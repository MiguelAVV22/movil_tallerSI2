import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/taller_service.dart';
import 'package:taller_movil/shared/app_drawer.dart';

// ── Configuración de estados ────────────────────────────────
const _estadoLabel = {
  'aceptado':      'Aceptado',
  'en_camino':     'En camino',
  'en_sitio':      'En sitio',
  'en_reparacion': 'En reparación',
  'finalizado':    'Finalizado',
  'cancelado':     'Cancelado',
};

const _estadoColor = {
  'aceptado':      Color(0xFFD97706),
  'en_camino':     AppColors.primary,
  'en_sitio':      Color(0xFF7C3AED),
  'en_reparacion': Color(0xFFEA580C),
  'finalizado':    AppColors.success,
  'cancelado':     AppColors.danger,
};

const _estadoIcon = {
  'aceptado':      Icons.check_circle_outline,
  'en_camino':     Icons.directions_car_outlined,
  'en_sitio':      Icons.location_on_outlined,
  'en_reparacion': Icons.build_outlined,
  'finalizado':    Icons.task_alt,
  'cancelado':     Icons.cancel_outlined,
};

// en_sitio es confirmado por el cliente (CU31) en el caso normal.
// El taller puede usarlo como fallback si el cliente no tiene señal (ej. SOS).
const _transiciones = {
  'aceptado':      ['en_camino', 'cancelado'],
  'en_camino':     ['en_sitio',  'cancelado'],
  'en_sitio':      ['en_reparacion'],
  'en_reparacion': ['finalizado'],
};

const _pasos = ['aceptado', 'en_camino', 'en_sitio', 'en_reparacion', 'finalizado'];

// ── Página ──────────────────────────────────────────────────
class ActualizarEstadoServicioPage extends StatefulWidget {
  const ActualizarEstadoServicioPage({super.key});

  @override
  State<ActualizarEstadoServicioPage> createState() =>
      _ActualizarEstadoServicioPageState();
}

class _ActualizarEstadoServicioPageState
    extends State<ActualizarEstadoServicioPage> {
  final _svc = TallerService();

  List<AsignacionModel> _asignaciones = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _svc.listarAsignacionesActivas();
      setState(() { _asignaciones = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _actualizar(AsignacionModel a, String nuevoEstado) async {
    // Pedir observación opcional
    final obs = await showDialog<String>(
      context: context,
      builder: (_) => _ObsDialog(estadoLabel: _estadoLabel[nuevoEstado] ?? nuevoEstado),
    );
    if (obs == null) return; // cancelado

    try {
      final actualizada = await _svc.actualizarEstado(a.id, nuevoEstado,
          observacion: obs.isEmpty ? null : obs);
      final activos = ['aceptado', 'en_camino', 'en_sitio', 'en_reparacion'];
      setState(() {
        if (!activos.contains(actualizada.estado)) {
          _asignaciones.removeWhere((x) => x.id == actualizada.id);
        } else {
          final idx = _asignaciones.indexWhere((x) => x.id == actualizada.id);
          if (idx != -1) _asignaciones[idx] = actualizada;
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Estado actualizado: ${_estadoLabel[actualizada.estado]}'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));

      // Al pasar a "en_camino", ofrecer compartir ubicación GPS al cliente
      if (nuevoEstado == 'en_camino') {
        final activar = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.location_on, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text('Compartir ubicación',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            content: const Text(
              'El cliente puede ver tu posición en tiempo real mientras vas en camino.\n\n¿Deseas activar la compartición de GPS ahora?',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Ahora no', style: TextStyle(color: AppColors.grey)),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.gps_fixed, size: 16),
                label: const Text('Activar GPS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        );
        if (activar == true && mounted) {
          Navigator.pushNamed(context, '/comunicacion/compartir-ubicacion');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Estado del Servicio',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _cargar,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 44),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
    if (_asignaciones.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.build_circle_outlined, size: 56, color: AppColors.grey),
            SizedBox(height: 12),
            Text('No hay servicios activos',
                style: TextStyle(color: AppColors.grey, fontSize: 15)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _asignaciones.length,
        itemBuilder: (_, i) => _AsignacionCard(
          asignacion: _asignaciones[i],
          onActualizar: _actualizar,
        ),
      ),
    );
  }
}

// ── Tarjeta de asignación ───────────────────────────────────
class _AsignacionCard extends StatelessWidget {
  const _AsignacionCard({
    required this.asignacion,
    required this.onActualizar,
  });

  final AsignacionModel asignacion;
  final Future<void> Function(AsignacionModel, String) onActualizar;

  @override
  Widget build(BuildContext context) {
    final estado   = asignacion.estado;
    final color    = _estadoColor[estado] ?? AppColors.grey;
    final icon     = _estadoIcon[estado]  ?? Icons.help_outline;
    final label    = _estadoLabel[estado] ?? estado;
    final opciones = _transiciones[estado] ?? <String>[];
    final pasoIdx  = _pasos.indexOf(estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Encabezado ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Asignación #${asignacion.id}',
                        style: const TextStyle(fontWeight: FontWeight.w700,
                            fontSize: 15, color: AppColors.text)),
                    const SizedBox(height: 2),
                    Text('Incidente #${asignacion.incidenteId}',
                        style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                    if (asignacion.esSos) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🆘', style: TextStyle(fontSize: 13)),
                            SizedBox(width: 4),
                            Text('SOS — emergencia urgente',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                    color: AppColors.danger)),
                          ],
                        ),
                      ),
                    ],
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 5),
                      Text(label,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Stepper ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: List.generate(_pasos.length * 2 - 1, (i) {
                    if (i.isOdd) {
                      final lineIdx = i ~/ 2;
                      final done = pasoIdx > lineIdx;
                      return Expanded(
                        child: Container(height: 2,
                            color: done ? AppColors.primary : AppColors.border),
                      );
                    }
                    final dotIdx = i ~/ 2;
                    final done   = pasoIdx >= dotIdx;
                    final active = estado == _pasos[dotIdx];
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: active ? 14 : 10,
                      height: active ? 14 : 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? AppColors.primary : AppColors.border,
                        boxShadow: active
                            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 6, spreadRadius: 2)]
                            : [],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _pasos.map((p) {
                    final isActive = estado == p;
                    return Expanded(
                      child: Text(
                        _estadoLabel[p]!.replaceAll(' ', '\n'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          color: isActive ? AppColors.primary : AppColors.grey,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // ── Observación actual ───────────────────────────
          if (asignacion.observacion != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.comment_outlined, size: 14, color: AppColors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(asignacion.observacion!,
                          style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // ── Aviso "en_sitio" cuando estado es en_camino ──
          if (estado == 'en_camino')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Color(0xFFD97706)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '"En sitio" lo confirma el cliente. Úsalo solo si el cliente no tiene señal (ej. SOS).',
                        style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Botones de transición ───────────────────────
          if (opciones.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: const [
                Icon(Icons.info_outline, size: 15, color: AppColors.grey),
                SizedBox(width: 6),
                Text('Sin cambios de estado disponibles.',
                    style: TextStyle(fontSize: 12, color: AppColors.grey)),
              ]),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: opciones.map((op) {
                  final opColor = _estadoColor[op] ?? AppColors.primary;
                  final opLabel = _estadoLabel[op] ?? op;
                  final opIcon  = _estadoIcon[op]  ?? Icons.arrow_forward;
                  final isDanger = op == 'cancelado';
                  return ElevatedButton.icon(
                    onPressed: () => onActualizar(asignacion, op),
                    icon: Icon(opIcon, size: 15),
                    label: Text(opLabel, style: const TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDanger
                          ? AppColors.danger.withValues(alpha: 0.1)
                          : opColor.withValues(alpha: 0.1),
                      foregroundColor: isDanger ? AppColors.danger : opColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(
                        color: isDanger ? AppColors.danger.withValues(alpha: 0.4)
                                        : opColor.withValues(alpha: 0.4),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Diálogo de observación ──────────────────────────────────
class _ObsDialog extends StatefulWidget {
  const _ObsDialog({required this.estadoLabel});
  final String estadoLabel;

  @override
  State<_ObsDialog> createState() => _ObsDialogState();
}

class _ObsDialogState extends State<_ObsDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Cambiar a "${widget.estadoLabel}"',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Observación (opcional)',
              style: TextStyle(fontSize: 13, color: AppColors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ej. Esperando pieza de repuesto...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar', style: TextStyle(color: AppColors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
