class ApiConfig {
  /// Override at run time if needed:
  /// flutter run --dart-define=API_BASE_URL=https://other-host/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://test-00m5.onrender.com/api/v1',
  );

  /// WebSocket URL derived from HTTP API base.
  static String get wsUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final path = uri.path.endsWith('/') ? '${uri.path}ws' : '${uri.path}/ws';
    return Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: path,
    ).toString();
  }
}
