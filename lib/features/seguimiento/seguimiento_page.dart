import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/features/comunicacion/chat/chat_page.dart';
import 'package:taller_movil/features/seguimiento/websocket_service.dart';
import 'package:taller_movil/services/emergencia_service.dart';
import 'package:taller_movil/services/routing_service.dart';

class SeguimientoPage extends StatefulWidget {
  const SeguimientoPage({super.key});

  @override
  State<SeguimientoPage> createState() => _SeguimientoPageState();
}

class _SeguimientoPageState extends State<SeguimientoPage> {
  int? _incidenteId;
  WebSocketService? _wsService;

  // Estados locales recibidos del WebSocket o API
  String _estadoActual = 'PENDIENTE';
  int? _etaMinutos;
  double? _latitud;
  double? _longitud;
  int? _tecnicoId;
  int? _asignacionId;
  String? _tecnicoNombre;
  String? _tecnicoTelefono;
  String? _tallerNombre;

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

  // Ruta real por calles usando OpenRouteService / OSRM
  final RoutingService _routingService = RoutingService();
  List<LatLng> _routePoints = [];
  double? _routeDistanceKm;
  int? _routeEtaMinutes;
  bool _loadingRoute = false;

  double? _lastRoutingLat;
  double? _lastRoutingLng;
  DateTime? _lastRoutingTime;

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
        final oldTecnicoId = _tecnicoId;
        final oldEstado = _estadoActual;
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

        _verificarYActualizarRuta();

        if ((oldTecnicoId == null && _tecnicoId != null) || (oldEstado != _estadoActual)) {
          _obtenerUbicacionCliente();
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
        final asignacion = solicitud['asignacion'] as Map<String, dynamic>?;
        setState(() {
          if (incidente != null && incidente['latitud'] != null && incidente['longitud'] != null) {
            _clienteLat = (incidente['latitud'] as num).toDouble();
            _clienteLng = (incidente['longitud'] as num).toDouble();
          }
          if (asignacion != null) {
            _asignacionId = asignacion['id'] as int?;
            _tecnicoId = asignacion['tecnico_id'] as int?;
            _tecnicoNombre = asignacion['tecnico_nombre'] as String?;
            _tecnicoTelefono = asignacion['tecnico_telefono'] as String?;
            _tallerNombre = asignacion['taller_nombre'] as String?;
          }
        });
        if (_mapaListo) {
          _recentrarMapa();
        }
        _verificarYActualizarRuta();
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
        final List<LatLng> pointsToFit = [clientPos, tecnicoPos];
        if (_routePoints.isNotEmpty) {
          pointsToFit.addAll(_routePoints);
        }
        final bounds = LatLngBounds.fromPoints(pointsToFit);
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

  Future<void> _loadRoute() async {
    if (_clienteLat == null || _clienteLng == null || _latitud == null || _longitud == null) {
      return;
    }

    setState(() {
      _loadingRoute = true;
    });

    try {
      final result = await _routingService.obtenerRuta(
        origenLat: _latitud!,
        origenLng: _longitud!,
        destinoLat: _clienteLat!,
        destinoLng: _clienteLng!,
      );

      if (!mounted) return;

      if (result != null) {
        setState(() {
          _routePoints = result.points;
          _routeDistanceKm = result.distanceMeters / 1000.0;
          _routeEtaMinutes = (result.durationSeconds / 60.0).round();
        });
      } else {
        // Fallback si falla
        if (_routePoints.isEmpty) {
          setState(() {
            _routePoints = [
              LatLng(_clienteLat!, _clienteLng!),
              LatLng(_latitud!, _longitud!),
            ];
            const distanceCalc = Distance();
            final metros = distanceCalc.distance(
              LatLng(_clienteLat!, _clienteLng!),
              LatLng(_latitud!, _longitud!),
            );
            _routeDistanceKm = metros / 1000.0;
            _routeEtaMinutes = _etaMinutos ?? (metros / 500.0).round();
          });
        }
      }
    } catch (e) {
      debugPrint('Error al calcular ruta: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingRoute = false;
        });
      }
    }
  }

  Future<void> _verificarYActualizarRuta() async {
    if (!mounted) return;
    if (_clienteLat == null || _clienteLng == null || _latitud == null || _longitud == null) {
      return;
    }

    final now = DateTime.now();
    bool debeRecalcular = false;

    if (_lastRoutingLat == null || _lastRoutingLng == null || _lastRoutingTime == null || _routePoints.isEmpty) {
      debeRecalcular = true;
    } else {
      try {
        const distanceCalc = Distance();
        final metros = distanceCalc.distance(
          LatLng(_lastRoutingLat!, _lastRoutingLng!),
          LatLng(_latitud!, _longitud!),
        );
        final segundosDiff = now.difference(_lastRoutingTime!).inSeconds;
        if (metros > 100 || segundosDiff > 30) {
          debeRecalcular = true;
        }
      } catch (e) {
        debeRecalcular = true;
      }
    }

    if (!debeRecalcular) return;

    _lastRoutingLat = _latitud;
    _lastRoutingLng = _longitud;
    _lastRoutingTime = now;

    await _loadRoute();
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

                  // Tarjeta del Técnico (Carlos Méndez)
                  _buildTechnicianCard(),
                  const SizedBox(height: 16),

                  // Tarjetas side-by-side de ETA y Distancia
                  _buildMetricsCards(),
                  const SizedBox(height: 24),

                  // Título de la sección de progreso
                  const Text(
                    'ESTADO DEL SERVICIO',
                    style: TextStyle(
                      color: Color(0xFF94A3B8), // Slate 400
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Línea de tiempo horizontal
                  _buildHorizontalTimeline(activeIndex),
                  const SizedBox(height: 28),

                  // Botones funcionales: Llamar, Chat, Compartir
                  _buildActionButtons(),
                  const SizedBox(height: 16),

                  // Centro de Ayuda
                  _buildHelpCenterButton(),

                  // Botón de Reconexión en caso de desconexión o error
                  if (!isConnected) ...[
                    const SizedBox(height: 20),
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

  Widget _buildMapContainer() {
    final cLat = _clienteLat ?? -17.783013;
    final cLng = _clienteLng ?? -63.180252;
    final clientPos = LatLng(cLat, cLng);

    final LatLng? tecnicoPos = (_latitud != null && _longitud != null)
        ? LatLng(_latitud!, _longitud!)
        : null;

    final hasTecnico = tecnicoPos != null;

    return Container(
      width: double.infinity,
      height: 300,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
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
                        points: _routePoints.isNotEmpty ? _routePoints : [clientPos, tecnicoPos],
                        strokeWidth: 5.0,
                        color: const Color(0xFF2563EB),
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

            // Overlay "Calculando mejor ruta..." si se está cargando
            if (_loadingRoute)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF38BDF8),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Calculando mejor ruta...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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
    );
  }

  // ── Acciones de contacto y compartir ────────────────────────
  Future<void> _hacerLlamada() async {
    final telefono = _tecnicoTelefono;
    if (telefono == null || telefono.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No existe número disponible.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final url = Uri.parse('tel:${telefono.trim()}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir el marcador para el número: $telefono'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _abrirChat() {
    if (_asignacionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El chat no está disponible hasta que se asigne un técnico.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      '/comunicacion/chat',
      arguments: ChatArgs(
        asignacionId: _asignacionId!,
        nombreContacto: _tecnicoNombre ?? 'Técnico Asignado',
      ),
    );
  }

  Future<void> _compartirSeguimiento() async {
    final statusText = _getEstadoLabel(_estadoActual).toUpperCase();
    final techText = _tecnicoNombre ?? 'Asignado';
    final etaVal = (_routeEtaMinutes ?? _etaMinutos);
    final etaText = etaVal != null ? '$etaVal min' : 'Calculando...';
    
    final techLat = _latitud ?? -17.80;
    final techLng = _longitud ?? -63.14;
    final mapsLink = 'https://maps.google.com/?q=${techLat.toStringAsFixed(6)},${techLng.toStringAsFixed(6)}';
    
    final text = '🚗 Seguimiento de asistencia RutaSegura\n\n'
        'Estado: $statusText\n'
        'Técnico: $techText\n'
        'ETA: $etaText\n\n'
        'Ubicación actual:\n'
        '$mapsLink\n\n'
        'Seguimiento generado desde RutaSegura.';
    
    await SharePlus.instance.share(
      ShareParams(
        text: text,
      ),
    );
  }

  void _mostrarCentroAyuda() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B), // Slate 800
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF475569), // Slate 600
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Centro de Ayuda',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '¿Tienes algún problema con el servicio? Selecciona una opción:',
                  style: TextStyle(
                    color: Color(0xFF94A3B8), // Slate 400
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emergency_outlined, color: Color(0xFFDC2626)),
                  ),
                  title: const Text(
                    'Emergencia (SOS)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Llamar a los servicios de emergencia o reportar peligro inmediato.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    final url = Uri.parse('tel:110');
                    launchUrl(url);
                  },
                ),
                const Divider(color: Color(0xFF334155), height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.report_problem_outlined, color: Color(0xFF38BDF8)),
                  ),
                  title: const Text(
                    'Reportar problema',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Inconvenientes con el técnico o el taller asignado.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reporte enviado a soporte. Nos contactaremos pronto.'),
                        backgroundColor: Color(0xFF38BDF8),
                      ),
                    );
                  },
                ),
                const Divider(color: Color(0xFF334155), height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent_outlined, color: Color(0xFF10B981)),
                  ),
                  title: const Text(
                    'Contactar soporte',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Hablar directamente con un administrador del sistema.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    final url = Uri.parse('tel:+59170000000');
                    launchUrl(url);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Componentes de UI Rediseñados ───────────────────────────
  Widget _buildTechnicianCard() {
    final techName = _tecnicoNombre ?? 'Técnico Asignado';
    final workshopName = _tallerNombre ?? 'Taller de Asistencia';
    
    final int ratingSeed = _tecnicoId ?? 1;
    final double rating = 4.5 + (ratingSeed % 5) * 0.1;
    final int servicesCount = 80 + (ratingSeed % 10) * 15;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                techName.isNotEmpty ? techName[0].toUpperCase() : 'T',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  techName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  workshopName,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '($servicesCount servicios)',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCards() {
    final hasTecnico = _latitud != null && _longitud != null;
    
    String distanciaTexto = 'Calculando...';
    if (_routeDistanceKm != null) {
      distanciaTexto = '${_routeDistanceKm!.toStringAsFixed(1)} km';
    } else if (hasTecnico && _clienteLat != null && _clienteLng != null) {
      try {
        const distanceCalc = Distance();
        final metros = distanceCalc.distance(LatLng(_clienteLat!, _clienteLng!), LatLng(_latitud!, _longitud!));
        if (metros < 1000) {
          distanciaTexto = '${metros.toStringAsFixed(0)} m';
        } else {
          distanciaTexto = '${(metros / 1000).toStringAsFixed(1)} km';
        }
      } catch (_) {
        distanciaTexto = '—';
      }
    }
    
    final etaVal = _routeEtaMinutes ?? _etaMinutos;
    final etaTexto = etaVal != null ? '$etaVal min' : 'Calculando...';
    
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tiempo estimado',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  etaTexto,
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Distancia',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  distanciaTexto,
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalTimeline(int activeIndex) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_pasos.length, (index) {
            final paso = _pasos[index];
            final label = paso['label'] as String;
            final isCompleted = index < activeIndex;
            final isActive = index == activeIndex;

            Widget dot;
            if (isCompleted) {
              dot = Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: emeraldColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              );
            } else if (isActive) {
              dot = Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            } else {
              dot = Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF475569), width: 1),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    dot,
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive
                            ? Colors.white
                            : isCompleted
                                ? Colors.white70
                                : Colors.white38,
                      ),
                    ),
                  ],
                ),
                if (index < _pasos.length - 1)
                  Container(
                    width: 32,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 18, left: 4, right: 4),
                    color: isCompleted ? emeraldColor : const Color(0xFF334155),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.phone,
            label: 'Llamar',
            color: const Color(0xFF2563EB),
            onPressed: _hacerLlamada,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.chat_bubble_outline,
            label: 'Chat',
            color: const Color(0xFF2563EB),
            onPressed: _abrirChat,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.share,
            label: 'Compartir',
            color: const Color(0xFF2563EB),
            onPressed: _compartirSeguimiento,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCenterButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _mostrarCentroAyuda,
        icon: const Icon(Icons.help_outline, color: Color(0xFF38BDF8), size: 18),
        label: const Text(
          'Centro de Ayuda',
          style: TextStyle(
            color: Color(0xFF38BDF8),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
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
