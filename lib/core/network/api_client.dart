import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Why a request failed, so a screen can choose the right icon and wording
/// instead of showing one generic "something went wrong" for every case.
enum FailureKind { offline, unauthorized, forbidden, notFound, server }

/// Every CRM endpoint answers with `{ success, data }` or
/// `{ success: false, error: { code, message } }`. [ApiException] carries the
/// server's own message so screens can show it verbatim.
class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  /// No status code means the request never reached the server — a dead
  /// connection, an unreachable host, or a timeout.
  bool get isNetwork => statusCode == null;

  FailureKind get kind {
    if (isNetwork) return FailureKind.offline;
    if (isUnauthorized) return FailureKind.unauthorized;
    if (isForbidden) return FailureKind.forbidden;
    if (isNotFound) return FailureKind.notFound;
    return FailureKind.server;
  }

  @override
  String toString() => 'ApiException($statusCode/$code): $message';
}

/// Thin HTTP layer shared by every service.
///
/// It owns the bearer token, unwraps the response envelope, and reports a 401
/// once through [onUnauthorized] so the app can return to the login screen from
/// wherever the user happens to be.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  String? _accessToken;
  VoidCallback? onUnauthorized;

  static const _timeout = Duration(seconds: 20);

  String get baseUrl => _baseUrl;
  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  void setAccessToken(String? token) => _accessToken = token;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    return _send('GET', path, query: query);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) {
    return _send('POST', path, body: body, extraHeaders: headers);
  }

  Future<dynamic> put(String path, {Object? body}) {
    return _send('PUT', path, body: body);
  }

  Future<dynamic> delete(String path, {Object? body}) {
    return _send('DELETE', path, body: body);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = _resolve(path, query);
    final headers = <String, String>{
      'Accept': 'application/json',
      'x-client-type': 'mobile',
      if (body != null) 'Content-Type': 'application/json',
      if (hasToken) 'Authorization': 'Bearer $_accessToken',
      ...?extraHeaders,
    };

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } catch (_) {
      throw const ApiException(
        'Network problem. Check your connection and try again.',
      );
    }

    _log('$method ${uri.path} -> ${response.statusCode}');
    return _unwrap(response);
  }

  Uri _resolve(String path, Map<String, dynamic>? query) {
    final base = Uri.tryParse(_baseUrl);
    if (base == null || !base.hasScheme || base.host.isEmpty) {
      throw const ApiException(
        'The CRM server address is not configured for this build.',
      );
    }
    final uri = base.resolve(path);
    if (query == null || query.isEmpty) return uri;
    final params = <String, String>{};
    query.forEach((key, value) {
      if (value == null) return;
      final text = value.toString();
      if (text.isEmpty) return;
      params[key] = text;
    });
    return uri.replace(queryParameters: {...uri.queryParameters, ...params});
  }

  dynamic _unwrap(http.Response response) {
    Map<String, dynamic> body = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } on FormatException {
        // Falls through to the status-based error below.
      }
    }

    if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException(
        _errorMessage(body) ?? 'Your session ended. Please sign in again.',
        code: _errorCode(body) ?? 'UNAUTHORIZED',
        statusCode: 401,
      );
    }

    final succeeded =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body['success'] != false;
    if (!succeeded) {
      throw ApiException(
        _errorMessage(body) ?? _fallbackMessage(response.statusCode),
        code: _errorCode(body),
        statusCode: response.statusCode,
      );
    }

    // A few endpoints answer with a bare `{ success, message }`; those callers
    // only check for the absence of an exception.
    return body.containsKey('data') ? body['data'] : body;
  }

  String? _errorMessage(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
    if (body['message'] is String) return body['message'] as String;
    return null;
  }

  String? _errorCode(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is Map && error['code'] is String) return error['code'] as String;
    return null;
  }

  String _fallbackMessage(int status) {
    if (status == 403) return 'You do not have access to this.';
    if (status == 404) return 'We could not find what you asked for.';
    if (status >= 500) return 'The server had a problem. Please try again.';
    return 'Something went wrong. Please try again.';
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[Ogera API] $message');
  }
}

/// Convenience casts used by the services; the API returns loose JSON.
Map<String, dynamic> asMap(dynamic value) =>
    value is Map<String, dynamic> ? value : const {};

List<Map<String, dynamic>> asList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().toList(growable: false);
}
