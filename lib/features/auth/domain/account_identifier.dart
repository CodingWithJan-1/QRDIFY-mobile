String? validateAccountIdentifier(String? value) {
  final identifier = value?.trim() ?? '';
  if (identifier.isEmpty) {
    return 'Enter your email address or mobile number.';
  }

  if (identifier.contains('@')) {
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailPattern.hasMatch(identifier)
        ? null
        : 'Enter a valid email address.';
  }

  final compactPhone = identifier.replaceAll(RegExp(r'[\s()\-]'), '');
  final isPhilippineMobile = RegExp(r'^(?:09\d{9}|639\d{9}|\+639\d{9})$')
      .hasMatch(compactPhone);
  return isPhilippineMobile ? null : 'Enter a valid Philippine mobile number.';
}
