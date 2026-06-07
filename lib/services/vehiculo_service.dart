import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_helper.dart';
import 'auth_service.dart';

class VehiculoService {
  static final _baseUrl = ApiConfig.api('acceso');
  final _auth = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> registrarVehiculo({
    required String placa,
    required String marca,
    required String modelo,
    required int anio,
    required String color,
  }) async {
    final res = await ejecutarPeticion(
      http.post(
        Uri.parse('$_baseUrl/vehiculos'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'placa': placa,
          'marca': marca,
          'modelo': modelo,
          'anio': anio,
          'color': color,
        }),
      ),
    );
    verificarRespuesta(res, esperado: 201);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listarVehiculos() async {
    final res = await ejecutarPeticion(
      http.get(
        Uri.parse('$_baseUrl/vehiculos'),
        headers: await _authHeaders(),
      ),
    );
    verificarRespuesta(res);
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> actualizarVehiculo({
    required int id,
    String? placa,
    String? marca,
    String? modelo,
    int? anio,
    String? color,
  }) async {
    final body = <String, dynamic>{
      if (placa != null) 'placa': placa,
      if (marca != null) 'marca': marca,
      if (modelo != null) 'modelo': modelo,
      if (anio != null) 'anio': anio,
      if (color != null) 'color': color,
    };
    final res = await ejecutarPeticion(
      http.patch(
        Uri.parse('$_baseUrl/vehiculos/$id'),
        headers: await _authHeaders(),
        body: jsonEncode(body),
      ),
    );
    verificarRespuesta(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> eliminarVehiculo(int id) async {
    final res = await ejecutarPeticion(
      http.delete(
        Uri.parse('$_baseUrl/vehiculos/$id'),
        headers: await _authHeaders(),
      ),
    );
    verificarRespuesta(res, esperado: 204);
  }

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
      if (latitud != null) 'latitud': latitud,
      if (longitud != null) 'longitud': longitud,
    };
    final res = await ejecutarPeticion(
      http.post(
        Uri.parse('$_baseUrl/talleres'),
        headers: await _authHeaders(),
        body: jsonEncode(body),
      ),
    );
    verificarRespuesta(res, esperado: 201);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
