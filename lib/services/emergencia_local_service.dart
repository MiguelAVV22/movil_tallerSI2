import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EmergenciaLocalService {
  static const String _key = 'pending_emergencias';

  /// Guarda una emergencia de forma local.
  static Future<void> guardarEmergenciaLocal({
    required int vehiculoId,
    String? descripcion,
    required String prioridad,
    double? latitud,
    double? longitud,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Obtener la lista actual de emergencias locales pendientes
    final String? raw = prefs.getString(_key);
    final List<dynamic> list = raw != null ? jsonDecode(raw) as List<dynamic> : [];

    // Generar un ID local único e incluir todos los campos requeridos
    final String localId = DateTime.now().millisecondsSinceEpoch.toString();
    final Map<String, dynamic> nuevaEmergencia = {
      'local_id': localId,
      'vehiculo_id': vehiculoId,
      'descripcion': descripcion,
      'prioridad': prioridad,
      'latitud': latitud,
      'longitud': longitud,
      'fecha_creacion_local': DateTime.now().toIso8601String(),
      'estado_sync': 'PENDIENTE',
      'intentos_sync': 0,
      'error_sync': null,
    };

    list.add(nuevaEmergencia);
    await prefs.setString(_key, jsonEncode(list));
  }

  /// Retorna la lista de todas las emergencias guardadas localmente.
  static Future<List<Map<String, dynamic>>> obtenerEmergenciasLocales() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  /// Actualiza los datos de una emergencia local específica por su local_id.
  static Future<void> actualizarEmergenciaLocal(String localId, Map<String, dynamic> datosActualizados) async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null) return;

    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    for (int i = 0; i < list.length; i++) {
      final map = Map<String, dynamic>.from(list[i] as Map);
      if (map['local_id'] == localId) {
        map.addAll(datosActualizados);
        list[i] = map;
        break;
      }
    }
    await prefs.setString(_key, jsonEncode(list));
  }

  /// Retorna las emergencias locales que están pendientes de sincronización (PENDIENTE o ERROR).
  static Future<List<Map<String, dynamic>>> obtenerPendientesSync() async {
    final todas = await obtenerEmergenciasLocales();
    return todas.where((x) => x['estado_sync'] == 'PENDIENTE' || x['estado_sync'] == 'ERROR').toList();
  }
}
