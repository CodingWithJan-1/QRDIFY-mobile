import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
    this.maxResponseBytes = 8 * 1024 * 1024,
  }) : _baseUri = Uri.parse(baseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _httpClient;
  final Duration timeout;
  final int maxResponseBytes;
  void Function(String token, ApiException error)? onSessionInvalidated;

  Future<Object?> get(String path, {String? token}) {
    return _send(
      () => _request('GET', path, headers: _headers(token: token)),
      token: token,
    );
  }

  Future<Object?> post(
    String path, {
    Map<String, Object?>? body,
    String? token,
    Map<String, String>? headers,
  }) {
    return _send(
      () => _request(
        'POST',
        path,
        headers: _headers(
          token: token,
          hasJsonBody: true,
          additionalHeaders: headers,
        ),
        body: jsonEncode(body ?? const <String, Object?>{}),
      ),
      token: token,
    );
  }

  Future<Object?> postMultipart(
    String path, {
    required Map<String, String> fields,
    String? token,
    String? fileField,
    List<int>? fileBytes,
    String? fileName,
  }) {
    return _send(() async {
      final request = http.MultipartRequest('POST', _uri(path));
      request.followRedirects = false;
      request.headers.addAll(_headers(token: token));
      request.fields.addAll(fields);
      if (fileField != null && fileBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            fileField,
            fileBytes,
            filename: fileName,
          ),
        );
      }
      final streamedResponse = await _httpClient.send(request);
      return _readResponse(streamedResponse);
    }, token: token);
  }

  Future<Object?> put(
    String path, {
    Map<String, Object?>? body,
    String? token,
  }) {
    return _send(
      () => _request(
        'PUT',
        path,
        headers: _headers(token: token, hasJsonBody: true),
        body: jsonEncode(body ?? const <String, Object?>{}),
      ),
      token: token,
    );
  }

  Future<Object?> delete(String path, {String? token}) {
    return _send(
      () => _request('DELETE', path, headers: _headers(token: token)),
      token: token,
    );
  }

  Future<http.Response> _request(
    String method,
    String path, {
    required Map<String, String> headers,
    String? body,
  }) async {
    final request = http.Request(method, _uri(path))..followRedirects = false;
    request.headers.addAll(headers);
    if (body != null) request.body = body;
    return _readResponse(await _httpClient.send(request));
  }

  Future<http.Response> _readResponse(http.StreamedResponse response) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > maxResponseBytes) {
        throw const ApiException(
          message: 'The server response is too large. Please contact school support.',
          code: 'response_too_large',
        );
      }
      bytes.add(chunk);
    }
    return http.Response.bytes(
      bytes.takeBytes(),
      response.statusCode,
      headers: response.headers,
      request: response.request,
      reasonPhrase: response.reasonPhrase,
    );
  }

  Uri _uri(String path) {
    final relativePath = path.replaceFirst(RegExp(r'^/+'), '');
    final uri = _baseUri.resolve(relativePath);
    if (!['http', 'https'].contains(uri.scheme) ||
        uri.origin != _baseUri.origin ||
        uri.userInfo.isNotEmpty) {
      throw const ApiException(
        message: 'Requests must use the configured school API.',
        code: 'invalid_api_origin',
      );
    }
    return uri;
  }

  String? publicAssetUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final uri = Uri.tryParse(path);
    if (uri == null) return null;
    if (uri.hasScheme) {
      return ['http', 'https'].contains(uri.scheme) &&
              uri.origin == _baseUri.origin &&
              uri.userInfo.isEmpty
          ? '$uri'
          : null;
    }
    final resolved = _baseUri.resolve(path.startsWith('/') ? path : '/$path');
    return resolved.origin == _baseUri.origin && resolved.userInfo.isEmpty
        ? '$resolved'
        : null;
  }

  Map<String, String> _headers({
    String? token,
    bool hasJsonBody = false,
    Map<String, String>? additionalHeaders,
  }) {
    return {
      'Accept': 'application/json',
      if (hasJsonBody) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?additionalHeaders,
    };
  }

  Future<Object?> _send(
    Future<http.Response> Function() request, {
    String? token,
  }) async {
    late final http.Response response;

    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        message: 'The server took too long to respond. Please try again.',
        code: 'request_timeout',
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'Unable to reach QRDify. Check your connection and try again.',
        code: 'connection_failed',
      );
    }

    final decoded = _decodeBody(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final error = _exceptionFrom(response.statusCode, decoded);
    if (token != null &&
        (error.isUnauthorized ||
            error.code == 'account_blocked' ||
            error.code == 'password_change_required')) {
      onSessionInvalidated?.call(token, error);
    }
    throw error;
  }

  Object? _decodeBody(String body) {
    if (body.trim().isEmpty) return null;

    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  ApiException _exceptionFrom(int statusCode, Object? body) {
    final json = body is Map<String, dynamic> ? body : null;
    final errors = <String, List<String>>{};
    final rawErrors = json?['errors'];

    if (rawErrors is Map<String, dynamic>) {
      for (final entry in rawErrors.entries) {
        final value = entry.value;
        errors[entry.key] = switch (value) {
          List<Object?> values => values.map((item) => '$item').toList(),
          _ => ['$value'],
        };
      }
    }

    final firstValidationMessage = errors.values
        .where((messages) => messages.isNotEmpty)
        .map((messages) => messages.first)
        .firstOrNull;

    return ApiException(
      statusCode: statusCode,
      code: json?['code'] as String?,
      message:
          firstValidationMessage ??
          json?['message'] as String? ??
          _defaultMessage(statusCode),
      validationErrors: errors,
    );
  }

  String _defaultMessage(int statusCode) => switch (statusCode) {
    401 => 'Your session has expired. Please sign in again.',
    403 => 'You do not have permission to perform this action.',
    404 => 'The requested information was not found.',
    429 => 'Too many requests. Please wait and try again.',
    503 => 'QRDify is currently under maintenance.',
    _ => 'Something went wrong. Please try again.',
  };

  void close() => _httpClient.close();
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
