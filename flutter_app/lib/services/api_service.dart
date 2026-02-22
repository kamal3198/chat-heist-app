import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  final AuthService _authService = AuthService();
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const List<Duration> _retryBackoff = <Duration>[
    Duration(milliseconds: 800),
    Duration(seconds: 2),
  ];

  Future<Map<String, String>> _getHeaders() async {
    return _authService.authHeaders();
  }

  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() request,
  ) async {
    Object? lastError;
    final attempts = _retryBackoff.length + 1;

    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        return await request().timeout(_requestTimeout);
      } on TimeoutException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      } on HttpException catch (e) {
        lastError = e;
      }

      if (attempt < _retryBackoff.length) {
        await Future.delayed(_retryBackoff[attempt]);
      }
    }

    throw lastError ?? TimeoutException('Request failed');
  }

  Future<http.Response> get(String url) async {
    final headers = await _getHeaders();
    return _requestWithRetry(() => http.get(Uri.parse(url), headers: headers));
  }

  Future<http.Response> post(String url, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    return _requestWithRetry(
      () => http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
  }

  Future<http.Response> put(String url, [Map<String, dynamic>? body]) async {
    final headers = await _getHeaders();
    return _requestWithRetry(
      () => http.put(
        Uri.parse(url),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Future<http.Response> delete(String url) async {
    final headers = await _getHeaders();
    return _requestWithRetry(() => http.delete(Uri.parse(url), headers: headers));
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
