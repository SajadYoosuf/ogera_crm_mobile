import '../core/utils/formatters.dart';

/// CRM roles, as issued by `/api/auth/login`.
enum UserRole {
  admin('admin', 'Admin'),
  salesHead('sales_head', 'Sales Head'),
  salesStaff('sales_staff', 'Sales Staff');

  const UserRole(this.id, this.label);

  final String id;
  final String label;

  static UserRole fromId(String? value) => switch (value) {
    'admin' => UserRole.admin,
    'sales_head' => UserRole.salesHead,
    _ => UserRole.salesStaff,
  };

  /// Admin and Sales Head share one experience throughout the app; the PRD
  /// calls that combined audience "Head".
  bool get isHead => this == UserRole.admin || this == UserRole.salesHead;
  bool get isStaff => this == UserRole.salesStaff;
}

/// Which login tab produced this session. The tab is a routing hint; the server
/// verifies the role independently and answers `SCOPE_MISMATCH` on a mismatch.
enum LoginScope {
  head('head', 'Head'),
  staff('staff', 'Staff');

  const LoginScope(this.id, this.label);

  final String id;
  final String label;

  bool accepts(UserRole role) =>
      this == LoginScope.head ? role.isHead : role.isStaff;

  String get mismatchMessage => this == LoginScope.head
      ? 'This is a Sales Staff account. Use the Staff tab to sign in.'
      : 'This is an Admin or Sales Head account. Use the Head tab to sign in.';
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
  });

  final int id;
  final String email;
  final String name;
  final String? phone;
  final UserRole role;

  bool get isHead => role.isHead;
  bool get isStaff => role.isStaff;

  /// Head roles bypass the per-record ownership checks.
  bool get isPrivileged => role.isHead;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'phone': phone,
    'role': role.id,
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: asInt(json['id']) ?? 0,
      email: asText(json['email']) ?? '',
      name: asText(json['name']) ?? 'User',
      phone: asText(json['phone']),
      role: UserRole.fromId(asText(json['role'])),
    );
  }
}

class AuthSession {
  const AuthSession({required this.accessToken, required this.user});

  final String accessToken;
  final AuthUser user;

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'user': user.toJson(),
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: asText(json['accessToken']) ?? '',
      user: AuthUser.fromJson(
        json['user'] is Map<String, dynamic>
            ? json['user'] as Map<String, dynamic>
            : const {},
      ),
    );
  }
}
