import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/features/solicitudes/ver_estado_solicitud/ver_estado_solicitud_detalle_page.dart';
import 'package:taller_movil/services/api_helper.dart' show TokenExpiradoException;
import 'package:taller_movil/services/cliente_historial_service.dart';
import 'package:taller_movil/services/emergencia_service.dart';

class HistorialServiciosPage extends StatefulWidget {
  const HistorialServiciosPage({super.key});

  @override
  State<HistorialServiciosPage> createState() => _HistorialServiciosPageState();
}

class _HistorialServiciosPageState extends State<HistorialServiciosPage> {
  final _svc = ClienteHistorialService();
  final _emergencias = EmergenciaService();
  List<dynamic> _rows = [];
  bool _load = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _load = true;
      _err = null;
    });
    try {
      final r = await _svc.listar();
      if (!mounted) return;
      setState(() => _rows = r);
    } catch (e) {
      if (e is TokenExpiradoException) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      if (mounted) setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _load = false);
    }
  }

  String _estadoLabel(String? e) {
    switch (e) {
      case 'completado':
        return 'Completado';
      case 'cancelado':
        return 'Cancelado';
      case 'pendiente':
      default:
        return 'Pendiente';
    }
  }

  Color _estadoColor(String? e) {
    switch (e) {
      case 'completado':
        return const Color(0xFF15803D);
      case 'cancelado':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFB45309);
    }
  }

  Future<void> _abrirDetalle(int incidenteId) async {
    try {
      final solicitudes = await _emergencias.listarMisSolicitudes();
      Map<String, dynamic>? detalle;
      for (final row in solicitudes) {
        final incidente = row['incidente'] as Map<String, dynamic>?;
        if (incidente?['id'] == incidenteId) {
          detalle = row;
          break;
        }
      }
      if (!mounted) return;
      if (detalle == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cargar el detalle de la solicitud.')),
        );
        return;
      }
      final actualizado = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => VerEstadoSolicitudDetallePage(item: detalle!),
        ),
      );
      if (actualizado == true && mounted) {
        await _cargar();
      }
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00135B),
        foregroundColor: Colors.white,
        title: const Text(
          'Historial de servicios',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: _load
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${_rows.length} servicios registrados',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
      ),
      body: _load
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00135B)))
          : _err != null
              ? Center(child: Text(_err!))
              : _rows.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay servicios aun',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF00135B),
                      onRefresh: _cargar,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final m = _rows[i] as Map<String, dynamic>;
                          final estado = m['estado'] as String?;
                          final monto = m['monto'];
                          final taller = m['nombre_taller'] as String? ?? '-';
                          final desc = m['descripcion'] as String? ?? '-';
                          final veh = m['vehiculo_texto'] as String? ?? '-';
                          final fecha = m['fecha'] as String?;
                          final incidenteId = m['incidente_id'] as int? ?? 0;
                          return _card(
                            label: _estadoLabel(estado),
                            col: _estadoColor(estado),
                            monto: monto is num ? monto : null,
                            taller: taller,
                            desc: desc,
                            veh: veh,
                            fecha: fecha,
                            onTap: incidenteId > 0 ? () => _abrirDetalle(incidenteId) : null,
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _card({
    required String label,
    required Color col,
    required String taller,
    required String desc,
    required String veh,
    String? fecha,
    num? monto,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: col,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (monto != null)
                    Text(
                      'Bs ${monto.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                taller,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF00135B),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                veh,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                'Toca para ver el detalle completo',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (fecha != null) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      fecha,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
