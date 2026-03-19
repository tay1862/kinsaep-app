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

  static Future<Map<String, String>> _getHeaders() async {
    const headers = {'Content-Type': 'application/json'};
    final token = await getToken();

    if (token != null && token.isNotEmpty) {
      return {...headers, 'Authorization': 'Bearer $token'};
    }

    return headers;
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('${await getBaseUrl()}$endpoint');
    final headers = await _getHeaders();
    return http.post(url, headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> get(String endpoint) async {
    final url = Uri.parse('${await getBaseUrl()}$endpoint');
    final headers = await _getHeaders();
    return http.get(url, headers: headers);
  }

  static Future<http.Response> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('${await getBaseUrl()}$endpoint');
    final headers = await _getHeaders();
    return http.patch(url, headers: headers, body: jsonEncode(body));
  }
}
