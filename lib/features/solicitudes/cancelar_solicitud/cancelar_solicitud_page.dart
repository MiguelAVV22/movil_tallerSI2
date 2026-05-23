import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/emergencia_service.dart';
import 'package:taller_movil/services/api_helper.dart';

/// CU11 – El cliente cancela una solicitud (incidente) propia.
class CancelarSolicitudPage extends StatefulWidget {
  const CancelarSolicitudPage({super.key});

  @override
  State<CancelarSolicitudPage> createState() => _CancelarSolicitudPageState();
}

class _CancelarSolicitudPageState extends State<CancelarSolicitudPage> {
  final _svc = EmergenciaService();

  List<Map<String, dynamic>> _incidentes = [];
  bool _loadingList = false;
  bool _cancelando  = false;
  String _error     = '';
  bool _cancelado   = false;
  int? _incidenteCancelado;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) {
      setState(() => _incidentes = [
        {'id': args, 'descripcion': null, 'estado': 'pendiente', 'prioridad': 'media'}
      ]);
    } else {
      _cargarIncidentes();
    }
  }

  Future<void> _cargarIncidentes() async {
    setState(() { _loadingList = true; _error = ''; });
    try {
      final data = await _svc.listarMisIncidentes();
      if (!mounted) return;
      setState(() {
        _incidentes = data
            .where((i) => ['pendiente', 'en_proceso'].contains(i['estado']))
            .toList();
        _loadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loadingList = false; });
    }
  }

  Future<void> _cancelar(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar cancelación'),
        content: Text('¿Cancelar la solicitud #$id? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() { _cancelando = true; _error = ''; });
    try {
      await _svc.cancelarSolicitud(id);
      if (!mounted) return;
      setState(() { _cancelado = true; _incidenteCancelado = id; _cancelando = false; });
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _cancelando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Cancelar Solicitud', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _cancelado ? _buildSuccess() : _buildContent(),
      ),
    );
  }

  Widget _buildSuccess() => Column(children: [
    const SizedBox(height: 40),
    const Icon(Icons.cancel_outlined, size: 64, color: AppColors.success),
    const SizedBox(height: 16),
    Text('Solicitud #$_incidenteCancelado cancelada',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
        textAlign: TextAlign.center),
    const SizedBox(height: 8),
    const Text('Tu solicitud fue cancelada. El taller ha sido notificado.',
        style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
    const SizedBox(height: 32),
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text('Volver al inicio'),
      ),
    ),
  ]);

  Widget _buildContent() {
    if (_loadingList) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error.isNotEmpty) return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
        child: Text(_error, style: const TextStyle(color: AppColors.danger)),
      ),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _cargarIncidentes, child: const Text('Reintentar')),
    ]);
    if (_incidentes.isEmpty) return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('No tienes solicitudes activas que puedas cancelar.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 14), textAlign: TextAlign.center),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Selecciona la solicitud a cancelar:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 16),
        ..._incidentes.map((inc) {
          final id   = inc['id'] as int;
          final desc = inc['descripcion'] as String?;
          final est  = inc['estado'] as String? ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Solicitud #$id',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.text)),
                _EstadoBadge(est),
              ]),
              if (desc != null && desc.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _cancelando ? null : () => _cancelar(id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: _cancelando
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Cancelar esta solicitud', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          );
        }),
      ],
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge(this.estado);
  final String estado;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (estado) {
      case 'pendiente': color = const Color(0xFFF59E0B); label = 'Pendiente'; break;
      case 'en_proceso': color = AppColors.primary; label = 'En proceso'; break;
      default: color = const Color(0xFF9CA3AF); label = estado;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
