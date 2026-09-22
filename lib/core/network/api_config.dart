class ApiConfig {
  /// Override at run time:
  /// flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );
}
