import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/comunicacion_service.dart';
import 'package:taller_movil/services/taller_service.dart';

// Argumentos de navegación para esta pantalla
class VerTecnicoMapaArgs {
  final int asignacionId;
  final double? incidenteLatitud;
  final double? incidenteLongitud;

  const VerTecnicoMapaArgs({
    required this.asignacionId,
    this.incidenteLatitud,
    this.incidenteLongitud,
  });
}

// CU17 — Ver técnico en mapa (vista del cliente)
class VerTecnicoMapaPage extends StatefulWidget {
  const VerTecnicoMapaPage({super.key});

  @override
  State<VerTecnicoMapaPage> createState() => _VerTecnicoMapaPageState();
}

class _VerTecnicoMapaPageState extends State<VerTecnicoMapaPage> {
  final _comunicacionService = ComunicacionService();
  final _tallerService       = TallerService();
  final _mapController       = MapController();

  UbicacionTecnicoModel? _ubicacion;
  bool    _cargando        = true;
  String? _error;
  Timer?  _timer;

  int     _asignacionId  = 0;
  LatLng? _incidentePos;
  bool    _argsLeidos    = false;
  bool    _sinAsignacion = false;
  bool    _mapaListo     = false;  // true una vez que FlutterMap llama onMapReady

  static const _estadosActivos = {
    'aceptado', 'en_camino', 'en_sitio', 'en_reparacion',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLeidos) return;
    _argsLeidos = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as VerTecnicoMapaArgs?;
    if (args != null) {
      _asignacionId = args.asignacionId;
      if (args.incidenteLatitud != null && args.incidenteLongitud != null) {
        _incidentePos = LatLng(args.incidenteLatitud!, args.incidenteLongitud!);
      }
      _iniciarPolling();
    } else {
      // Sin args: buscar la asignación activa del cliente automáticamente
      _cargarAsignacionActiva();
    }
  }

  Future<void> _cargarAsignacionActiva() async {
    setState(() { _cargando = true; _sinAsignacion = false; _error = null; });
    try {
      final asignaciones = await _tallerService.listarMisAsignacionesCliente();
      final activa = asignaciones.firstWhere(
        (a) => _estadosActivos.contains(a.estado),
        orElse: () => throw Exception('sin_asignacion'),
      );
      if (!mounted) return;
      _asignacionId = activa.id;
      _iniciarPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando      = false;
        _sinAsignacion = e.toString().contains('sin_asignacion');
        if (!_sinAsignacion) {
          _error = e.toString().replaceFirst('Exception: ', '');
        }
      });
    }
  }

  void _iniciarPolling() {
    _consultar();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _consultar());
  }

  Future<void> _consultar() async {
    if (!mounted) return;
    try {
      final ub = await _comunicacionService.obtenerUbicacionTecnico(_asignacionId);
      if (!mounted) return;
      setState(() {
        _ubicacion = ub;
        _cargando  = false;
        _error     = null;
      });
      // Mover solo si el mapa ya fue renderizado (onMapReady disparado)
      if (_mapaListo && ub.latitud != null && ub.longitud != null) {
        _mapController.move(LatLng(ub.latitud!, ub.longitud!), 15);
      }
      if (!_estadosActivos.contains(ub.estadoAsignacion)) {
        _timer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error    = e.toString().replaceFirst('Exception: ', '');
        _cargando = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _sinAsignacion
              ? _buildSinAsignacion()
              : _error != null
                  ? _buildError()
                  : _buildMapa(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFF3F4F6), height: 1),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.text),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child:
                const Icon(Icons.map_outlined, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          const Text(
            'Ver Técnico en Mapa',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.text,
            ),
          ),
        ],
      ),
      actions: [
        if (_asignacionId != 0)
          IconButton(
            icon: const Icon(Icons.refresh_outlined,
                size: 20, color: AppColors.primary),
            tooltip: 'Actualizar',
            onPressed: () {
              setState(() => _cargando = true);
              _consultar();
            },
          ),
      ],
    );
  }

  // Sin asignación activa en este momento
  Widget _buildSinAsignacion() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.map_outlined,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sin servicio activo',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'No tienes ningún servicio en curso en este momento. Cuando un taller acepte tu solicitud podrás ver al técnico aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.grey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _cargarAsignacionActiva,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Verificar de nuevo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.location_off_outlined,
                  color: AppColors.danger, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'No se pudo cargar la ubicación',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _cargando = true;
                  _error    = null;
                });
                _iniciarPolling();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapa() {
    final ub         = _ubicacion!;
    final tecnicoPos = (ub.latitud != null && ub.longitud != null)
        ? LatLng(ub.latitud!, ub.longitud!)
        : null;
    final center = tecnicoPos ?? _incidentePos ?? const LatLng(-16.5, -68.15);

    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              onMapReady: () => setState(() => _mapaListo = true),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.taller.movil',
              ),
              MarkerLayer(
                markers: [
                  // Marcador del incidente / posición del cliente (rojo)
                  if (_incidentePos != null)
                    Marker(
                      point: _incidentePos!,
                      width: 44,
                      height: 44,
                      child: const _MapMarker(
                        icon: Icons.person_pin_circle,
                        color: AppColors.danger,
                        bgColor: Color(0xFFFEF2F2),
                      ),
                    ),
                  // Marcador del técnico (azul)
                  if (tecnicoPos != null)
                    Marker(
                      point: tecnicoPos,
                      width: 44,
                      height: 44,
                      child: const _MapMarker(
                        icon: Icons.directions_car,
                        color: AppColors.primary,
                        bgColor: Color(0xFFEFF6FF),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        _buildInfoCard(ub),
      ],
    );
  }

  Widget _buildInfoCard(UbicacionTecnicoModel ub) {
    final (label, color) = _estadoInfo(ub.estadoAsignacion);
    final sinUbicacion   = ub.latitud == null || ub.longitud == null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.engineering_outlined,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ub.nombre,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (ub.eta != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${ub.eta} min',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          if (sinUbicacion)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El técnico aún no ha compartido su ubicación',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                const Icon(Icons.location_on,
                    size: 14, color: AppColors.grey),
                const SizedBox(width: 4),
                Text(
                  '${ub.latitud!.toStringAsFixed(5)}, '
                  '${ub.longitud!.toStringAsFixed(5)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.grey),
                ),
                const Spacer(),
                const Icon(Icons.sync, size: 13, color: AppColors.grey),
                const SizedBox(width: 4),
                const Text(
                  'Cada 4 s',
                  style: TextStyle(fontSize: 11, color: AppColors.grey),
                ),
              ],
            ),
        ],
      ),
    );
  }

  (String, Color) _estadoInfo(String estado) => switch (estado) {
        'aceptado'      => ('Aceptado',      AppColors.grey),
        'en_camino'     => ('En camino',     AppColors.primary),
        'en_sitio'      => ('En el sitio',   Color(0xFFD97706)),
        'en_reparacion' => ('En reparación', Color(0xFF7C3AED)),
        'finalizado'    => ('Finalizado',    AppColors.success),
        _               => ('Cancelado',     AppColors.danger),
      };
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
