import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taller_movil/services/api_config.dart';
import 'package:taller_movil/services/api_helper.dart';
import 'package:taller_movil/services/auth_service.dart';

class SosService {
  static final _baseUrl = ApiConfig.api('acceso');
  final _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> listarContactos() async {
    final res = await ejecutarPeticion(
      http.get(
        Uri.parse('$_baseUrl/contactos-emergencia'),
        headers: await _headers(),
      ),
    );
    verificarRespuesta(res);
    final data = jsonDecode(res.body) as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> registrarContacto({
    required String nombre,
    required String telefono,
    required String relacion,
  }) async {
    final res = await ejecutarPeticion(
      http.post(
        Uri.parse('$_baseUrl/contactos-emergencia'),
        headers: await _headers(),
        body: jsonEncode({
          'nombre': nombre,
          'telefono': telefono,
          'relacion': relacion,
        }),
      ),
    );
    verificarRespuesta(res, esperado: 201);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> eliminarContacto(int contactoId) async {
    final res = await ejecutarPeticion(
      http.delete(
        Uri.parse('$_baseUrl/contactos-emergencia/$contactoId'),
        headers: await _headers(),
      ),
    );
    verificarRespuesta(res, esperado: 204);
  }

  Future<Position?> obtenerUbicacionActual() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> dispararSOS(Map<String, dynamic> contacto, {bool usarWhatsapp = true}) async {
    final String telefono = contacto['telefono'] ?? '';
    if (telefono.isEmpty) return false;

    // Obtener ubicación
    final pos = await obtenerUbicacionActual();
    String mapsLink = '';
    if (pos != null) {
      mapsLink = '\nUbicación actual: https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';
    }

    final mensaje = '¡ALERTA DE SOS! Estoy sufriendo una emergencia con mi vehículo y necesito ayuda.$mapsLink';
    final textEncoded = Uri.encodeComponent(mensaje);

    // Limpiar prefijo si es necesario
    String finalPhone = telefono.replaceAll(RegExp(r'\D'), '');
    if (!finalPhone.startsWith('591') && finalPhone.length == 8) {
      finalPhone = '591$finalPhone';
    }

    Uri url;
    if (usarWhatsapp) {
      url = Uri.parse('https://wa.me/$finalPhone?text=$textEncoded');
    } else {
      url = Uri.parse('sms:$telefono?body=$textEncoded');
    }

    // Intentamos con LaunchMode.externalApplication (abre la app nativa si está disponible)
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (_) {}

    // Si falló (por ejemplo, en Chrome/web), intentamos el modo por defecto (abre nueva pestaña)
    try {
      final launched = await launchUrl(url);
      if (launched) return true;
    } catch (_) {}

    // Fallback con la API de Whatsapp tradicional
    if (usarWhatsapp) {
      final fallbackUrl = Uri.parse('https://api.whatsapp.com/send?phone=$finalPhone&text=$textEncoded');
      try {
        final launched = await launchUrl(fallbackUrl);
        if (launched) return true;
      } catch (_) {}
    }

    return false;
  }
}
