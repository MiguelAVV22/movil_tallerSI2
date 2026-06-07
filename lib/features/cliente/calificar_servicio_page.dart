import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/api_helper.dart' show TokenExpiradoException;
import 'package:taller_movil/services/emergencia_service.dart';

class CalificarServicioPage extends StatefulWidget {
  const CalificarServicioPage({super.key, required this.incidenteId, this.tallerNombre, this.servicioDescripcion, this.fechaTexto});
  final int incidenteId;
  final String? tallerNombre;
  final String? servicioDescripcion;
  final String? fechaTexto;

  @override
  State<CalificarServicioPage> createState() => _CalificarServicioPageState();
}

class _CalificarServicioPageState extends State<CalificarServicioPage> {
  final _svc = EmergenciaService();
  int _puntos = 3;
  final _ctrl = TextEditingController();
  static const int _max = 500;
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _etiqueta(int p) {
    if (p <= 1) return 'Malo';
    if (p == 2) return 'Regular';
    if (p == 3) return 'Neutral';
    if (p == 4) return 'Muy bueno';
    return 'Excelente';
  }

  Future<void> _enviar() async {
    setState(() => _sending = true);
    try {
      final com = _ctrl.text.trim();
      await _svc.calificarServicio(
        incidenteId: widget.incidenteId,
        puntaje: _puntos,
        comentario: com.isEmpty ? null : com,
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
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00135b),
        foregroundColor: Colors.white,
        title: const Text('Califica tu experiencia', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.tallerNombre ?? 'Taller', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF00135b))),
                const SizedBox(height: 4),
                Text(
                  widget.servicioDescripcion ?? 'Servicio de asistencia de emergencia',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(widget.fechaTexto ?? '—', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('¿Cómo fue tu experiencia?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF00135b))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final p = i + 1;
              return IconButton(
                iconSize: 40,
                onPressed: () => setState(() => _puntos = p),
                icon: Icon(
                  p <= _puntos ? Icons.star : Icons.star_border,
                  color: p <= _puntos ? const Color(0xFFEA580C) : const Color(0xFFCBD5E1),
                ),
              );
            }),
          ),
          Center(child: Text(_etiqueta(_puntos), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF00135b)))),
          const SizedBox(height: 20),
          const Text.rich(
            TextSpan(
              text: 'Cuéntanos más ',
              style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF00135b)),
              children: [
                TextSpan(text: '(opcional)', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            minLines: 3,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            maxLength: _max,
            decoration: const InputDecoration(
              hintText: 'Comparte tu experiencia con el servicio...',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            buildCounter: (_, {required int currentLength, required bool isFocused, int? maxLength}) {
              return Align(
                alignment: Alignment.centerRight,
                child: Text('${(maxLength ?? _max) - currentLength} restantes', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: Color(0xFF5d8ce2)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tu opinión es importante para nosotros y nos ayuda a brindarte un mejor servicio.',
                    style: TextStyle(color: Color(0xFF00135b), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _enviar,
              icon: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, color: Colors.white),
              label: const Text('Enviar calificación', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00135b),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
