import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class AppConfig {
  static const _railwayUrl = 'https://tallerbackend-production-06ad.up.railway.app';
  static const _localWeb   = 'http://localhost:8000';
  static const _localAndroid = 'http://10.0.2.2:8000';

  static String get baseUrl {
    if (kReleaseMode) return _railwayUrl;
    return kIsWeb ? _localWeb : _localAndroid;
  }
}
