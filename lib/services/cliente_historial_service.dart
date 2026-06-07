import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_helper.dart' show TokenExpiradoException, verificarRespuesta;
import 'auth_service.dart';

class ClienteHistorialService {
  static String get _baseUrl => ApiConfig.api('reportes');

  final _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<dynamic>> listar() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/historial/cliente'),
      headers: await _headers(),
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw TokenExpiradoException();
    }
    verificarRespuesta(res, esperado: 200);
    return (jsonDecode(res.body) as List);
  }
}
