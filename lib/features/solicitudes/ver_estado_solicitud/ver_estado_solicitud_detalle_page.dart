import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/api_helper.dart';
import 'package:taller_movil/services/emergencia_service.dart';
import 'package:taller_movil/widgets/incidente_taller_map.dart';
import 'package:taller_movil/features/cliente/pago_servicio_page.dart';
import 'package:taller_movil/features/cliente/calificar_servicio_page.dart';

class VerEstadoSolicitudDetallePage extends StatefulWidget {
  const VerEstadoSolicitudDetallePage({super.key, required this.item});
  final Map<String, dynamic> item;

  @override
  State<VerEstadoSolicitudDetallePage> createState() => _VerEstadoSolicitudDetallePageState();
}

class _VerEstadoSolicitudDetallePageState extends State<VerEstadoSolicitudDetallePage> {
  final _svc = EmergenciaService();
  final _player = AudioPlayer();
  int? _gestionandoId;
  bool _reproduciendo = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _labelIncidente(String? e) {
    const m = {
      'pendiente': 'Pendiente',
      'en_proceso': 'En proceso',
      'resuelto': 'Atendido',
      'cancelado': 'Cancelado',
    };
    return m[e] ?? (e ?? '—');
  }

  String _labelAccion(String accion) {
    switch (accion) {
      case 'aceptado':
        return 'aceptar';
      case 'rechazado':
        return 'rechazar';
      case 'cancelado':
        return 'cancelar';
      default:
        return accion;
    }
  }

  String _tituloResultado(String accion) {
    switch (accion) {
      case 'aceptado':
        return 'Solicitud aceptada';
      case 'rechazado':
        return 'Solicitud rechazada';
      case 'cancelado':
        return 'Solicitud cancelada';
      default:
        return 'Solicitud actualizada';
    }
  }

  Future<void> _accionSolicitud({
    required int incidenteId,
    required String accion,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar acción'),
        content: Text('¿Deseas ${_labelAccion(accion)} la solicitud #$incidenteId?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _gestionandoId = incidenteId);
    try {
      await _svc.gestionarSolicitud(incidenteId: incidenteId, estado: accion);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_tituloResultado(accion)),
          content: Text('La solicitud #$incidenteId se actualizó correctamente.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _gestionandoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.item;
    final inc = row['incidente'] as Map<String, dynamic>? ?? {};
    final asig = row['asignacion'] as Map<String, dynamic>?;
    final fotos = (row['fotos_urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
    final audios = (row['audios_urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
    final id = inc['id'] as int? ?? 0;
    final estado = (inc['estado'] as String?) ?? '';
    final descripcion = (inc['descripcion'] as String?) ?? 'Sin descripción';
    final puedeCancelar = estado == 'pendiente';
    final puedeAceptarRechazar = estado == 'pendiente' && asig != null;
    final lat = inc['latitud'];
    final lon = inc['longitud'];
    final tlat = asig?['taller_latitud'];
    final tlon = asig?['taller_longitud'];
    final ilat = _toD(lat);
    final ilon = _toD(lon);
    final wlat = _toD(tlat);
    final wlon = _toD(tlon);
    final mapaOk = ilat != null && ilon != null && wlat != null && wlon != null;
    final asgEst = asig?['estado'] as String? ?? '';
    final puedeCiclo3 = estado == 'resuelto' && asgEst == 'finalizado';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Detalle de solicitud', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#EMG-${id.toString().padLeft(3, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                Text('Estado: ${_labelIncidente(estado)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Taller: ${asig?['taller_nombre']?.toString() ?? 'Sin asignar'}'),
                if (asig?['eta'] != null) Text('Tiempo estimado: ${asig!['eta']} min'),
                if (mapaOk)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: IncidenteTallerMap(
                      incidenteLat: ilat,
                      incidenteLng: ilon,
                      tallerLat: wlat,
                      tallerLng: wlon,
                      height: 220,
                    ),
                  )
                else ...[
                  if (tlat != null && tlon != null)
                    Text('Ubicación taller: $tlat, $tlon'),
                  if (lat != null && lon != null) Text('Tu ubicación: $lat, $lon'),
                ],
                const Divider(height: 24),
                const Text('Descripción del problema', style: TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 6),
                Text(descripcion, style: const TextStyle(fontSize: 17)),
                const SizedBox(height: 14),
                const Text('Evidencias', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (fotos.isEmpty)
                  const Text('Sin fotos', style: TextStyle(color: Color(0xFF6B7280)))
                else
                  SizedBox(
                    height: 86,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: fotos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final url = fotos[i].startsWith('http')
                            ? fotos[i]
                            : '${EmergenciaService.apiOrigin}${fotos[i].startsWith('/') ? '' : '/'}${fotos[i]}';
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(url, width: 86, height: 86, fit: BoxFit.cover),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                if (audios.isEmpty)
                  const Text('Sin audios', style: TextStyle(color: Color(0xFF6B7280)))
                else
                  Column(
                    children: audios.map((a) {
                      final url = a.startsWith('http')
                          ? a
                          : '${EmergenciaService.apiOrigin}${a.startsWith('/') ? '' : '/'}$a';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(_reproduciendo ? Icons.stop : Icons.play_arrow),
                              onPressed: () async {
                                if (_reproduciendo) {
                                  await _player.stop();
                                  if (mounted) setState(() => _reproduciendo = false);
                                  return;
                                }
                                await _player.stop();
                                await _player.play(UrlSource(url));
                                if (mounted) setState(() => _reproduciendo = true);
                                _player.onPlayerComplete.listen((_) {
                                  if (mounted) setState(() => _reproduciendo = false);
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('Audio evidencia', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (puedeAceptarRechazar) ...[
            _ActionButton(
              label: _gestionandoId == id ? 'Procesando...' : 'Aceptar',
              color: const Color(0xFF1EB980),
              icon: Icons.check_circle_outline,
              onTap: _gestionandoId == id ? null : () => _accionSolicitud(incidenteId: id, accion: 'aceptado'),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              label: 'Rechazar',
              color: AppColors.danger,
              icon: Icons.cancel_outlined,
              onTap: _gestionandoId == id ? null : () => _accionSolicitud(incidenteId: id, accion: 'rechazado'),
            ),
            const SizedBox(height: 10),
          ],
          if (puedeCancelar)
            _ActionButton(
              label: 'Cancelar',
              color: const Color(0xFF6B7280),
              icon: Icons.block_outlined,
              onTap: _gestionandoId == id ? null : () => _accionSolicitud(incidenteId: id, accion: 'cancelado'),
            ),
          if (puedeCiclo3) ...[
            const SizedBox(height: 12),
            _ActionButton(
              label: 'Pago del servicio',
              color: const Color(0xFF16A34A),
              icon: Icons.payments,
              onTap: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PagoServicioPage(incidenteId: id),
                  ),
                );
                if (ok == true && context.mounted) {
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 8),
            _ActionButton(
              label: 'Calificar servicio',
              color: const Color(0xFF00135b),
              icon: Icons.star_rate,
              onTap: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalificarServicioPage(
                      incidenteId: id,
                      tallerNombre: asig?['taller_nombre']?.toString(),
                      servicioDescripcion: descripcion,
                    ),
                  ),
                );
                if (ok == true && context.mounted) setState(() {});
              },
            ),
          ],
        ],
      ),
    );
  }
}

double? _toD(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
    );
  }
}
