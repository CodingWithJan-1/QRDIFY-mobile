import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.useMobileApi});

  factory AppConfig.fromEnvironment() {
    const configuredUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );
    const useMobileApi = bool.fromEnvironment('USE_MOBILE_API');
    final defaultUrl = kReleaseMode
        ? 'https://qridify.online/api'
        : 'http://10.0.2.2:8000/api';

    return AppConfig(
      apiBaseUrl: _normalizeBaseUrl(
        configuredUrl.trim().isEmpty ? defaultUrl : configuredUrl,
      ),
      useMobileApi: useMobileApi,
    );
  }

  final String apiBaseUrl;
  final bool useMobileApi;

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('API_BASE_URL cannot be empty.');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw FormatException('API_BASE_URL is invalid: $trimmed');
    }
    if (kReleaseMode && uri.scheme.toLowerCase() != 'https') {
      throw const FormatException(
        'Release builds require an HTTPS API_BASE_URL.',
      );
    }

    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }
}
