import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/solicitud_taller_service.dart';
import 'package:taller_movil/services/api_helper.dart';

/// CU13 – Listar disponibles ordenados por score IA (§4.6 Motor).
/// CU15 – Aceptar solicitud.
class VerSolicitudesDisponiblesPage extends StatefulWidget {
  const VerSolicitudesDisponiblesPage({super.key});

  @override
  State<VerSolicitudesDisponiblesPage> createState() => _VerSolicitudesDisponiblesPageState();
}

class _VerSolicitudesDisponiblesPageState extends State<VerSolicitudesDisponiblesPage> {
  final _svc = SolicitudTallerService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _error = '';
  int? _aceptandoId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final data = await _svc.listarDisponibles();
      if (!mounted) return;
      setState(() { _items = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _aceptar(Map<String, dynamic> row) async {
    final id = row['incidente_id'] as int;
    final etaCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Aceptar solicitud #$id'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Opcional: tiempo estimado de llegada (minutos).'),
            const SizedBox(height: 12),
            TextField(
              controller: etaCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ETA (min)', hintText: 'Ej. 30'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aceptar')),
        ],
      ),
    );
    if (confirm != true) { etaCtrl.dispose(); return; }

    int? eta;
    final t = etaCtrl.text.trim();
    if (t.isNotEmpty) eta = int.tryParse(t);
    etaCtrl.dispose();

    setState(() => _aceptandoId = id);
    try {
      await _svc.aceptar(id, etaMinutos: eta);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud aceptada'), backgroundColor: AppColors.success),
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) { Navigator.pushReplacementNamed(context, '/login'); return; }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _aceptandoId = null);
    }
  }

  // ── Score label ────────────────────────────────────────────
  String _scoreLabel(double score) {
    if (score >= 0.7) return 'Muy cercano';
    if (score >= 0.4) return 'Cercano';
    if (score > 0)    return 'Lejano';
    return '';
  }

  Color _scoreColor(double score) {
    if (score >= 0.7) return AppColors.success;
    if (score >= 0.4) return const Color(0xFFF59E0B);
    return AppColors.grey;
  }

  Color _prioridadColor(String p) {
    if (p == 'alta') return AppColors.danger;
    if (p == 'media') return const Color(0xFFF59E0B);
    return AppColors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Solicitudes disponibles', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _cargar),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
                    ]),
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.assignment_late_outlined, size: 48, color: Color(0xFF9CA3AF)),
                          SizedBox(height: 12),
                          Text(
                            'No hay solicitudes disponibles.\nAparecerán ordenadas por distancia a tu taller.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ]),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final s      = _items[i];
                        final id     = s['incidente_id'] as int;
                        final tipo   = s['tipo_problema'] as String? ?? '';
                        final pri    = s['prioridad'] as String? ?? 'media';
                        final esSOS  = s['es_sos'] as bool? ?? false;
                        final nFotos = (s['fotos_urls'] as List?)?.length ?? 0;
                        final tieneAudio = s['tiene_audio'] as bool? ?? false;
                        final score  = (s['score_ia'] as num?)?.toDouble() ?? 0.0;
                        final dist   = s['distancia_km'];
                        final busy   = _aceptandoId == id;

                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          elevation: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: esSOS ? AppColors.danger.withValues(alpha: 0.5)
                                    : const Color(0xFFE5E7EB),
                                width: esSOS ? 1.5 : 1.0,
                              ),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Fila superior: ID + badges ───────────────
                                Row(children: [
                                  Text('#$id',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  const SizedBox(width: 8),
                                  if (esSOS) ...[
                                    _Badge('🆘 SOS', AppColors.danger),
                                  ] else ...[
                                    _Badge(pri.toUpperCase(), _prioridadColor(pri)),
                                  ],
                                  const Spacer(),
                                  // §4.6 Score IA
                                  if (score > 0)
                                    _Badge(_scoreLabel(score), _scoreColor(score)),
                                ]),
                                const SizedBox(height: 8),

                                // §4.5 Tipo clasificado por IA
                                if (tipo.isNotEmpty)
                                  Row(children: [
                                    const Icon(Icons.smart_toy_outlined,
                                      size: 14, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(tipo,
                                        style: const TextStyle(
                                          fontSize: 13, color: Color(0xFF374151),
                                          fontWeight: FontWeight.w500)),
                                    ),
                                  ])
                                else
                                  const Text('Sin clasificar',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                const SizedBox(height: 6),

                                // Coordenadas + distancia
                                Row(children: [
                                  const Icon(Icons.location_on_outlined,
                                    size: 14, color: Color(0xFF6B7280)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      s['latitud'] != null
                                          ? '${(s['latitud'] as double).toStringAsFixed(4)}, '
                                            '${(s['longitud'] as double).toStringAsFixed(4)}'
                                          : 'Sin GPS',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: s['latitud'] != null
                                            ? const Color(0xFF6B7280)
                                            : AppColors.danger,
                                      ),
                                    ),
                                  ),
                                  // §4.6 Distancia
                                  if (dist != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '${(dist as double).toStringAsFixed(1)} km',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6366F1),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ]),

                                // Evidencias
                                if (nFotos > 0 || tieneAudio) ...[
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    if (nFotos > 0) ...[
                                      const Icon(Icons.image_outlined, size: 13, color: Color(0xFF6B7280)),
                                      const SizedBox(width: 3),
                                      Text('$nFotos foto(s)',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                      const SizedBox(width: 8),
                                    ],
                                    if (tieneAudio) ...[
                                      const Icon(Icons.mic_outlined, size: 13, color: Color(0xFF6B7280)),
                                      const SizedBox(width: 3),
                                      const Text('Audio',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                    ],
                                  ]),
                                ],

                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: busy ? null : () => _aceptar(s),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                    child: busy
                                        ? const SizedBox(
                                            height: 20, width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white))
                                        : const Text('Aceptar solicitud'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
