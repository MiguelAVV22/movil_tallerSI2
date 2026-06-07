import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';
import 'api_config.dart';
import 'api_helper.dart';

MediaType _fotoMediaType(String? mimeType, String filename) {
  if (mimeType != null && mimeType.isNotEmpty) {
    try {
      return MediaType.parse(mimeType);
    } catch (_) {}
  }
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return MediaType('image', 'png');
  if (lower.endsWith('.webp')) return MediaType('image', 'webp');
  return MediaType('image', 'jpeg');
}

class EmergenciaService {
  static final _baseUrl = ApiConfig.api('emergencias');
  static String get apiOrigin => ApiConfig.origin;

  final _auth = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // CU05 - Reportar emergencia
  Future<Map<String, dynamic>> crearIncidente({
    required int vehiculoId,
    String? descripcion,
    String prioridad = 'media',
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/'),          // barra final para evitar redirect 307
      headers: await _authHeaders(),
      body: jsonEncode({
        'vehiculo_id': vehiculoId,
        if (descripcion != null && descripcion.isNotEmpty) 'descripcion': descripcion,
        'prioridad': prioridad,
      }),
    );
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    final detail = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>)['detail']
        : null;
    throw Exception(detail ?? 'Error al reportar emergencia (${res.statusCode})');
  }

  // CU06 - Enviar ubicación GPS
  Future<Map<String, dynamic>> actualizarUbicacion({
    required int incidenteId,
    required double latitud,
    required double longitud,
  }) async {
    final res = await http.patch(
      Uri.parse('$_baseUrl/$incidenteId/ubicacion'),
      headers: await _authHeaders(),
      body: jsonEncode({'latitud': latitud, 'longitud': longitud}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    final detail = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>)['detail']
        : null;
    throw Exception(detail ?? 'Error al enviar ubicación (${res.statusCode})');
  }

  // Listar incidentes del usuario
  Future<List<Map<String, dynamic>>> listarMisIncidentes() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/mis-incidentes'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Error al cargar incidentes (${res.statusCode})');
  }

  /// CU07 – Subir una foto (multipart, campo `file`). Usa bytes para compatibilidad con Flutter Web.
  Future<Map<String, dynamic>> subirFoto({
    required int incidenteId,
    required Uint8List bytes,
    String filename = 'foto.jpg',
    String? mimeType,
  }) async {
    final token = await _auth.getToken();
    final uri = Uri.parse('$_baseUrl/$incidenteId/fotos');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    var fn = filename.trim();
    if (fn.isEmpty) fn = 'foto.jpg';
    final ct = _fotoMediaType(mimeType, fn);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fn,
        contentType: ct,
      ),
    );
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw TokenExpiradoException();
    }
    final detail = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>)['detail']
        : null;
    throw Exception(detail ?? 'Error al subir la foto (${res.statusCode})');
  }

  /// CU08 – Subir un audio (multipart, campo `file`). Retorna transcripción + clasificación IA.
  Future<Map<String, dynamic>> subirAudio({
    required int incidenteId,
    required Uint8List bytes,
    String filename = 'audio.wav',
    String? mimeType,
    int? duracionSegundos,
  }) async {
    final token = await _auth.getToken();
    final uri   = Uri.parse('$_baseUrl/$incidenteId/audio');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    var fn = filename.trim();
    if (fn.isEmpty) fn = 'audio.wav';
    final ct = mimeType != null && mimeType.isNotEmpty
        ? MediaType.parse(mimeType)
        : MediaType('audio', 'wav');
    request.files.add(http.MultipartFile.fromBytes('file', bytes,
        filename: fn, contentType: ct));
    if (duracionSegundos != null) {
      request.fields['duracion_segundos'] = duracionSegundos.toString();
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 401 || res.statusCode == 403) throw TokenExpiradoException();
    final detail = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>)['detail']
        : null;
    throw Exception(detail ?? 'Error al subir el audio (${res.statusCode})');
  }

  /// CU09 – Actualizar descripción (opcional tras crear el incidente).
  Future<Map<String, dynamic>> actualizarDescripcion({
    required int incidenteId,
    required String descripcion,
  }) async {
    final res = await http.patch(
      Uri.parse('$_baseUrl/$incidenteId/descripcion'),
      headers: await _authHeaders(),
      body: jsonEncode({'descripcion': descripcion}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw TokenExpiradoException();
    }
    final detail = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>)['detail']
        : null;
    throw Exception(detail ?? 'Error al guardar descripción (${res.statusCode})');
  }

  // CU30 – Botón SOS (prioridad alta, auto-selecciona vehículo)
  Future<Map<String, dynamic>> enviarSOS({
    double? latitud,
    double? longitud,
  }) async {
    final body = <String, dynamic>{};
    if (latitud != null) body['latitud'] = latitud;
    if (longitud != null) body['longitud'] = longitud;

    final res = await http.post(
      Uri.parse('$_baseUrl/sos'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 401 || res.statusCode == 403) throw TokenExpiradoException();
    final detail = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>)['detail']
        : null;
    throw Exception(detail ?? 'Error al enviar SOS (${res.statusCode})');
  }

  /// CU10 – Incidente + asignación + URLs de fotos.
  Future<List<Map<String, dynamic>>> listarMisSolicitudes() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/mis-solicitudes'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw TokenExpiradoException();
    }
    throw Exception('Error al cargar solicitudes (${res.statusCode})');
  }

  /// CU11 – Cliente cancela su incidente.
  Future<Map<String, dynamic>> cancelarSolicitud(int incidenteId) async {
    final res = await http.patch(
      Uri.parse('${ApiConfig.api('solicitudes')}/$incidenteId/cancelar'),
      headers: await _authHeaders(),
      body: jsonEncode({}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 401 || res.statusCode == 403) throw TokenExpiradoException();
    final detail = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>)['detail']
        : null;
    throw Exception(detail ?? 'Error al cancelar solicitud (${res.statusCode})');
  }

  /// CU29 – Historial de servicios (cliente y taller).
  /// CU23 - Calificar servicio.
  Future<Map<String, dynamic>> calificarServicio({
    required int incidenteId,
    required int puntaje,
    String? comentario,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/$incidenteId/calificacion'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'puntaje': puntaje,
        if (comentario != null && comentario.isNotEmpty) 'comentario': comentario,
      }),
    );
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 401 || res.statusCode == 403) throw TokenExpiradoException();
    final detail = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>)['detail']
        : null;
    throw Exception(detail ?? 'Error al enviar calificacion (${res.statusCode})');
  }

  /// CU11 - Gestionar solicitud (aceptar/rechazar/cancelar).
  Future<Map<String, dynamic>> gestionarSolicitud({
    required int incidenteId,
    required String estado,
    String? comentario,
  }) async {
    final body = <String, dynamic>{
      'estado': estado,
      if (comentario != null && comentario.isNotEmpty) 'comentario': comentario,
    };
    final res = await http.put(
      Uri.parse('$_baseUrl/$incidenteId/estado'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 401 || res.statusCode == 403) throw TokenExpiradoException();
    final detail = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>)['detail']
        : null;
    throw Exception(detail ?? 'Error al gestionar solicitud (${res.statusCode})');
  }

  Future<List<Map<String, dynamic>>> listarHistorial() async {
    final res = await http.get(
      Uri.parse(ApiConfig.api('reportes/historial')),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    if (res.statusCode == 401 || res.statusCode == 403) throw TokenExpiradoException();
    throw Exception('Error al cargar historial (${res.statusCode})');
  }

  /// CU20 – Realizar pago de una cotización aceptada.
  Future<Map<String, dynamic>> realizarPago({
    required int cotizacionId,
    required String metodo,
  }) async {
    final res = await http.post(
      Uri.parse(ApiConfig.api('pagos/pagos')),
      headers: await _authHeaders(),
      body: jsonEncode({'cotizacion_id': cotizacionId, 'metodo': metodo}),
    );
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 401 || res.statusCode == 403) throw TokenExpiradoException();
    final detail = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>)['detail']
        : null;
    throw Exception(detail ?? 'Error al realizar el pago (${res.statusCode})');
  }

  /// CU20 – Listar cotizaciones del cliente (para pago).
  Future<List<Map<String, dynamic>>> listarMisCotizaciones() async {
    final res = await http.get(
      Uri.parse(ApiConfig.api('pagos/mis-cotizaciones')),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    if (res.statusCode == 401 || res.statusCode == 403) throw TokenExpiradoException();
    throw Exception('Error al cargar cotizaciones (${res.statusCode})');
  }
}
