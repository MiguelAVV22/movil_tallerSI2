import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:taller_movil/services/auth_service.dart';
import 'package:taller_movil/services/emergencia_service.dart';
import 'package:taller_movil/services/emergencia_local_service.dart';
import 'package:taller_movil/services/api_helper.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  SyncService._internal();

  final _connectivity = Connectivity();
  final _authService = AuthService();
  final _emergenciaSvc = EmergenciaService();

  final ValueNotifier<List<String>> logsSincronizacion = ValueNotifier([]);
  final ValueNotifier<bool> estaSincronizando = ValueNotifier(false);

  /// Inicializa la escucha de cambios en la conectividad.
  void inicializar() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final hasConnection = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        sincronizarPendientes();
      }
    });
  }

  /// Limpia la lista de logs de sincronización.
  void limpiarLogs() {
    logsSincronizacion.value = [];
  }

  void _agregarLog(String msg) {
    logsSincronizacion.value = [...logsSincronizacion.value, msg];
  }

  /// Sincroniza las emergencias locales pendientes.
  Future<void> sincronizarPendientes() async {
    // 1. Evitar sincronizaciones concurrentes
    if (estaSincronizando.value) return;

    // 2. Verificar que exista una sesión activa (token JWT válido)
    final loggedIn = await _authService.isLoggedIn();
    if (!loggedIn) return;

    // 3. Obtener emergencias locales pendientes o con error
    final pendientes = await EmergenciaLocalService.obtenerPendientesSync();
    if (pendientes.isEmpty) return;

    estaSincronizando.value = true;
    limpiarLogs();
    _agregarLog('Sincronizando solicitudes pendientes...');

    for (final emer in pendientes) {
      final String localId = emer['local_id'] as String;
      final int vehiculoId = emer['vehiculo_id'] as int;
      final String? descripcion = emer['descripcion'] as String?;
      final String prioridad = emer['prioridad'] as String;
      final double? latitud = emer['latitud'] as double?;
      final double? longitud = emer['longitud'] as double?;
      final int intentos = (emer['intentos_sync'] as int? ?? 0);

      try {
        // Enviar creación del incidente
        final resIncidente = await _emergenciaSvc.crearIncidente(
          vehiculoId: vehiculoId,
          descripcion: descripcion,
          prioridad: prioridad,
        );

        final int backendId = resIncidente['id'] as int;

        // Si se obtuvieron coordenadas GPS, enviar ubicación en un PATCH subsecuente
        if (latitud != null && longitud != null) {
          await _emergenciaSvc.actualizarUbicacion(
            incidenteId: backendId,
            latitud: latitud,
            longitud: longitud,
          );
        }

        // Actualizar localmente a SINCRONIZADO incluyendo ID del backend y fecha
        await EmergenciaLocalService.actualizarEmergenciaLocal(localId, {
          'estado_sync': 'SINCRONIZADO',
          'intentos_sync': intentos + 1,
          'error_sync': null,
          'backend_incidente_id': backendId,
          'fecha_sincronizacion': DateTime.now().toIso8601String(),
        });

        _agregarLog('Solicitud sincronizada correctamente');
      } catch (e) {
        // Manejar específicamente token expirado o error de autenticación (401/403)
        final errorStr = e.toString();
        if (e is TokenExpiradoException || errorStr.contains('401') || errorStr.contains('403')) {
          await EmergenciaLocalService.actualizarEmergenciaLocal(localId, {
            'error_sync': 'Sesión expirada, inicie sesión nuevamente',
            'estado_sync': 'PENDIENTE', // No marcar como ERROR definitivo, mantener PENDIENTE
          });
          _agregarLog('Error al sincronizar solicitud: Sesión expirada');
        } else {
          // Otros errores (red caída, timeout, etc.) se marcan como ERROR y se incrementa el reintento
          await EmergenciaLocalService.actualizarEmergenciaLocal(localId, {
            'estado_sync': 'ERROR',
            'intentos_sync': intentos + 1,
            'error_sync': errorStr.replaceFirst('Exception: ', ''),
          });
          _agregarLog('Error al sincronizar solicitud');
        }
      }
    }

    estaSincronizando.value = false;
  }
}
