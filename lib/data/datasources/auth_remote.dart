import '../../core/network/api_client.dart';

class AuthRemote {
  AuthRemote(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'full_name': fullName,
        'email': email,
        'password': password,
      },
    );
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _api.get<Map<String, dynamic>>('/me');
    return res.data ?? {};
  }
}
