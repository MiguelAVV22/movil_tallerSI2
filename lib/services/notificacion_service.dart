import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_helper.dart';
import 'auth_service.dart';

class NotificacionService {
  static final _base = ApiConfig.api('comunicacion');

  final _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> listarMias() async {
    final headers = await _headers();
    final rutas = ['$_base/notificaciones/mias', '$_base/notificaciones'];
    http.Response? ultimo;

    for (final ruta in rutas) {
      final res = await ejecutarPeticion(http.get(Uri.parse(ruta), headers: headers));
      ultimo = res;
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        } else if (decoded is Map<String, dynamic>) {
          return [];
        }
      }
      if (res.statusCode != 404) {
        verificarRespuesta(res);
      }
    }

    verificarRespuesta(ultimo!);
    return const [];
  }

  Future<Map<String, dynamic>> marcarLeida(int id) async {
    final res = await ejecutarPeticion(
      http.patch(
        Uri.parse('$_base/notificaciones/$id/leida'),
        headers: await _headers(),
        body: jsonEncode({}),
      ),
    );
    if (res.statusCode == 404) {
      return {'id': id, 'leida': true};
    }
    verificarRespuesta(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
