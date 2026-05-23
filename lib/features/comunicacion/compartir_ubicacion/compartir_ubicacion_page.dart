import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/comunicacion_service.dart';

// CU17 — Compartir ubicación (vista del técnico)
// El técnico activa esta pantalla cuando está "en_camino" para que el
// cliente pueda ver su posición en tiempo real cada 5 segundos.
class CompartirUbicacionPage extends StatefulWidget {
  const CompartirUbicacionPage({super.key});

  @override
  State<CompartirUbicacionPage> createState() =>
      _CompartirUbicacionPageState();
}

class _CompartirUbicacionPageState extends State<CompartirUbicacionPage> {
  final _service = ComunicacionService();

  Timer?  _timer;
  bool    _compartiendo        = false;
  String? _error;
  double? _latitud;
  double? _longitud;
  String  _ultimaActualizacion = '--';
  int     _envios              = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _iniciarCompartir() async {
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      setState(() =>
          _error = 'Permiso de ubicación denegado. Habilítalo en Ajustes.');
      return;
    }

    setState(() {
      _compartiendo = true;
      _error        = null;
    });
    await _enviarUbicacion();
    _timer =
        Timer.periodic(const Duration(seconds: 5), (_) => _enviarUbicacion());
  }

  void _detenerCompartir() {
    _timer?.cancel();
    setState(() => _compartiendo = false);
  }

  Future<void> _enviarUbicacion() async {
    if (!mounted) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _service.actualizarMiUbicacion(
        latitud: pos.latitude,
        longitud: pos.longitude,
      );
      if (!mounted) return;
      final now = TimeOfDay.now();
      setState(() {
        _latitud             = pos.latitude;
        _longitud            = pos.longitude;
        _ultimaActualizacion =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        _envios++;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            const Text(
              'Compartir Ubicación',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _compartiendo
                  ? 'Tu ubicación se está enviando al cliente'
                  : 'Activa para que el cliente te vea en el mapa',
              style: const TextStyle(fontSize: 13, color: AppColors.grey),
            ),

            const SizedBox(height: 28),

            // Tarjeta de estado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _compartiendo
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFF3F4F6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _compartiendo
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _compartiendo
                          ? Icons.location_on
                          : Icons.location_off_outlined,
                      size: 40,
                      color: _compartiendo ? AppColors.success : AppColors.grey,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _compartiendo ? 'Compartiendo' : 'Inactivo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _compartiendo ? AppColors.success : AppColors.grey,
                    ),
                  ),
                  if (_latitud != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${_latitud!.toStringAsFixed(5)}, '
                      '${_longitud!.toStringAsFixed(5)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.grey),
                    ),
                  ],
                  if (_envios > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$_envios ${_envios == 1 ? 'envío' : 'envíos'} realizados',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.grey),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Filas informativas
            if (_compartiendo) ...[
              _InfoRow(
                Icons.sync,
                'Actualización automática',
                'Cada 5 segundos',
              ),
              const SizedBox(height: 10),
              _InfoRow(
                Icons.access_time_outlined,
                'Último envío',
                _ultimaActualizacion,
              ),
              const SizedBox(height: 20),
            ],

            // Error
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),

            // Botón principal
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _compartiendo ? _detenerCompartir : _iniciarCompartir,
                icon: Icon(
                  _compartiendo
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outlined,
                  size: 20,
                ),
                label: Text(
                  _compartiendo
                      ? 'Detener compartición'
                      : 'Iniciar compartición',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _compartiendo ? AppColors.danger : AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFF3F4F6), height: 1),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.text),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          const Text(
            'Mi Ubicación',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget auxiliar ───────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.grey)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
        ],
      ),
    );
  }
}
