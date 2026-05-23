import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:taller_movil/core/config/app_config.dart';
import 'auth_service.dart';
import 'api_helper.dart';

class VehiculoService {
  static final _baseUrl = '${AppConfig.baseUrl}/api/acceso';
  final _auth = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── CU03 - Registrar Vehículo ─────────────────────────────
  Future<Map<String, dynamic>> registrarVehiculo({
    required String placa,
    required String marca,
    required String modelo,
    required int anio,
    required String color,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/vehiculos'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'placa': placa,
        'marca': marca,
        'modelo': modelo,
        'anio': anio,
        'color': color,
      }),
    );
    verificarRespuesta(res, esperado: 201);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── CU04 - Listar Vehículos ───────────────────────────────
  Future<List<Map<String, dynamic>>> listarVehiculos() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/vehiculos'),
      headers: await _authHeaders(),
    );
    verificarRespuesta(res);
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  // ── Actualizar vehículo (CU04) ────────────────────────────
  Future<Map<String, dynamic>> actualizarVehiculo({
    required int id,
    String? placa,
    String? marca,
    String? modelo,
    int? anio,
    String? color,
  }) async {
    final body = <String, dynamic>{
      'placa': ?placa,
      'marca': ?marca,
      'modelo': ?modelo,
      'anio': ?anio,
      'color': ?color,
    };
    final res = await http.patch(
      Uri.parse('$_baseUrl/vehiculos/$id'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    verificarRespuesta(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Eliminar Vehículo ────────────────────────────────────
  Future<void> eliminarVehiculo(int id) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/vehiculos/$id'),
      headers: await _authHeaders(),
    );
    verificarRespuesta(res, esperado: 204);
  }

  // ── CU12 - Registrar Taller ───────────────────────────────
  Future<Map<String, dynamic>> registrarTaller({
    required String nombre,
    required String direccion,
    String? telefono,
    String? emailComercial,
    double? latitud,
    double? longitud,
  }) async {
    final body = <String, dynamic>{
      'nombre': nombre,
      'direccion': direccion,
      if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
      if (emailComercial != null && emailComercial.isNotEmpty) 'email_comercial': emailComercial,
      'latitud': ?latitud,
      'longitud': ?longitud,
    };
    final res = await http.post(
      Uri.parse('$_baseUrl/talleres'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    verificarRespuesta(res, esperado: 201);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
