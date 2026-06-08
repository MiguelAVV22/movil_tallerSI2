import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/features/seguimiento/websocket_service.dart';
import 'package:taller_movil/features/seguimiento/ubicacion_service.dart';

class SeguimientoTecnicoPage extends StatefulWidget {
  const SeguimientoTecnicoPage({super.key});

  @override
  State<SeguimientoTecnicoPage> createState() => _SeguimientoTecnicoPageState();
}

class _SeguimientoTecnicoPageState extends State<SeguimientoTecnicoPage> {
  int? _incidenteId;
  int? _tecnicoId;

  // Servicios
  final _ubicacionService = UbicacionService();
  WebSocketService? _wsService;

  // Timer para envío periódico cada 10s
  Timer? _timerEnvio;

  // Estado local de transmisión
  bool _transmitiendo = false;
  String _estadoActual = 'EN_CAMINO';
  int _etaMinutos = 15;
  double? _latitud;
  double? _longitud;
  String _ultimaActualizacion = '--:--';
  int _paquetesEnviados = 0;

  // Estado de la UI
  String _statusConexion = 'Desconectado';
  String _errorMsg = '';
  bool _tieneError = false;

  static const Color emeraldColor = Color(0xFF10B981);
  static const Color roseColor = Color(0xFFF43F5E);
  static const Color slateBg = Color(0xFF0F172A);
  static const Color cardBg = Color(0xFF1E293B);
  static const Color borderCol = Color(0xFF334155);

  final List<String> _estados = ['EN_CAMINO', 'LLEGADA', 'REPARANDO', 'FINALIZADO'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_incidenteId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _incidenteId = args['incidente_id'] as int?;
        _tecnicoId = args['tecnico_id'] as int?;
        
        if (_incidenteId != null && _tecnicoId != null) {
          _iniciarTransmision();
        } else {
          _setError('ID de incidente o técnico inválido.');
        }
      } else {
        _setError('Argumentos inválidos.');
      }
    }
  }

  void _setError(String msg) {
    setState(() {
      _tieneError = true;
      _errorMsg = msg;
      _transmitiendo = false;
    });
  }

  Future<void> _iniciarTransmision() async {
    if (_incidenteId == null || _tecnicoId == null) return;

    setState(() {
      _transmitiendo = true;
      _tieneError = false;
      _errorMsg = '';
      _statusConexion = 'Conectando...';
    });

    // 1. Establecer conexión WebSocket
    _wsService?.disconnect();
    _wsService = WebSocketService(
      incidenteId: _incidenteId!,
      onMessageReceived: (data) {
        // En el flujo del técnico, solo somos emisores.
        // Si recibimos algún eco o respuesta del backend, actualizamos conexión.
        if (mounted) {
          setState(() {
            _statusConexion = 'Conectado';
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _statusConexion = 'Desconectado';
            _tieneError = true;
            _errorMsg = 'Error en WebSocket. Reintentando...';
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _statusConexion = 'Desconectado';
          });
        }
      },
    );

    await _wsService!.connect();
    
    if (_wsService!.isConnected) {
      setState(() {
        _statusConexion = 'Conectado';
      });
    }

    // 2. Realizar primer envío de ubicación inmediatamente
    await _enviarActualizacionUbicacion();

    // 3. Iniciar temporizador de envío periódico de 10 segundos
    _timerEnvio?.cancel();
    _timerEnvio = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_transmitiendo && mounted) {
        await _enviarActualizacionUbicacion();
      }
    });
  }

  Future<void> _enviarActualizacionUbicacion() async {
    if (_incidenteId == null || _tecnicoId == null) return;

    try {
      // Intentamos obtener la ubicación
      final pos = await _ubicacionService.obtenerUbicacionActual();
      
      if (!mounted) return;

      setState(() {
        _latitud = pos.latitude;
        _longitud = pos.longitude;
        _tieneError = false;
        _errorMsg = '';
      });

      // Asegurar conexión WebSocket antes de enviar
      if (_wsService == null || !_wsService!.isConnected) {
        setState(() {
          _statusConexion = 'Conectando...';
        });
        await _wsService?.connect();
      }

      if (_wsService != null && _wsService!.isConnected) {
        // Enviar payload JSON
        final payload = {
          "tipo": "ubicacion_tecnico",
          "incidente_id": _incidenteId,
          "tecnico_id": _tecnicoId,
          "latitud": pos.latitude,
          "longitud": pos.longitude,
          "estado": _estadoActual,
          "eta_minutos": _etaMinutos
        };

        _wsService!.sendMessage(payload);
        
        final now = DateTime.now();
        setState(() {
          _statusConexion = 'Conectado';
          _paquetesEnviados++;
          _ultimaActualizacion = 
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        });
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        _setError('Activa la ubicación del dispositivo para compartir tu seguimiento.');
      }
    } catch (e) {
      if (mounted) {
        _setError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _detenerTransmision() {
    _timerEnvio?.cancel();
    _wsService?.disconnect();
    setState(() {
      _transmitiendo = false;
      _statusConexion = 'Desconectado';
    });
  }

  void _cambiarEstado(String nuevoEstado) {
    if (!mounted) return;
    setState(() {
      _estadoActual = nuevoEstado;
    });

    // Enviar actualización inmediatamente
    if (_transmitiendo) {
      _enviarActualizacionUbicacion();
    }
  }

  void _ajustarEta(int delta) {
    if (!mounted) return;
    setState(() {
      _etaMinutos = (_etaMinutos + delta).clamp(0, 120);
    });

    // Enviar actualización inmediatamente
    if (_transmitiendo) {
      _enviarActualizacionUbicacion();
    }
  }

  @override
  void dispose() {
    _timerEnvio?.cancel();
    _wsService?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _statusConexion == 'Conectado';

    return Scaffold(
      backgroundColor: slateBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Transmisión GPS - Incidente #${_incidenteId ?? ""}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
      body: _incidenteId == null || _tecnicoId == null
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
                  // Banner de Error
                  if (_tieneError && _errorMsg.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: roseColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: roseColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: roseColor, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMsg,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Botón principal de compartir
                  _buildControlPanel(),
                  const SizedBox(height: 24),

                  // Tarjeta de Detalles del GPS
                  _buildGpsCard(),
                  const SizedBox(height: 24),

                  // Sección de Estado del Técnico
                  const Text(
                    'ESTADO DEL SERVICIO',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStateControls(),
                  const SizedBox(height: 24),

                  // Sección de ETA
                  const Text(
                    'TIEMPO ESTIMADO DE LLEGADA (ETA)',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildEtaControls(),
                ],
              ),
            ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _transmitiendo ? 'TRANSMITIENDO GPS' : 'TRANSMISIÓN INACTIVA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _transmitiendo ? emeraldColor : const Color(0xFF94A3B8),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _transmitiendo 
                      ? 'Ubicación enviándose cada 10s' 
                      : 'El cliente no puede ver tu ubicación',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _transmitiendo,
            activeThumbColor: emeraldColor,
            activeTrackColor: emeraldColor.withValues(alpha: 0.2),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withValues(alpha: 0.2),
            onChanged: (val) {
              if (val) {
                _iniciarTransmision();
              } else {
                _detenerTransmision();
              }
            },
          )
        ],
      ),
    );
  }

  Widget _buildGpsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatsWidget(
                icon: Icons.sync,
                iconColor: Colors.blueAccent,
                label: 'Frecuencia',
                value: 'Cada 10s',
              ),
              Container(width: 1, height: 40, color: borderCol),
              _buildStatsWidget(
                icon: Icons.send,
                iconColor: emeraldColor,
                label: 'Envíos OK',
                value: '$_paquetesEnviados',
              ),
              Container(width: 1, height: 40, color: borderCol),
              _buildStatsWidget(
                icon: Icons.history,
                iconColor: Colors.orangeAccent,
                label: 'Último envío',
                value: _ultimaActualizacion,
              ),
            ],
          ),
          if (_latitud != null && _longitud != null) ...[
            const Divider(height: 32, color: borderCol),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: slateBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderCol),
                    ),
                    child: Text(
                      'Lat: ${_latitud!.toStringAsFixed(6)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: slateBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderCol),
                    ),
                    child: Text(
                      'Lon: ${_longitud!.toStringAsFixed(6)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildStatsWidget({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStateControls() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        children: _estados.map((state) {
          final isSelected = _estadoActual == state;
          
          Color stateColor = AppColors.primary;
          IconData stateIcon = Icons.local_shipping_outlined;
          String stateLabel = state;

          if (state == 'EN_CAMINO') {
            stateColor = Colors.blueAccent;
            stateIcon = Icons.directions_car_outlined;
            stateLabel = 'En camino';
          } else if (state == 'LLEGADA') {
            stateColor = Colors.purpleAccent;
            stateIcon = Icons.location_on_outlined;
            stateLabel = 'Llegada (En sitio)';
          } else if (state == 'REPARANDO') {
            stateColor = Colors.orangeAccent;
            stateIcon = Icons.build_outlined;
            stateLabel = 'Reparando';
          } else if (state == 'FINALIZADO') {
            stateColor = emeraldColor;
            stateIcon = Icons.check_circle_outline;
            stateLabel = 'Finalizado';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              icon: Icon(stateIcon, size: 18),
              label: Text(stateLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isSelected ? Colors.white : stateColor,
                backgroundColor: isSelected ? stateColor : Colors.transparent,
                side: BorderSide(color: stateColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _cambiarEstado(state),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEtaControls() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: slateBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.schedule, color: Colors.blueAccent, size: 20),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_etaMinutos MINUTOS',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Text('Tiempo estimado', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                ],
              )
            ],
          ),
          Row(
            children: [
              _buildEtaBtn(Icons.remove, () => _ajustarEta(-5)),
              const SizedBox(width: 8),
              _buildEtaBtn(Icons.add, () => _ajustarEta(5)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEtaBtn(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: slateBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderCol),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}
