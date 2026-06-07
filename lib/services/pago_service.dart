import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_helper.dart' show TokenExpiradoException, verificarRespuesta;
import 'auth_service.dart';

class PagoService {
  static String get _baseUrl => ApiConfig.api('pagos');

  final _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> resumenPago({required int incidenteId}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/incidente/$incidenteId/resumen-pago'),
      headers: await _headers(),
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw TokenExpiradoException();
    }
    if (res.statusCode == 404) {
      final body = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic> : null;
      throw Exception(body?['detail'] ?? 'No hay cotización aceptada');
    }
    verificarRespuesta(res, esperado: 200);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> realizarPago({
    required int cotizacionId,
    String metodo = 'qr',
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/pago'),
      headers: await _headers(),
      body: jsonEncode({'cotizacion_id': cotizacionId, 'metodo': metodo}),
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw TokenExpiradoException();
    }
    verificarRespuesta(res, esperado: 201);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
