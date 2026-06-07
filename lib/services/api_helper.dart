import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class TokenExpiradoException implements Exception {}

const Duration _defaultTimeout = Duration(seconds: 20);
const String _mensajeConexion =
    'No se pudo conectar con el servidor. Verifica tu internet y la URL del backend.';

Future<http.Response> ejecutarPeticion(
  Future<http.Response> request, {
  Duration timeout = _defaultTimeout,
}) async {
  try {
    return await request.timeout(timeout);
  } on TimeoutException {
    throw Exception(_mensajeConexion);
  } on SocketException {
    throw Exception(_mensajeConexion);
  } on http.ClientException {
    throw Exception(_mensajeConexion);
  }
}

Future<http.Response> ejecutarMultipart(
  http.MultipartRequest request, {
  Duration timeout = _defaultTimeout,
}) async {
  try {
    final streamed = await request.send().timeout(timeout);
    return await http.Response.fromStream(streamed);
  } on TimeoutException {
    throw Exception(_mensajeConexion);
  } on SocketException {
    throw Exception(_mensajeConexion);
  } on http.ClientException {
    throw Exception(_mensajeConexion);
  }
}

String detalleRespuesta(http.Response res, {String fallback = 'Error de servidor'}) {
  if (res.body.isEmpty) return fallback;
  try {
    final body = jsonDecode(res.body);
    if (body is Map<String, dynamic>) {
      final detail = body['detail'];
      if (detail != null && detail.toString().trim().isNotEmpty) {
        return detail.toString();
      }
      final msg = body['msg'];
      if (msg != null && msg.toString().trim().isNotEmpty) {
        return msg.toString();
      }
    }
  } catch (_) {}
  return fallback;
}

void verificarRespuesta(http.Response res, {int esperado = 200}) {
  if (res.statusCode == esperado) return;
  if (res.statusCode == 401 || res.statusCode == 403) {
    throw TokenExpiradoException();
  }
  throw Exception(detalleRespuesta(res, fallback: 'Error ${res.statusCode}'));
}
