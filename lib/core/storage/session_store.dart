abstract interface class SessionStore {
  Future<String?> readAccessToken();

  Future<void> writeAccessToken(String token);

  Future<void> clearAccessToken();

  Future<String> getOrCreateInstallationId();
}
