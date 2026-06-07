import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:taller_movil/services/api_config.dart';
import 'package:taller_movil/services/api_helper.dart';
import 'package:taller_movil/services/auth_service.dart';

class AsignacionModel {
  final int id;
  final int incidenteId;
  final int tallerId;
  final int? tecnicoId;
  final String estado;
  final int? eta;
  final String? observacion;
  final String createdAt;
  final bool esSos;

  AsignacionModel({
    required this.id,
    required this.incidenteId,
    required this.tallerId,
    this.tecnicoId,
    required this.estado,
    this.eta,
    this.observacion,
    required this.createdAt,
    this.esSos = false,
  });

  factory AsignacionModel.fromJson(Map<String, dynamic> j) => AsignacionModel(
        id: j['id'] as int,
        incidenteId: j['incidente_id'] as int,
        tallerId: j['taller_id'] as int,
        tecnicoId: j['tecnico_id'] as int?,
        estado: j['estado'] as String,
        eta: j['eta'] as int?,
        observacion: j['observacion'] as String?,
        createdAt: j['created_at'] as String,
        esSos: j['es_sos'] as bool? ?? false,
      );
}

class RepuestoItem {
  final String descripcion;
  final int cantidad;

  RepuestoItem({required this.descripcion, required this.cantidad});

  Map<String, dynamic> toJson() => {'descripcion': descripcion, 'cantidad': cantidad};

  factory RepuestoItem.fromJson(Map<String, dynamic> j) =>
      RepuestoItem(descripcion: j['descripcion'] as String, cantidad: j['cantidad'] as int);
}

class ServicioRealizadoModel {
  final int id;
  final int asignacionId;
  final String descripcionTrabajo;
  final String? repuestos;
  final String? observaciones;
  final String fechaCierre;

  ServicioRealizadoModel({
    required this.id,
    required this.asignacionId,
    required this.descripcionTrabajo,
    this.repuestos,
    this.observaciones,
    required this.fechaCierre,
  });

  factory ServicioRealizadoModel.fromJson(Map<String, dynamic> j) =>
      ServicioRealizadoModel(
        id: j['id'] as int,
        asignacionId: j['asignacion_id'] as int,
        descripcionTrabajo: j['descripcion_trabajo'] as String,
        repuestos: j['repuestos'] as String?,
        observaciones: j['observaciones'] as String?,
        fechaCierre: j['fecha_cierre'] as String,
      );

  List<RepuestoItem> get repuestosParsed {
    if (repuestos == null) return [];
    try {
      final list = jsonDecode(repuestos!) as List<dynamic>;
      return list.map((e) => RepuestoItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}

class TallerService {
  static final _baseUrl = ApiConfig.api('talleres');

  final _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<AsignacionModel>> listarMisAsignacionesCliente() async {
    final res = await ejecutarPeticion(
      http.get(
        Uri.parse(ApiConfig.api('solicitudes/mis-asignaciones')),
        headers: await _headers(),
      ),
    );
    verificarRespuesta(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => AsignacionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AsignacionModel>> listarAsignacionesActivas() async {
    final res = await ejecutarPeticion(
      http.get(
        Uri.parse('$_baseUrl/asignaciones/activas'),
        headers: await _headers(),
      ),
    );
    verificarRespuesta(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => AsignacionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AsignacionModel>> listarAsignacionesListas() async {
    final res = await ejecutarPeticion(
      http.get(
        Uri.parse('$_baseUrl/servicios/listas'),
        headers: await _headers(),
      ),
    );
    verificarRespuesta(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => AsignacionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ServicioRealizadoModel> registrarServicio({
    required int asignacionId,
    required String descripcionTrabajo,
    List<RepuestoItem>? repuestos,
    String? observaciones,
  }) async {
    final body = <String, dynamic>{
      'asignacion_id': asignacionId,
      'descripcion_trabajo': descripcionTrabajo,
      if (repuestos != null && repuestos.isNotEmpty)
        'repuestos': repuestos.map((r) => r.toJson()).toList(),
      if (observaciones != null && observaciones.isNotEmpty) 'observaciones': observaciones,
    };
    final res = await ejecutarPeticion(
      http.post(
        Uri.parse('$_baseUrl/servicios'),
        headers: await _headers(),
        body: jsonEncode(body),
      ),
    );
    verificarRespuesta(res, esperado: 201);
    return ServicioRealizadoModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<ServicioRealizadoModel>> listarServiciosRealizados() async {
    final res = await ejecutarPeticion(
      http.get(
        Uri.parse('$_baseUrl/servicios'),
        headers: await _headers(),
      ),
    );
    verificarRespuesta(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => ServicioRealizadoModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AsignacionModel> actualizarEstado(
    int asignacionId,
    String nuevoEstado, {
    String? observacion,
  }) async {
    final body = <String, dynamic>{'estado': nuevoEstado};
    if (observacion != null && observacion.isNotEmpty) body['observacion'] = observacion;

    final res = await ejecutarPeticion(
      http.patch(
        Uri.parse('$_baseUrl/asignaciones/$asignacionId/estado'),
        headers: await _headers(),
        body: jsonEncode(body),
      ),
    );
    verificarRespuesta(res);
    return AsignacionModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> rechazarSolicitud(int incidenteId) async {
    final res = await ejecutarPeticion(
      http.patch(
        Uri.parse('${ApiConfig.api('solicitudes')}/$incidenteId/rechazar'),
        headers: await _headers(),
        body: jsonEncode({}),
      ),
    );
    verificarRespuesta(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<AsignacionModel> confirmarLlegadaTecnico(int asignacionId) async {
    final res = await ejecutarPeticion(
      http.patch(
        Uri.parse('$_baseUrl/asignaciones/$asignacionId/confirmar-llegada'),
        headers: await _headers(),
        body: jsonEncode({}),
      ),
    );
    verificarRespuesta(res);
    return AsignacionModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
