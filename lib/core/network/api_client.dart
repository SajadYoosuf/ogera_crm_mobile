import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_media_type;

import '../config/app_config.dart';

/// Why a request failed, so a screen can choose the right icon and wording
/// instead of showing one generic "something went wrong" for every case.
enum FailureKind { offline, unauthorized, forbidden, notFound, server }

/// The CRM API answers with plain JSON and reports problems as FastAPI's
/// `{ "detail": ... }` (a string, a list of validation errors, or an object
/// such as `{ message, missing_fields }`). [ApiException] carries the server's
/// own message so screens can show it verbatim.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.details = const {},
  });

  final String message;
  final String? code;
  final int? statusCode;

  /// The structured `detail` object when the server sent one, e.g. the
  /// `missing_fields` behind a blocked stage change.
  final Map<String, dynamic> details;

  List<String> get missingFields => [
    for (final field in (details['missing_fields'] as List?) ?? const [])
      field.toString(),
  ];

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
      _baseUrlOverride = baseUrl {
    _log(
      'server = $baseUrl '
      '(${kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug'} build)',
    );
  }

  final http.Client _client;
  final String? _baseUrlOverride;

  String? _accessToken;
  VoidCallback? onUnauthorized;

  /// The signed-in employee's id. A few endpoints (stage changes) want the
  /// caller named in the body.
  int? currentUserId;

  static const _timeout = Duration(seconds: 20);

  // Read on every request rather than frozen at startup, so a hot reload picks
  // up a changed AppConfig address.
  String get baseUrl => _baseUrlOverride ?? AppConfig.apiBaseUrl;
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

  Future<dynamic> patch(String path, {Object? body}) {
    return _send('PATCH', path, body: body);
  }

  Future<dynamic> delete(String path, {Object? body}) {
    return _send('DELETE', path, body: body);
  }

  /// Uploads a single file as multipart/form-data.
  ///
  /// [path] is the API endpoint (e.g. '/expenses/1/bill-photo').
  /// [fieldName] is the form field the server expects (usually 'file').
  /// [filePath] is the local path to the file on disk.
  /// [mimeType] is the MIME type (e.g. 'image/jpeg').
  ///
  /// Returns the parsed JSON response, same as the other methods.
  Future<dynamic> postFile(
    String path, {
    required String fieldName,
    required String filePath,
    required String mimeType,
    Map<String, String>? fields,
  }) async {
    final uri = _resolve(path, null);
    final request = http.MultipartRequest('POST', uri);
    if (hasToken) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }
    request.headers['x-client-type'] = 'mobile';
    if (fields != null) request.fields.addAll(fields);

    final parts = mimeType.split('/');
    request.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        filePath,
        contentType: http_media_type.MediaType(
          parts.first,
          parts.length > 1 ? parts[1] : '*',
        ),
      ),
    );

    _log('--> POST (multipart) $uri${hasToken ? '  (authorised)' : '  (no token)'}');
    final clock = Stopwatch()..start();

    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      _log('<-- POST $uri  TIMEOUT after ${clock.elapsedMilliseconds} ms');
      throw const ApiException('The server took too long to respond.');
    } catch (error) {
      _log(
        '<-- POST $uri  NETWORK ERROR after ${clock.elapsedMilliseconds} ms'
        ' | ${error.runtimeType}: $error',
      );
      throw const ApiException(
        'Network problem. Check your connection and try again.',
      );
    }

    _log(
      '<-- POST ${uri.path} ${response.statusCode}'
      '  ${clock.elapsedMilliseconds} ms, ${response.bodyBytes.length} bytes',
    );
    return _unwrap(response);
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

    // The bearer token is never logged, only where the request went and how it
    // ended.
    _log('--> $method $uri${hasToken ? '  (authorised)' : '  (no token)'}');
    final clock = Stopwatch()..start();

    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      _log('<-- $method $uri  TIMEOUT after ${clock.elapsedMilliseconds} ms');
      throw const ApiException('The server took too long to respond.');
    } catch (error) {
      // The user sees one friendly message; the log keeps the real reason
      // (unreachable host, refused connection, cleartext blocked, DNS...).
      _log(
        '<-- $method $uri  NETWORK ERROR after ${clock.elapsedMilliseconds} ms'
        ' | ${error.runtimeType}: $error',
      );
      throw const ApiException(
        'Network problem. Check your connection and try again.',
      );
    }

    _log(
      '<-- $method ${uri.path} ${response.statusCode}'
      '  ${clock.elapsedMilliseconds} ms, ${response.bodyBytes.length} bytes',
    );
    if (response.statusCode >= 400) {
      // Error bodies carry the server's code and message, never user data. An
      // HTML page (a route that does not exist, a proxy error) is cut short.
      final text = response.body.trim();
      final looksLikeHtml = text.startsWith('<');
      _log(
        looksLikeHtml
            ? '    not a JSON API reply (an HTML page). Is this the right server?'
            : '    error body: ${text.length > 300 ? '${text.substring(0, 300)}…' : text}',
      );
    }
    return _unwrap(response);
  }

  Uri _resolve(String path, Map<String, dynamic>? query) {
    final base = Uri.tryParse(baseUrl);
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
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        // Falls through to the status-based error below.
      }
    }
    final Map<String, dynamic> body = decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};

    if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException(
        _errorMessage(body) ?? 'Your session ended. Please sign in again.',
        code: 'UNAUTHORIZED',
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
        details: _errorDetails(body),
      );
    }

    // 204 and other empty replies carry nothing for the caller to read.
    if (decoded == null) return null;
    // Tolerate the old `{ success, data }` envelope so a proxy or older
    // deployment in front of the API does not break the app.
    if (body.containsKey('success') && body.containsKey('data')) {
      return body['data'];
    }
    return decoded;
  }

  /// Turns FastAPI's `detail` into one readable sentence.
  String? _errorMessage(Map<String, dynamic> body) {
    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is Map && detail['message'] is String) {
      return detail['message'] as String;
    }
    if (detail is List && detail.isNotEmpty) {
      final lines = <String>[];
      for (final entry in detail) {
        if (entry is! Map) continue;
        final message = (entry['msg'] ?? '').toString().replaceFirst(
          'Value error, ',
          '',
        );
        final location = entry['loc'];
        final field = location is List && location.length > 1
            ? location.skip(1).join('.')
            : '';
        lines.add(field.isEmpty ? message : '$field: $message');
      }
      if (lines.isNotEmpty) return lines.join('\n');
    }
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

  Map<String, dynamic> _errorDetails(Map<String, dynamic> body) {
    final detail = body['detail'];
    return detail is Map<String, dynamic> ? detail : const {};
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
