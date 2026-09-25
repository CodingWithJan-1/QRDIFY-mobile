class PasswordRecoveryRequest {
  const PasswordRecoveryRequest({
    required this.message,
    required this.expiresIn,
    required this.resendIn,
  });

  final String message;
  final Duration expiresIn;
  final Duration resendIn;
}
