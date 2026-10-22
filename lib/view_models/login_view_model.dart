import 'package:flutter/foundation.dart';

import '../models/auth_session.dart';
import '../services/auth_service.dart';

enum LoginStatus { idle, submitting, error }

/// Holds login form state for the staff-only login screen.
/// Admin/manager accounts are blocked at sign-in — they must use the web portal.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._authService);

  final AuthService _authService;

  String _email = '';
  String _password = '';
  bool _hasAttemptedSubmit = false;
  bool _obscurePassword = true;
  LoginStatus _status = LoginStatus.idle;
  String? _message;
  AuthSession? _session;

  bool get hasAttemptedSubmit => _hasAttemptedSubmit;
  bool get obscurePassword => _obscurePassword;
  bool get isSubmitting => _status == LoginStatus.submitting;
  bool get hasError => _status == LoginStatus.error;
  String? get message => _message;
  AuthSession? get session => _session;

  void updateEmail(String value) {
    _email = value.trim();
    _clearMessage();
  }

  void updatePassword(String value) {
    _password = value;
    _clearMessage();
  }

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  /// Accepts a mobile number (digits, spaces, +, -) or an email address,
  /// since the login field now says "Mobile number or email".
  String? validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your mobile number or email.';
    final isPhone = RegExp(r'^[\d\s+\-]{7,}$').hasMatch(v);
    final isEmail = v.contains('@') && v.contains('.');
    if (!isPhone && !isEmail) {
      return 'Enter a valid mobile number or email address.';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password.';
    return null;
  }

  /// Returns the session on success so the caller can hand it to
  /// [SessionViewModel]; the view model itself never routes.
  Future<AuthSession?> signIn() async {
    _hasAttemptedSubmit = true;
    _message = null;
    if (validateEmail(_email) != null || validatePassword(_password) != null) {
      notifyListeners();
      return null;
    }
    _status = LoginStatus.submitting;
    notifyListeners();

    try {
      _session = await _authService.signIn(
        email: _email,
        password: _password,
      );
      _status = LoginStatus.idle;
      notifyListeners();
      return _session;
    } on AuthException catch (error) {
      _status = LoginStatus.error;
      _message = error.message;
    } catch (_) {
      _status = LoginStatus.error;
      _message = 'We could not sign you in. Please try again.';
    }
    notifyListeners();
    return null;
  }

  void showNotice(String notice) {
    _status = LoginStatus.error;
    _message = notice;
    notifyListeners();
  }

  void _clearMessage() {
    if (_message == null && _status == LoginStatus.idle) return;
    _message = null;
    _status = LoginStatus.idle;
    notifyListeners();
  }
}
