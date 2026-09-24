import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
  }) : _baseUri = Uri.parse(baseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _httpClient;
  final Duration timeout;

  Future<Object?> get(String path, {String? token}) {
    return _send(
      () => _httpClient.get(_uri(path), headers: _headers(token: token)),
    );
  }

  Future<Object?> post(
    String path, {
    Map<String, Object?>? body,
    String? token,
    Map<String, String>? headers,
  }) {
    return _send(
      () => _httpClient.post(
        _uri(path),
        headers: _headers(
          token: token,
          hasJsonBody: true,
          additionalHeaders: headers,
        ),
        body: jsonEncode(body ?? const <String, Object?>{}),
      ),
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
      return http.Response.fromStream(streamedResponse);
    });
  }

  Future<Object?> put(
    String path, {
    Map<String, Object?>? body,
    String? token,
  }) {
    return _send(
      () => _httpClient.put(
        _uri(path),
        headers: _headers(token: token, hasJsonBody: true),
        body: jsonEncode(body ?? const <String, Object?>{}),
      ),
    );
  }

  Future<Object?> delete(String path, {String? token}) {
    return _send(
      () => _httpClient.delete(_uri(path), headers: _headers(token: token)),
    );
  }

  Uri _uri(String path) {
    final relativePath = path.replaceFirst(RegExp(r'^/+'), '');
    return _baseUri.resolve(relativePath);
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

  Future<Object?> _send(Future<http.Response> Function() request) async {
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

    throw _exceptionFrom(response.statusCode, decoded);
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
