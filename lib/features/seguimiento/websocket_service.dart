import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:taller_movil/services/api_config.dart';

import 'websocket_client_stub.dart'
    if (dart.library.io) 'websocket_client_io.dart'
    if (dart.library.html) 'websocket_client_web.dart';

class WebSocketService {
  final int incidenteId;
  final void Function(Map<String, dynamic> data) onMessageReceived;
  final void Function(dynamic error) onError;
  final void Function() onDone;

  late final BaseWebSocketClient _client;
  bool _isConnecting = false;
  bool _connected = false;

  WebSocketService({
    required this.incidenteId,
    required this.onMessageReceived,
    required this.onError,
    required this.onDone,
  }) {
    _client = createWebSocketClient();
  }

  bool get isConnected => _connected && _client.isConnected;
  bool get isConnecting => _isConnecting;

  Future<void> connect() async {
    if (isConnected || _isConnecting) return;

    _isConnecting = true;
    final url = '${ApiConfig.wsBaseUrl}/api/seguimiento/ws/$incidenteId';
    debugPrint('WebSocketService: Conectándose a $url');

    try {
      _client.connect(
        url,
        onOpen: () {
          _isConnecting = false;
          _connected = true;
          debugPrint('WebSocketService: Conectado exitosamente');
        },
        onMessage: (message) {
          try {
            final decoded = jsonDecode(message);
            if (decoded is Map<String, dynamic>) {
              onMessageReceived(decoded);
            }
          } catch (e) {
            debugPrint('WebSocketService: Error al decodificar JSON: $e');
          }
        },
        onError: (err) {
          debugPrint('WebSocketService: Error en stream: $err');
          _isConnecting = false;
          _connected = false;
          onError(err);
        },
        onClose: () {
          debugPrint('WebSocketService: Conexión cerrada');
          _isConnecting = false;
          _connected = false;
          onDone();
        },
      );
    } catch (e) {
      debugPrint('WebSocketService: Falló conexión: $e');
      _isConnecting = false;
      _connected = false;
      onError(e);
      onDone();
    }
  }

  void sendMessage(Map<String, dynamic> data) {
    if (isConnected) {
      _client.send(jsonEncode(data));
    } else {
      debugPrint('WebSocketService: No se puede enviar, no conectado');
    }
  }

  Future<void> disconnect() async {
    _client.close();
    _isConnecting = false;
    _connected = false;
  }
}
