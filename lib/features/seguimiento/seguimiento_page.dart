import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/features/seguimiento/websocket_service.dart';

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

  @override
  void dispose() {
    _wsService?.disconnect();
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
}
