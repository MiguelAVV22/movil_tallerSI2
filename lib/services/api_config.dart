class ApiConfig {
  const ApiConfig._();

  // Puedes cambiar esto al compilar:
  // flutter run --dart-define=API_BASE_URL=http://192.168.1.35:8000
  static const String origin = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static String api(String path) => '$origin/api/$path';

  static String asset(String path) {
    if (path.isEmpty) return origin;
    return path.startsWith('/') ? '$origin$path' : '$origin/$path';
  }
}
