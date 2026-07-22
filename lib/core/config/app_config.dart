import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class AppConfig {
  static const _railwayUrl = 'https://backend-tallersi2.onrender.com';
  static const _localWeb   = 'http://localhost:8000';
  static const _localAndroid = 'http://192.168.0.11:8000';

  static String get baseUrl {
    return _railwayUrl;
  }
}
