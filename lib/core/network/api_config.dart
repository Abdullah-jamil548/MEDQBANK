class ApiConfig {
  /// Override at run time if needed:
  /// flutter run --dart-define=API_BASE_URL=https://other-host/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://test-00m5.onrender.com/api/v1',
  );
}
