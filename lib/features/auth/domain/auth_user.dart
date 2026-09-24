import 'portal_role.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    required this.needsPasswordChange,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    final roles = rawRoles is List
        ? rawRoles.map((role) => '$role').toList(growable: false)
        : const <String>[];

    return AuthUser(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      roles: roles,
      needsPasswordChange: json['needs_password_change'] as bool? ?? false,
    );
  }

  final int id;
  final String name;
  final String email;
  final List<String> roles;
  final bool needsPasswordChange;

  PortalRole? get portalRole {
    if (roles.contains('student')) return PortalRole.student;
    if (roles.contains('parent')) return PortalRole.parent;
    return null;
  }
}
