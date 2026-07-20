import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'api_config.dart';
import 'api_helper.dart';
import 'package:taller_movil/services/push_notification_service.dart';

class AuthService {
  static final _baseUrl = ApiConfig.api('acceso');
  static const _tokenKey = 'access_token';
  static const _userKey = 'taller_user';

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await ejecutarPeticion(
      http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await _saveSession(data);
      return data;
    }
    throw Exception(detalleRespuesta(res, fallback: 'Error al iniciar sesion'));
  }

  Future<List<Map<String, dynamic>>> getPublicTenants() async {
    final res = await ejecutarPeticion(
      http.get(
        Uri.parse('$_baseUrl/tenants/public'),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception(detalleRespuesta(res, fallback: 'Error al obtener redes de talleres'));
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
    required int tenantId,
    String? fullName,
    String? telefono,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'username': username,
      'password': password,
      'tenant_id': tenantId,
      if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
    };
    final res = await ejecutarPeticion(
      http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await _saveSession(data);
      return data;
    }
    throw Exception(detalleRespuesta(res, fallback: 'Error al registrarse'));
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final token = await getToken();
    final res = await ejecutarPeticion(
      http.post(
        Uri.parse('$_baseUrl/change-password'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'current_password': currentPassword, 'new_password': newPassword}),
      ),
    );
    verificarRespuesta(res);
  }

  Future<void> requestReset(String email) async {
    final res = await ejecutarPeticion(
      http.post(
        Uri.parse('$_baseUrl/request-reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ),
    );
    verificarRespuesta(res);
  }

  Future<void> resetPassword(String email, String code, String newPassword) async {
    final res = await ejecutarPeticion(
      http.post(
        Uri.parse('$_baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code, 'new_password': newPassword}),
      ),
    );
    verificarRespuesta(res);
  }

  Future<void> logout() async {
    final token = await getToken();
    final fcmToken = PushNotificationService.fcmToken;
    if (token != null && fcmToken != null) {
      try {
        await http.delete(
          Uri.parse('${ApiConfig.api('comunicacion')}/notificaciones/token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'token': fcmToken}),
        );
      } catch (e) {
        debugPrint('Error al eliminar token FCM en logout: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<bool> isLoggedIn() async => (await getToken()) != null;

  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    return raw != null ? jsonDecode(raw) as Map<String, dynamic> : null;
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, data['access_token'] as String);
    await prefs.setString(_userKey, jsonEncode(data['user']));

    final fcmToken = PushNotificationService.fcmToken;
    if (fcmToken != null) {
      await enviarTokenFCM(fcmToken, data['access_token'] as String);
    }
  }

  Future<void> enviarTokenFCM(String fcmToken, [String? explicitToken]) async {
    final token = explicitToken ?? await getToken();
    if (token == null) return;

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.api('comunicacion')}/notificaciones/token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'token': fcmToken}),
      );
      if (res.statusCode == 200) {
        debugPrint('Token FCM registrado correctamente en el servidor.');
      } else {
        debugPrint('Error al registrar token FCM: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('Excepción al enviar token FCM: $e');
    }
  }
}
