import 'dart:convert';
import 'package:taller_movil/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class UbicacionTecnicoModel {
  final int tecnicoId;
  final String nombre;
  final double? latitud;
  final double? longitud;
  final String? ultimaActualizacion;
  final String estadoAsignacion;
  final int? eta;

  UbicacionTecnicoModel({
    required this.tecnicoId,
    required this.nombre,
    this.latitud,
    this.longitud,
    this.ultimaActualizacion,
    required this.estadoAsignacion,
    this.eta,
  });

  factory UbicacionTecnicoModel.fromJson(Map<String, dynamic> j) =>
      UbicacionTecnicoModel(
        tecnicoId:            j['tecnico_id'] as int,
        nombre:               j['nombre'] as String,
        latitud:              (j['latitud'] as num?)?.toDouble(),
        longitud:             (j['longitud'] as num?)?.toDouble(),
        ultimaActualizacion:  j['ultima_actualizacion'] as String?,
        estadoAsignacion:     j['estado_asignacion'] as String,
        eta:                  j['eta'] as int?,
      );
}

// ── CU18 ─────────────────────────────────────────────────────

class MensajeModel {
  final int id;
  final int asignacionId;
  final int usuarioId;
  final String remitente;
  final String rol;
  final String contenido;
  final String createdAt;

  MensajeModel({
    required this.id,
    required this.asignacionId,
    required this.usuarioId,
    required this.remitente,
    required this.rol,
    required this.contenido,
    required this.createdAt,
  });

  factory MensajeModel.fromJson(Map<String, dynamic> j) => MensajeModel(
        id:           j['id'] as int,
        asignacionId: j['asignacion_id'] as int,
        usuarioId:    j['usuario_id'] as int,
        remitente:    j['remitente'] as String,
        rol:          j['rol'] as String,
        contenido:    j['contenido'] as String,
        createdAt:    j['created_at'] as String,
      );
}

// ─────────────────────────────────────────────────────────────

class ComunicacionService {
  static final _baseUrl = '${AppConfig.baseUrl}/api/comunicacion';

  final _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // CU17 — Técnico: envía su posición GPS actual al backend
  Future<void> actualizarMiUbicacion({
    required double latitud,
    required double longitud,
  }) async {
    final res = await http.patch(
      Uri.parse('$_baseUrl/tecnicos/mi-ubicacion'),
      headers: await _headers(),
      body: jsonEncode({'latitud': latitud, 'longitud': longitud}),
    );
    if (res.statusCode != 200) {
      final detail = res.body.isNotEmpty
          ? (jsonDecode(res.body) as Map<String, dynamic>)['detail']
          : null;
      throw Exception(detail ?? 'Error al actualizar ubicación (${res.statusCode})');
    }
  }

  // CU17 — Cliente: obtiene la posición actual del técnico asignado
  Future<UbicacionTecnicoModel> obtenerUbicacionTecnico(int asignacionId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/asignaciones/$asignacionId/tecnico-ubicacion'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return UbicacionTecnicoModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    final detail = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>)['detail']
        : null;
    throw Exception(detail ?? 'Error al obtener ubicación (${res.statusCode})');
  }

  // CU18 — Enviar mensaje de chat
  Future<MensajeModel> enviarMensaje({
    required int asignacionId,
    required String contenido,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/mensajes'),
      headers: await _headers(),
      body: jsonEncode({'asignacion_id': asignacionId, 'contenido': contenido}),
    );
    if (res.statusCode == 201) {
      return MensajeModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    final detail = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>)['detail']
        : null;
    throw Exception(detail ?? 'Error al enviar mensaje (${res.statusCode})');
  }

  // CU18 — Listar mensajes de una asignación
  Future<List<MensajeModel>> listarMensajes(int asignacionId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/asignaciones/$asignacionId/mensajes'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list
          .map((e) => MensajeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final detail = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>)['detail']
        : null;
    throw Exception(detail ?? 'Error al listar mensajes (${res.statusCode})');
  }
}
