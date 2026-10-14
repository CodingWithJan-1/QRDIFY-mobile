abstract interface class SessionStore {
  Future<String?> readAccessToken();

  Future<void> writeAccessToken(String token, {DateTime? expiresAt});

  Future<DateTime?> readExpiresAt();

  Future<void> clearAccessToken();

  Future<String> getOrCreateInstallationId();
}
