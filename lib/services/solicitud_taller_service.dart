import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:taller_movil/core/config/app_config.dart';
import 'package:taller_movil/services/api_helper.dart';
import 'package:taller_movil/services/auth_service.dart';
import 'package:taller_movil/services/taller_service.dart';

/// CU13 / CU15 – API solicitudes para rol taller.
class SolicitudTallerService {
  static final _base = '${AppConfig.baseUrl}/api/solicitudes';

  final _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> listarDisponibles() async {
    final res = await http.get(Uri.parse('$_base/disponibles'), headers: await _headers());
    verificarRespuesta(res);
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  /// [incidenteId] es el id del incidente (campo `incidente_id` en la lista).
  Future<AsignacionModel> aceptar(int incidenteId, {int? etaMinutos}) async {
    final body = <String, dynamic>{};
    if (etaMinutos != null && etaMinutos > 0) body['eta'] = etaMinutos;
    final res = await http.patch(
      Uri.parse('$_base/$incidenteId/aceptar'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    verificarRespuesta(res);
    return AsignacionModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
