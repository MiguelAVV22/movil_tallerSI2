import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/emergencia_service.dart';
import 'package:taller_movil/services/api_helper.dart';

/// CU08 – Enviar audio al incidente con transcripción + clasificación IA (§4.5).
class EnviarAudioPage extends StatefulWidget {
  const EnviarAudioPage({super.key, required this.incidenteId});

  final int incidenteId;

  @override
  State<EnviarAudioPage> createState() => _EnviarAudioPageState();
}

class _EnviarAudioPageState extends State<EnviarAudioPage> {
  final _svc = EmergenciaService();

  String? _nombreArchivo;
  Uint8List? _audioBytes;
  String? _mimeType;
  bool _uploading = false;
  String _error = '';
  Map<String, dynamic>? _resultado;

  Future<void> _seleccionarAudio() async {
    setState(() { _error = ''; _resultado = null; _audioBytes = null; _nombreArchivo = null; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'ogg', 'm4a', 'flac', 'aac'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      setState(() {
        _audioBytes = file.bytes;
        _nombreArchivo = file.name;
        _mimeType = null;
      });
    } catch (e) {
      setState(() => _error = 'No se pudo cargar el archivo de audio.');
    }
  }

  Future<void> _subirAudio() async {
    if (_audioBytes == null) return;
    setState(() { _uploading = true; _error = ''; });
    try {
      final res = await _svc.subirAudio(
        incidenteId: widget.incidenteId,
        bytes: _audioBytes!,
        filename: _nombreArchivo ?? 'audio.wav',
        mimeType: _mimeType,
      );
      if (!mounted) return;
      setState(() {
        _resultado = res;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trans   = _resultado?['transcripcion'] as Map<String, dynamic>?;
    final clasif  = _resultado?['clasificacion'] as Map<String, dynamic>?;
    final exito   = trans?['exito'] as bool? ?? false;
    final texto   = trans?['transcripcion'] as String? ?? '';
    final mensaje = trans?['mensaje'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Enviar audio', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Emergencia #${widget.incidenteId}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 6),
          const Text(
            'Selecciona un archivo de audio WAV/MP3/OGG. El sistema lo transcribirá '
            'y clasificará el tipo de incidente automáticamente.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),

          // ── Selector ───────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _uploading ? null : _seleccionarAudio,
              icon: const Icon(Icons.audio_file_outlined, color: AppColors.primary),
              label: Text(
                _nombreArchivo ?? 'Seleccionar archivo de audio',
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
          ),
          if (_nombreArchivo != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_nombreArchivo!,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _subirAudio,
                icon: _uploading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.upload_rounded),
                label: Text(
                  _uploading ? 'Transcribiendo…' : 'Subir y transcribir',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],

          // ── Error ──────────────────────────────────────────
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
          ],

          // ── Resultado transcripción IA ─────────────────────
          if (_resultado != null) ...[
            const SizedBox(height: 24),
            const Text('Resultado IA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),

            // Transcripción
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: exito ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: exito
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(exito ? Icons.mic : Icons.mic_off,
                    size: 16, color: exito ? AppColors.success : AppColors.danger),
                  const SizedBox(width: 6),
                  Text(
                    exito ? 'Transcripción exitosa' : 'Sin transcripción',
                    style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13,
                      color: exito ? AppColors.success : AppColors.danger),
                  ),
                ]),
                const SizedBox(height: 6),
                if (exito && texto.isNotEmpty)
                  Text('"$texto"',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151),
                      fontStyle: FontStyle.italic))
                else
                  Text(mensaje,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
            ),

            // Clasificación IA del tipo de incidente
            if (clasif != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.smart_toy_outlined, size: 16, color: Color(0xFF6366F1)),
                    SizedBox(width: 6),
                    Text('Clasificación automática del incidente',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                        color: Color(0xFF6366F1))),
                  ]),
                  const SizedBox(height: 8),
                  _Row('Tipo detectado', clasif['etiqueta_es'] as String? ?? ''),
                  const SizedBox(height: 4),
                  _Row('Confianza',
                    '${((clasif['confianza'] as double? ?? 0) * 100).toStringAsFixed(0)}%'),
                  if ((clasif['alternativas'] as List?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    const Text('Alternativas:',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                    const SizedBox(height: 2),
                    ...((clasif['alternativas'] as List).cast<Map>()).map((alt) =>
                      Text(
                        '• ${alt['etiqueta_es']} (${((alt['confianza'] as double) * 100).toStringAsFixed(0)}%)',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ]),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/dashboard', (_) => false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Listo'),
              ),
            ),
          ],

          if (_resultado == null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _uploading
                    ? null
                    : () => Navigator.pushNamedAndRemoveUntil(
                        context, '/dashboard', (_) => false),
                child: const Text('Omitir y volver al inicio'),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('$label: ', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      Expanded(
        child: Text(value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: Color(0xFF1E1B4B))),
      ),
    ]);
  }
}
