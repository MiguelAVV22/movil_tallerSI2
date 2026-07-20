import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';

import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/emergencia_service.dart';
import 'package:taller_movil/services/api_helper.dart';

/// CU08 – Enviar audio al incidente (Grabación en vivo + Reproducción + Archivos).
class EnviarAudioPage extends StatefulWidget {
  const EnviarAudioPage({super.key, required this.incidenteId});

  final int incidenteId;

  @override
  State<EnviarAudioPage> createState() => _EnviarAudioPageState();
}

class _EnviarAudioPageState extends State<EnviarAudioPage> {
  final _svc = EmergenciaService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordDuration = 0;
  Timer? _timer;

  String? _nombreArchivo;
  Uint8List? _audioBytes;
  String? _mimeType;
  bool _uploading = false;
  String _error = '';
  Map<String, dynamic>? _resultado;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Grabar Audio en Tiempo Real ───────────────────────────
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _error = '';
      _resultado = null;
      _audioBytes = null;
      _nombreArchivo = null;
    });

    try {
      if (await _audioRecorder.hasPermission()) {
        String? targetPath;
        if (!kIsWeb) {
          final dir = await getTemporaryDirectory();
          targetPath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';
        }

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: targetPath ?? '',
        );

        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });

        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (mounted) setState(() => _recordDuration++);
        });
      } else {
        setState(() => _error = 'Permiso de micrófono denegado.');
      }
    } catch (e) {
      setState(() => _error = 'Error al iniciar la grabación de audio: $e');
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        final xfile = XFile(path);
        final bytes = await xfile.readAsBytes();
        setState(() {
          _isRecording = false;
          _audioBytes = bytes;
          _nombreArchivo = 'grabacion_voz_${DateTime.now().millisecondsSinceEpoch}.wav';
          _mimeType = 'audio/wav';
        });
      } else {
        setState(() {
          _isRecording = false;
          _error = 'No se obtuvo archivo de la grabación.';
        });
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _error = 'Error al detener grabación: $e';
      });
    }
  }

  // ── Reproducir / Pausar Audio ──────────────────────────────
  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
    } else {
      if (_audioBytes != null) {
        await _audioPlayer.stop();
        setState(() => _isPlaying = true);
        await _audioPlayer.play(BytesSource(_audioBytes!));
      }
    }
  }

  void _descartarAudio() {
    _audioPlayer.stop();
    setState(() {
      _audioBytes = null;
      _nombreArchivo = null;
      _isPlaying = false;
      _resultado = null;
      _error = '';
    });
  }

  // ── Seleccionar Archivo (WAV / MP3) ───────────────────────
  Future<void> _seleccionarArchivo() async {
    _descartarAudio();
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

  // ── Subir y Transcribir ────────────────────────────────────
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Audio enviado y procesado con IA'),
          backgroundColor: AppColors.success,
        ),
      );
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

  String _formatDuration(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final trans   = _resultado?['transcripcion'] as Map<String, dynamic>?;
    final clasif  = _resultado?['clasificacion'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Grabar / Enviar audio', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Emergencia #${widget.incidenteId}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 6),
          const Text(
            'Puedes grabar una nota de voz con el micrófono o subir un archivo de audio. El sistema transcribirá tu mensaje con IA.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),

          // ── Grabador en Vivo ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isRecording ? AppColors.danger : const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(children: [
              if (_isRecording) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GRABANDO... ${_formatDuration(_recordDuration)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              GestureDetector(
                onTap: _uploading ? null : _toggleRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _isRecording ? AppColors.danger : AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording ? AppColors.danger : AppColors.primary).withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isRecording ? 'Toca para detener la grabación' : 'Toca el micrófono para grabar voz',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isRecording ? AppColors.danger : const Color(0xFF374151),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Opción secundaria: Seleccionar archivo ────────────
          Center(
            child: TextButton.icon(
              onPressed: _uploading || _isRecording ? null : _seleccionarArchivo,
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text('O seleccionar archivo de audio (WAV/MP3)'),
            ),
          ),
          const SizedBox(height: 12),

          // ── Vista Previa & Reproductor ────────────────────────
          if (_audioBytes != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.audiotrack_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _nombreArchivo ?? 'Audio listo',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                      onPressed: _uploading ? null : _descartarAudio,
                      tooltip: 'Descartar audio',
                    ),
                  ]),
                  const SizedBox(height: 8),

                  // Botón de Reproducción
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _togglePlay,
                        icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        label: Text(_isPlaying ? 'Pausar' : 'Escuchar audio'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _descartarAudio,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Volver a grabar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _subirAudio,
                icon: _uploading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(
                  _uploading ? 'Transcribiendo con IA…' : 'Confirmar y Enviar Audio',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],

          // ── Resultado IA ─────────────────────────────────────
          if (_resultado != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.smart_toy_outlined, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 8),
                  const Text('Resultado del Análisis IA',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4F46E5), fontSize: 14)),
                ]),
                const SizedBox(height: 8),
                Text('Transcripción: "${trans?['transcripcion'] ?? ''}"',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E1B4B))),
                if (clasif != null) ...[
                  const SizedBox(height: 6),
                  Text('Tipo sugerido: ${clasif['tipo_incidente_sugerido'] ?? ''}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4338CA))),
                ]
              ]),
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
        ]),
      ),
    );
  }
}
