import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  const ApiConfig._();

  // Puedes cambiar esto al compilar:
  // flutter run --dart-define=API_BASE_URL=http://192.168.1.35:8000
  static String get origin {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return kIsWeb ? 'http://localhost:8000' : 'http://192.168.0.11:8000';
  }

  static String api(String path) => '$origin/api/$path';

  static String get wsBaseUrl {
    try {
      final uri = Uri.parse(origin);
      final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final portPart = uri.hasPort ? ':${uri.port}' : '';
      return '$scheme://${uri.host}$portPart';
    } catch (_) {
      // Fallback
      return origin.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    }
  }

  static String asset(String path) {
    if (path.isEmpty) return origin;
    return path.startsWith('/') ? '$origin$path' : '$origin/$path';
  }
}
