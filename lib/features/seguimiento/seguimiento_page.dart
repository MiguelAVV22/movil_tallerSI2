import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/features/seguimiento/websocket_service.dart';
import 'package:taller_movil/services/emergencia_service.dart';

class SeguimientoPage extends StatefulWidget {
  const SeguimientoPage({super.key});

  @override
  State<SeguimientoPage> createState() => _SeguimientoPageState();
}

class _SeguimientoPageState extends State<SeguimientoPage> {
  int? _incidenteId;
  WebSocketService? _wsService;

  // Estados locales recibidos del WebSocket
  String _estadoActual = 'PENDIENTE';
  int? _etaMinutos;
  double? _latitud;
  double? _longitud;
  int? _tecnicoId;

  // Estado de la conexión
  String _statusConexion = 'Conectando...';
  bool _tieneError = false;
  String _errorMsg = '';

  // Variables para el mapa en tiempo real
  double? _clienteLat;
  double? _clienteLng;
  bool _cargandoClienteUbicacion = false;
  final MapController _mapController = MapController();
  bool _mapaListo = false;
  bool _firstUbicacionRecibida = false;

  static const Color emeraldColor = Color(0xFF10B981);
  static const Color roseColor = Color(0xFFF43F5E);

  final List<Map<String, dynamic>> _pasos = [
    {'estado': 'PENDIENTE', 'label': 'Pendiente', 'desc': 'La solicitud de asistencia ha sido registrada.'},
    {'estado': 'BUSCANDO_TALLER', 'label': 'Buscando Taller', 'desc': 'Buscando talleres mecánicos disponibles.'},
    {'estado': 'ACEPTADO', 'label': 'Aceptado', 'desc': 'El taller ha aceptado tu solicitud de asistencia.'},
    {'estado': 'EN_CAMINO', 'label': 'En Camino', 'desc': 'El técnico asignado va en camino hacia tu ubicación.'},
    {'estado': 'LLEGADA', 'label': 'Llegada', 'desc': 'El técnico ha llegado al lugar del incidente.'},
    {'estado': 'REPARANDO', 'label': 'Reparando', 'desc': 'El técnico está realizando la asistencia en sitio.'},
    {'estado': 'FINALIZADO', 'label': 'Finalizado', 'desc': 'El servicio se ha completado correctamente.'},
  ];

  int _getEstadoIndex(String state) {
    final s = state.toUpperCase().trim();
    if (s == 'PENDIENTE') return 0;
    if (s == 'BUSCANDO_TALLER') return 1;
    if (s == 'ACEPTADO') return 2;
    if (s == 'EN_CAMINO') return 3;
    if (s == 'LLEGADA' || s == 'EN_SITIO') return 4;
    if (s == 'REPARANDO' || s == 'EN_REPARACION') return 5;
    if (s == 'FINALIZADO') return 6;
    return 0; // Default
  }

  String _getEstadoLabel(String state) {
    final idx = _getEstadoIndex(state);
    return _pasos[idx]['label'] as String;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_incidenteId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) {
        _incidenteId = args;
        _iniciarWebSocket();
        _obtenerUbicacionCliente();
      } else if (args is Map<String, dynamic>) {
        _incidenteId = args['incidenteId'] as int?;
        _clienteLat = (args['latitud'] as num?)?.toDouble();
        _clienteLng = (args['longitud'] as num?)?.toDouble();
        _iniciarWebSocket();
        if (_clienteLat == null || _clienteLng == null) {
          _obtenerUbicacionCliente();
        }
      } else {
        setState(() {
          _statusConexion = 'Error';
          _tieneError = true;
          _errorMsg = 'ID de incidente no válido o ausente.';
        });
      }
    }
  }

  void _iniciarWebSocket() {
    if (_incidenteId == null) return;

    setState(() {
      _statusConexion = 'Conectando...';
      _tieneError = false;
      _errorMsg = '';
    });

    _wsService?.disconnect();
    _wsService = WebSocketService(
      incidenteId: _incidenteId!,
      onMessageReceived: (data) {
        if (!mounted) return;
        setState(() {
          _estadoActual = data['estado'] as String? ?? _estadoActual;
          _etaMinutos = data['eta_minutos'] as int? ?? _etaMinutos;
          _latitud = (data['latitud'] as num?)?.toDouble() ?? _latitud;
          _longitud = (data['longitud'] as num?)?.toDouble() ?? _longitud;
          _tecnicoId = data['tecnico_id'] as int? ?? _tecnicoId;
          _statusConexion = 'Conectado';
          _tieneError = false;
        });

        // Centrar automáticamente solo la primera vez que llegue la ubicación del técnico
        if (!_firstUbicacionRecibida && _latitud != null && _longitud != null) {
          _firstUbicacionRecibida = true;
          if (_mapaListo) {
            _recentrarMapa();
          }
        }
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _statusConexion = 'Desconectado';
          _tieneError = true;
          _errorMsg = 'Error de conexión con el servidor de seguimiento.';
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _statusConexion = 'Desconectado';
        });
      },
    );

    _wsService!.connect();
  }

  Future<void> _obtenerUbicacionCliente() async {
    if (_incidenteId == null) return;
    setState(() {
      _cargandoClienteUbicacion = true;
    });
    try {
      final svc = EmergenciaService();
      final solicitudes = await svc.listarMisSolicitudes();
      final Map<String, dynamic>? solicitud = solicitudes.cast<Map<String, dynamic>?>().firstWhere(
        (element) => element?['incidente']?['id'] == _incidenteId,
        orElse: () => null,
      );
      if (solicitud != null) {
        final incidente = solicitud['incidente'] as Map<String, dynamic>?;
        if (incidente != null && incidente['latitud'] != null && incidente['longitud'] != null) {
          setState(() {
            _clienteLat = (incidente['latitud'] as num).toDouble();
            _clienteLng = (incidente['longitud'] as num).toDouble();
          });
          if (_mapaListo) {
            _recentrarMapa();
          }
        }
      }
    } catch (e) {
      debugPrint('Error al obtener ubicación del cliente: $e');
    } finally {
      if (mounted) {
        setState(() {
          _cargandoClienteUbicacion = false;
        });
      }
    }
  }

  void _recentrarMapa() {
    if (!_mapaListo) return;

    // TODO: Si todavía no existen coordenadas del cliente, usar coordenadas de prueba temporalmente
    final cLat = _clienteLat ?? -17.783013;
    final cLng = _clienteLng ?? -63.180252;
    final clientPos = LatLng(cLat, cLng);

    try {
      if (_latitud != null && _longitud != null) {
        final tecnicoPos = LatLng(_latitud!, _longitud!);
        final bounds = LatLngBounds.fromPoints([clientPos, tecnicoPos]);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(50.0),
          ),
        );
      } else {
        _mapController.move(clientPos, 15);
      }
    } catch (e) {
      debugPrint('Error en _recentrarMapa: $e');
      if (_latitud != null && _longitud != null) {
        _mapController.move(LatLng(_latitud!, _longitud!), 14);
      } else {
        _mapController.move(clientPos, 14);
      }
    }
  }

  @override
  void dispose() {
    _wsService?.disconnect();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _getEstadoIndex(_estadoActual);
    final isConnected = _statusConexion == 'Conectado';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fondo oscuro premium (Slate 900)
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B), // Slate 800
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          'Seguimiento #${_incidenteId ?? ""}',
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isConnected ? emeraldColor.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isConnected ? emeraldColor.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isConnected ? emeraldColor : Colors.amber,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (isConnected)
                        BoxShadow(
                          color: emeraldColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _statusConexion,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isConnected ? emeraldColor : Colors.amber,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      body: _incidenteId == null
          ? Center(
              child: Text(
                _errorMsg,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner de Error si _tieneError es true
                  if (_tieneError && _errorMsg.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: roseColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: roseColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: roseColor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMsg,
                              style: const TextStyle(color: roseColor, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Mapa en Tiempo Real con GPS
                  _buildMapContainer(),
                  const SizedBox(height: 20),

                  // Tarjeta Principal de Seguimiento
                  _buildMainCard(activeIndex),
                  const SizedBox(height: 28),

                  // Título de la sección
                  const Text(
                    'LÍNEA DE TIEMPO DEL SERVICIO',
                    style: TextStyle(
                      color: Color(0xFF94A3B8), // Slate 400
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Barra de progreso y pasos
                  _buildTimeline(activeIndex),

                  // Botón de Reconexión en caso de desconexión o error
                  if (!isConnected) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.sync_problem_outlined, size: 20),
                        label: const Text(
                          'Reconectar seguimiento',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _iniciarWebSocket,
                      ),
                    ),
                  ]
                ],
              ),
            ),
    );
  }

  Widget _buildMainCard(int activeIndex) {
    final statusColor = activeIndex == 6 ? emeraldColor : Colors.blueAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Slate 800
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)), // Slate 700
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila del Estado
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  activeIndex == 6
                      ? Icons.check_circle_outline
                      : Icons.local_shipping_outlined,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESTADO ACTUAL',
                      style: TextStyle(
                        color: Color(0xFF94A3B8), // Slate 400
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      _getEstadoLabel(_estadoActual),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32, color: Color(0xFF334155)),

          // Fila de Info Auxiliar (ETA y Técnico)
          Row(
            children: [
              // ETA Card
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Color(0xFF94A3B8)),
                        SizedBox(width: 4),
                        Text(
                          'ETA ESTIMADO',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _etaMinutos != null ? '$_etaMinutos mins' : '—',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // Técnico ID Card
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.badge_outlined, size: 14, color: Color(0xFF94A3B8)),
                        SizedBox(width: 4),
                        Text(
                          'ID TÉCNICO',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _tecnicoId != null ? '#$_tecnicoId' : '—',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Coordenadas
          if (_latitud != null && _longitud != null) ...[
            const Divider(height: 32, color: Color(0xFF334155)),
            const Row(
              children: [
                Icon(Icons.pin_drop_outlined, size: 16, color: roseColor),
                SizedBox(width: 6),
                Text(
                  'COORDENADAS DEL TÉCNICO',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lat: ${_latitud!.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8), // Light Blue
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 14,
                    color: const Color(0xFF334155),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lon: ${_longitud!.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildTimeline(int activeIndex) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _pasos.length,
        itemBuilder: (context, index) {
          final paso = _pasos[index];
          final pasoLabel = paso['label'] as String;
          final pasoDesc = paso['desc'] as String;

          final isCompleted = index < activeIndex;
          final isActive = index == activeIndex;

          Widget dotWidget;

          if (isActive) {
            dotWidget = Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            );
          } else if (isCompleted) {
            dotWidget = const Icon(
              Icons.check_circle,
              color: emeraldColor,
              size: 20,
            );
          } else {
            dotWidget = Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFF475569),
                shape: BoxShape.circle,
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna de Línea
              Column(
                children: [
                  dotWidget,
                  if (index < _pasos.length - 1)
                    Container(
                      width: 2,
                      height: 48,
                      color: isCompleted ? emeraldColor : const Color(0xFF334155),
                    ),
                ],
              ),
              const SizedBox(width: 18),

              // Columna de Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pasoLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? Colors.white
                            : isCompleted
                                ? Colors.white70
                                : const Color(0xFF64748B), // Slate 500
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pasoDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive
                            ? const Color(0xFF94A3B8)
                            : isCompleted
                                ? const Color(0xFF64748B)
                                : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMapContainer() {
    // TODO: Si todavía no existen coordenadas del cliente, usar coordenadas de prueba temporalmente
    final cLat = _clienteLat ?? -17.783013;
    final cLng = _clienteLng ?? -63.180252;
    final clientPos = LatLng(cLat, cLng);

    final LatLng? tecnicoPos = (_latitud != null && _longitud != null)
        ? LatLng(_latitud!, _longitud!)
        : null;

    final hasTecnico = tecnicoPos != null;

    // Calcular distancia aproximada si técnico está disponible
    String distanciaTexto = 'Calculando...';
    double? metros;
    if (hasTecnico) {
      try {
        const distanceCalc = Distance();
        metros = distanceCalc.distance(clientPos, tecnicoPos);
        if (metros < 1000) {
          distanciaTexto = '${metros.toStringAsFixed(0)} m';
        } else {
          distanciaTexto = '${(metros / 1000).toStringAsFixed(2)} km';
        }
      } catch (e) {
        distanciaTexto = 'Error al calcular';
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Slate 800
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)), // Slate 700
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Área del Mapa o Placeholder
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: tecnicoPos ?? clientPos,
                      initialZoom: 14.5,
                      onMapReady: () {
                        setState(() {
                          _mapaListo = true;
                        });
                        _recentrarMapa();
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.taller.movil',
                        tileBuilder: (context, tileWidget, tile) {
                          return ColorFiltered(
                            colorFilter: const ColorFilter.matrix([
                              -0.9, 0, 0, 0, 255,
                              0, -0.9, 0, 0, 255,
                              0, 0, -0.9, 0, 255,
                              0, 0, 0, 1, 0,
                            ]),
                            child: tileWidget,
                          );
                        },
                      ),
                      if (hasTecnico)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [clientPos, tecnicoPos],
                              strokeWidth: 4.0,
                              color: const Color(0xFF38BDF8),
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: clientPos,
                            width: 44,
                            height: 44,
                            child: const _MapMarker(
                              icon: Icons.person_pin_circle,
                              color: emeraldColor,
                              bgColor: Color(0xFF064E3B),
                            ),
                          ),
                          if (hasTecnico)
                            Marker(
                              point: tecnicoPos,
                              width: 44,
                              height: 44,
                              child: const _MapMarker(
                                icon: Icons.local_shipping,
                                color: Color(0xFFF59E0B),
                                bgColor: Color(0xFF78350F),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // Overlay "Esperando ubicación del técnico" si no hay coordenadas
                  if (!hasTecnico)
                    Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Esperando ubicación del técnico',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _cargandoClienteUbicacion 
                                  ? 'Cargando datos del cliente...'
                                  : 'El técnico aún no transmite su señal GPS...',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Botón flotante para recentrar
                  if (_mapaListo)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'recentrar_map_fab',
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFF334155)),
                        ),
                        onPressed: _recentrarMapa,
                        tooltip: 'Recentrar seguimiento',
                        child: const Icon(Icons.my_location, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Barra inferior de detalles (Distancia y ETA)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.straighten_outlined,
                          color: Color(0xFF38BDF8),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DISTANCIA',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasTecnico ? distanciaTexto : '—',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: const Color(0xFF334155),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.speed_outlined,
                          color: Color(0xFFF59E0B),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ETA ESTIMADO',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _etaMinutos != null ? '$_etaMinutos min' : '—',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Marcador personalizado del mapa ──────────────────────────
class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.icon,
    required this.color,
    required this.bgColor,
  });
  final IconData icon;
  final Color color, bgColor;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      );
}
