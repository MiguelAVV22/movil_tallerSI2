import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/taller_service.dart';
import 'package:taller_movil/services/api_helper.dart';

/// CU16 – El taller rechaza su asignación activa (solo en estado "aceptado").
/// Navegar con arguments: incidente_id (int)
class RechazarSolicitudPage extends StatefulWidget {
  const RechazarSolicitudPage({super.key});

  @override
  State<RechazarSolicitudPage> createState() => _RechazarSolicitudPageState();
}

class _RechazarSolicitudPageState extends State<RechazarSolicitudPage> {
  final _svc = TallerService();

  int? _incidenteId;
  bool _rechazando = false;
  bool _rechazado  = false;
  String _error    = '';

  List<AsignacionModel> _asignaciones = [];
  bool _loadingList = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) {
      setState(() => _incidenteId = args);
    } else {
      _cargarAsignaciones();
    }
  }

  Future<void> _cargarAsignaciones() async {
    setState(() { _loadingList = true; _error = ''; });
    try {
      final data = await _svc.listarAsignacionesActivas();
      if (!mounted) return;
      setState(() {
        _asignaciones = data.where((a) => a.estado == 'aceptado').toList();
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

  Future<void> _rechazar(int incidenteId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rechazar asignación'),
        content: Text('¿Rechazar el incidente #$incidenteId? '
            'El incidente volverá a estar disponible para otros talleres.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Sí, rechazar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() { _rechazando = true; _error = ''; });
    try {
      await _svc.rechazarSolicitud(incidenteId);
      if (!mounted) return;
      setState(() { _rechazado = true; _incidenteId = incidenteId; _rechazando = false; });
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _rechazando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Rechazar Solicitud', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _rechazado ? _buildSuccess() : _buildContent(),
      ),
    );
  }

  Widget _buildSuccess() => Column(children: [
    const SizedBox(height: 40),
    const Icon(Icons.block_outlined, size: 64, color: AppColors.danger),
    const SizedBox(height: 16),
    Text('Incidente #$_incidenteId rechazado',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
        textAlign: TextAlign.center),
    const SizedBox(height: 8),
    const Text('El incidente vuelve a estar disponible para que otro taller lo acepte.',
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
    // Caso: navegar con incidente_id directo
    if (_incidenteId != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Rechazar asignación',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.text)),
              const SizedBox(height: 6),
              Text('Incidente #$_incidenteId',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              const SizedBox(height: 4),
              const Text('Al rechazar, el incidente volverá al estado pendiente y otros talleres podrán aceptarlo.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ]),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Text(_error, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _rechazando ? null : () => _rechazar(_incidenteId!),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _rechazando
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Rechazar esta solicitud', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      );
    }

    // Caso: cargar lista de asignaciones aceptadas
    if (_loadingList) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error.isNotEmpty) return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
        child: Text(_error, style: const TextStyle(color: AppColors.danger)),
      ),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _cargarAsignaciones, child: const Text('Reintentar')),
    ]);
    if (_asignaciones.isEmpty) return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('No tienes asignaciones en estado "aceptado" que puedas rechazar.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 14), textAlign: TextAlign.center),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Asignaciones que puedes rechazar:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 16),
        ..._asignaciones.map((a) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Incidente #${a.incidenteId}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.text)),
            const SizedBox(height: 4),
            Text('Asignación #${a.id} · Estado: ${a.estado}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            if (a.eta != null) ...[
              const SizedBox(height: 2),
              Text('ETA: ${a.eta} min', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _rechazando ? null : () => _rechazar(a.incidenteId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: _rechazando
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        )),
      ],
    );
  }
}
