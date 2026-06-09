import 'dart:html' as html;
import 'websocket_client_stub.dart';
export 'websocket_client_stub.dart';

class WebWebSocketClient implements BaseWebSocketClient {
  html.WebSocket? _socket;

  @override
  void connect(
    String url, {
    required void Function() onOpen,
    required void Function(String message) onMessage,
    required void Function(dynamic error) onError,
    required void Function() onClose,
  }) {
    try {
      _socket = html.WebSocket(url);
      _socket!.onOpen.listen((_) {
        onOpen();
      });
      _socket!.onMessage.listen((event) {
        onMessage(event.data.toString());
      });
      _socket!.onError.listen((err) {
        onError(err);
      });
      _socket!.onClose.listen((_) {
        onClose();
      });
    } catch (e) {
      onError(e);
      onClose();
    }
  }

  @override
  void send(String message) {
    if (isConnected) {
      _socket!.send(message);
    }
  }

  @override
  void close() {
    _socket?.close();
    _socket = null;
  }

  @override
  bool get isConnected => _socket != null && _socket!.readyState == html.WebSocket.OPEN;
}

BaseWebSocketClient createWebSocketClient() => WebWebSocketClient();
