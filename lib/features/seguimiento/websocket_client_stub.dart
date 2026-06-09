abstract class BaseWebSocketClient {
  void connect(
    String url, {
    required void Function() onOpen,
    required void Function(String message) onMessage,
    required void Function(dynamic error) onError,
    required void Function() onClose,
  });
  void send(String message);
  void close();
  bool get isConnected;
}

BaseWebSocketClient createWebSocketClient() =>
    throw UnsupportedError('Cannot create websocket client without platforms');
