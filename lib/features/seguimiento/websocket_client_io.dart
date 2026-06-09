import 'dart:io';
import 'websocket_client_stub.dart';
export 'websocket_client_stub.dart';

class IoWebSocketClient implements BaseWebSocketClient {
  WebSocket? _socket;

  @override
  void connect(
    String url, {
    required void Function() onOpen,
    required void Function(String message) onMessage,
    required void Function(dynamic error) onError,
    required void Function() onClose,
  }) async {
    try {
      _socket = await WebSocket.connect(url).timeout(const Duration(seconds: 10));
      onOpen();
      _socket!.listen(
        (data) {
          onMessage(data as String);
        },
        onError: (err) {
          onError(err);
        },
        onDone: () {
          onClose();
        },
        cancelOnError: true,
      );
    } catch (e) {
      onError(e);
      onClose();
    }
  }

  @override
  void send(String message) {
    if (isConnected) {
      _socket!.add(message);
    }
  }

  @override
  void close() {
    _socket?.close();
    _socket = null;
  }

  @override
  bool get isConnected => _socket != null && _socket!.readyState == WebSocket.open;
}

BaseWebSocketClient createWebSocketClient() => IoWebSocketClient();
