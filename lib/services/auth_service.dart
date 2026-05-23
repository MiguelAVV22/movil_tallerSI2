import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taller_movil/core/config/app_config.dart';

class AuthService {
  static final _baseUrl = '${AppConfig.baseUrl}/api/acceso';
  static const _tokenKey  = 'access_token';
  static const _userKey   = 'taller_user';

  // ── CU02 - Iniciar sesión ────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await _saveSession(data);
      return data;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? 'Error al iniciar sesión');
  }

  // ── CU01 - Registrarse ───────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
    String? telefono,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'username': username,
      'password': password,
      if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
    };
    final res = await http.post(
      Uri.parse('$_baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await _saveSession(data);
      return data;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? 'Error al registrarse');
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/change-password'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'current_password': currentPassword, 'new_password': newPassword}),
    );
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Error al cambiar la contraseña');
    }
  }

  Future<void> requestReset(String email) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/request-reset'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Error al enviar el correo');
    }
  }

  Future<void> resetPassword(String email, String code, String newPassword) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code, 'new_password': newPassword}),
    );
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Error al restablecer la contraseña');
    }
  }

  Future<void> logout() async {
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
  }
}
