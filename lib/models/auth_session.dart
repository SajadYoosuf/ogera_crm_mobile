import '../core/utils/formatters.dart';

/// The app's three audiences, folded from the API's employee roles
/// (`admin`, `manager`, `team_lead`, `sales_executive`, `tele_caller`,
/// `field_executive`, `support`, and any custom role).
///
/// `admin` and `manager` are the "Head" audience, the same pair the API lets
/// see the live staff map and the whole team's numbers. Every other role,
/// including custom ones, is Staff.
enum UserRole {
  admin('admin', 'Admin'),
  salesHead('manager', 'Manager'),
  salesStaff('sales_staff', 'Sales Staff'),
  support('support', 'Support');

  const UserRole(this.id, this.label);

  final String id;
  final String label;

  static UserRole fromId(String? value) => switch (value) {
    'admin' => UserRole.admin,
    'manager' || 'sales_head' => UserRole.salesHead,
    'support' => UserRole.support,
    _ => UserRole.salesStaff,
  };

  /// Admin and Sales Head share one experience throughout the app; the PRD
  /// calls that combined audience "Head".
  bool get isHead => this == UserRole.admin || this == UserRole.salesHead;
  bool get isStaff => this == UserRole.salesStaff || this == UserRole.support;

  /// Support handles after-sales and cannot move leads through the pipeline (rule in role_access.py).
  bool get canMoveStage => this != UserRole.support;
}

/// Which login tab produced this session. The tab is a routing hint checked on
/// the phone only: the API has no scope guard, it simply signs the employee in.
enum LoginScope {
  head('head', 'Head'),
  staff('staff', 'Staff');

  const LoginScope(this.id, this.label);

  final String id;
  final String label;

  bool accepts(UserRole role) =>
      this == LoginScope.head ? role.isHead : role.isStaff;

  String get mismatchMessage => this == LoginScope.head
      ? 'This is a Staff account. Use the Staff tab to sign in.'
      : 'This is an Admin or Manager account. Use the Head tab to sign in.';
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

  /// The `POST /auth/login` reply: `{ access_token, token_type, employee }`.
  /// Returns null when the reply is missing either half.
  static AuthSession? fromLogin(dynamic body) {
    if (body is! Map<String, dynamic>) return null;
    final token = body['access_token'];
    final employee = body['employee'];
    if (token is! String ||
        token.isEmpty ||
        employee is! Map<String, dynamic>) {
      return null;
    }
    return AuthSession(accessToken: token, user: AuthUser.fromJson(employee));
  }

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
