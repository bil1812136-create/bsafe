import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Thin HTTP wrapper used by remote data-sources.
/// All feature-level data-sources depend on this rather than [http] directly.
class HttpClient {
  final String baseUrl;
  final Duration timeout;
  final Map<String, String> _defaultHeaders;

  HttpClient({
    this.baseUrl = '',
    this.timeout = const Duration(seconds: 30),
    Map<String, String>? defaultHeaders,
  }) : _defaultHeaders = defaultHeaders ??
            const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            };

  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? headers}) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {..._defaultHeaders, ...?headers},
    ).timeout(timeout);
    return _handle(response);
  }

  Future<Map<String, dynamic>> post(String path, Object body,
      {Map<String, String>? headers}) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {..._defaultHeaders, ...?headers},
          body: jsonEncode(body),
        )
        .timeout(timeout);
    return _handle(response);
  }

  Future<Map<String, dynamic>> patch(String path, Object body,
      {Map<String, String>? headers}) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: {..._defaultHeaders, ...?headers},
          body: jsonEncode(body),
        )
        .timeout(timeout);
    return _handle(response);
  }

  Map<String, dynamic> _handle(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    }
    debugPrint('HTTP ${response.statusCode}: ${response.body}');
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }
}
