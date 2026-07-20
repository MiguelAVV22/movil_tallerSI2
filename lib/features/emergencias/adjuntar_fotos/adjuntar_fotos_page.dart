import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taller_movil/features/emergencias/enviar_audio/enviar_audio_page.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/emergencia_service.dart';
import 'package:taller_movil/services/api_helper.dart';

/// CU07 – Adjuntar fotos al incidente (cámara o galería, vista previa, confirmar).
/// La vista previa usa bytes en memoria para que funcione también en Flutter Web
/// (`Image.file` no está soportado en web).
class AdjuntarFotosPage extends StatefulWidget {
  const AdjuntarFotosPage({super.key, required this.incidenteId});

  final int incidenteId;

  @override
  State<AdjuntarFotosPage> createState() => _AdjuntarFotosPageState();
}

class _AdjuntarFotosPageState extends State<AdjuntarFotosPage> {
  final _svc = EmergenciaService();
  final _picker = ImagePicker();

  XFile? _previewFile;
  Uint8List? _previewBytes;
  bool _loadingPick = false;
  bool _uploading = false;
  String _error = '';
  final List<Map<String, dynamic>> _subidas = []; // {url, analisis_ia}

  Future<void> _pick(ImageSource source) async {
    setState(() { _loadingPick = true; _error = ''; });
    try {
      final x = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (x == null) {
        setState(() => _loadingPick = false);
        return;
      }
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _previewFile = x;
        _previewBytes = bytes;
        _loadingPick = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la imagen.';
        _loadingPick = false;
      });
    }
  }

  void _descartarPreview() {
    setState(() {
      _previewFile = null;
      _previewBytes = null;
    });
  }

  Future<void> _confirmarSubida() async {
    final file = _previewFile;
    final bytes = _previewBytes;
    if (file == null || bytes == null) return;
    setState(() { _uploading = true; _error = ''; });
    try {
      final res = await _svc.subirFoto(
        incidenteId: widget.incidenteId,
        bytes: bytes,
        filename: file.name.isNotEmpty ? file.name : 'foto.jpg',
        mimeType: file.mimeType,
      );
      final url = res['url'] as String? ?? '';
      final analisis = res['analisis_ia'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _subidas.add({'url': url, 'analisis_ia': analisis});
        _previewFile = null;
        _previewBytes = null;
        _uploading = false;
      });
      final etiqueta = analisis?['etiqueta_es'] as String? ?? '';
      final msg = etiqueta.isNotEmpty
          ? 'Foto guardada · IA: $etiqueta'
          : 'Foto guardada';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.success),
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

  void _irInicio() {
    Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Adjuntar fotos', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergencia #${widget.incidenteId}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
            const SizedBox(height: 8),
            const Text(
              'Puedes tomar una foto o elegir de la galería. Se pedirán permisos si hace falta.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadingPick || _uploading ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                    label: const Text('Cámara'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadingPick || _uploading ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                    label: const Text('Galería'),
                  ),
                ),
              ],
            ),
            if (_loadingPick) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            ],
            if (_previewBytes != null) ...[
              const SizedBox(height: 20),
              const Text('Vista previa', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.memory(_previewBytes!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _uploading ? null : _descartarPreview,
                      child: const Text('Descartar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _uploading ? null : _confirmarSubida,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _uploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Confirmar y subir'),
                    ),
                  ),
                ],
              ),
            ],
            if (_subidas.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fotos registradas (${_subidas.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  TextButton.icon(
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                    label: const Text('Agregar más', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._subidas.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final url     = item['url'] as String;
                final analisis = item['analisis_ia'] as Map<String, dynamic>?;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(url,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                        tooltip: 'Eliminar foto',
                        onPressed: () {
                          setState(() { _subidas.removeAt(idx); });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Foto eliminada'), backgroundColor: AppColors.primary),
                          );
                        },
                      ),
                    ]),
                    if (analisis != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.smart_toy_outlined, size: 13, color: Color(0xFF6366F1)),
                            const SizedBox(width: 4),
                            const Text('Análisis IA',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                color: Color(0xFF6366F1))),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            '${analisis['etiqueta_es'] ?? ''} · '
                            'Severidad: ${analisis['severidad_es'] ?? ''}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF1E1B4B),
                              fontWeight: FontWeight.w500),
                          ),
                          if ((analisis['descripcion_auto'] as String?) != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(analisis['descripcion_auto'] as String,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                            ),
                        ]),
                      ),
                    ],
                  ]),
                );
              }),
            ],
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
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _uploading ? null : _irInicio,
                child: const Text('Omitir y volver al inicio'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _uploading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EnviarAudioPage(incidenteId: widget.incidenteId),
                          ),
                        );
                      },
                icon: const Icon(Icons.mic_none_rounded),
                label: const Text('Grabar / enviar audio'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _uploading ? null : _irInicio,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Listo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
