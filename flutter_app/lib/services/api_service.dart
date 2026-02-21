import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    return _authService.authHeaders();
  }

  Future<http.Response> get(String url) async {
    final headers = await _getHeaders();
    return await http.get(Uri.parse(url), headers: headers);
  }

  Future<http.Response> post(String url, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    return await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> put(String url, [Map<String, dynamic>? body]) async {
    final headers = await _getHeaders();
    return await http.put(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> delete(String url) async {
    final headers = await _getHeaders();
    return await http.delete(Uri.parse(url), headers: headers);
  }

  Map<String, dynamic> parseResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    } catch (_) {
      return {
        'error': 'Unexpected server response (${response.statusCode})',
        'raw': response.body,
      };
    }
  }

  bool isSuccess(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }
}
