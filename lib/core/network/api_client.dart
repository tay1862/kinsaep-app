import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClientException implements Exception {
  final String message;

  const ApiClientException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  static const Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
  };

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  static Future<void> saveTokens(
    String accessToken,
    String refreshToken,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  static Future<bool> hasSession() async {
    return (await getToken()) != null;
  }

  static Future<String> getBaseUrl() async {
    final settings = await DatabaseHelper.instance.getSettings();
    final serverUrl = (settings['serverUrl'] as String?)?.trim();

    if (serverUrl == null || serverUrl.isEmpty) {
      throw const ApiClientException(
        'Set your server URL in Cloud Connection before using cloud features.',
      );
    }

    final normalized =
        serverUrl.endsWith('/')
            ? serverUrl.substring(0, serverUrl.length - 1)
            : serverUrl;

    return '$normalized/api';
  }

  static Future<String?> getWebSocketUrl() async {
    final settings = await DatabaseHelper.instance.getSettings();
    final serverUrl = (settings['serverUrl'] as String?)?.trim();

    if (serverUrl == null || serverUrl.isEmpty) {
      return null;
    }

    final uri = Uri.parse(serverUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri
        .replace(
          scheme: wsScheme,
          path: uri.path.isEmpty ? '/ws' : '${uri.path}/ws',
        )
        .toString();
  }

  static Future<Map<String, String>> _getHeaders({String? token}) async {
    final resolvedToken = token ?? await getToken();

    if (resolvedToken != null && resolvedToken.isNotEmpty) {
      return {..._defaultHeaders, 'Authorization': 'Bearer $resolvedToken'};
    }

    return _defaultHeaders;
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) => _request('POST', endpoint, body: body);

  static Future<http.Response> get(String endpoint) =>
      _request('GET', endpoint);

  static Future<http.Response> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) => _request('PATCH', endpoint, body: body);

  static Future<http.Response> delete(String endpoint) =>
      _request('DELETE', endpoint);

  static Future<http.Response> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool allowRefresh = true,
  }) async {
    final url = Uri.parse('${await getBaseUrl()}$endpoint');
    final headers = await _getHeaders();

    http.Response response;
    switch (method) {
      case 'POST':
        response = await http.post(
          url,
          headers: headers,
          body: jsonEncode(body ?? const <String, dynamic>{}),
        );
        break;
      case 'PATCH':
        response = await http.patch(
          url,
          headers: headers,
          body: jsonEncode(body ?? const <String, dynamic>{}),
        );
        break;
      case 'DELETE':
        response = await http.delete(url, headers: headers);
        break;
      default:
        response = await http.get(url, headers: headers);
    }

    if (response.statusCode == 401 &&
        allowRefresh &&
        endpoint != '/auth/refresh' &&
        await _refreshAccessToken()) {
      return _request(method, endpoint, body: body, allowRefresh: false);
    }

    return response;
  }

  static Future<bool> _refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await clearTokens();
      return false;
    }

    try {
      final url = Uri.parse('${await getBaseUrl()}/auth/refresh');
      final response = await http.post(
        url,
        headers: _defaultHeaders,
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode != 200) {
        await clearTokens();
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;
      if (accessToken == null || newRefreshToken == null) {
        await clearTokens();
        return false;
      }

      await saveTokens(accessToken, newRefreshToken);
      return true;
    } catch (_) {
      await clearTokens();
      return false;
    }
  }
}
