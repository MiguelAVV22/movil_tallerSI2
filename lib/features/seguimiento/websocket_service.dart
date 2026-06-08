import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:taller_movil/services/api_config.dart';

class WebSocketService {
  final int incidenteId;
  final void Function(Map<String, dynamic> data) onMessageReceived;
  final void Function(dynamic error) onError;
  final void Function() onDone;

  WebSocket? _socket;
  bool _isConnecting = false;

  WebSocketService({
    required this.incidenteId,
    required this.onMessageReceived,
    required this.onError,
    required this.onDone,
  });

  bool get isConnected => _socket != null && _socket!.readyState == WebSocket.open;
  bool get isConnecting => _isConnecting;

  Future<void> connect() async {
    if (isConnected || _isConnecting) return;

    _isConnecting = true;
    final url = '${ApiConfig.wsBaseUrl}/ws/seguimiento/$incidenteId';
    debugPrint('WebSocketService: Conectándose a $url');

    try {
      _socket = await WebSocket.connect(url).timeout(const Duration(seconds: 10));
      _isConnecting = false;
      debugPrint('WebSocketService: Conectado exitosamente');

      _socket!.listen(
        (message) {
          try {
            final decoded = jsonDecode(message as String);
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
          onError(err);
        },
        onDone: () {
          debugPrint('WebSocketService: Conexión cerrada');
          _socket = null;
          _isConnecting = false;
          onDone();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('WebSocketService: Falló conexión: $e');
      _socket = null;
      _isConnecting = false;
      onError(e);
      onDone();
    }
  }

  void sendMessage(Map<String, dynamic> data) {
    if (isConnected) {
      _socket!.add(jsonEncode(data));
    } else {
      debugPrint('WebSocketService: No se puede enviar, no conectado');
    }
  }

  Future<void> disconnect() async {
    if (_socket != null) {
      await _socket!.close();
      _socket = null;
    }
    _isConnecting = false;
  }
}
