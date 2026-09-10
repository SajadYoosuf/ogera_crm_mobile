import 'package:flutter/foundation.dart';

import '../models/auth_session.dart';
import '../services/auth_service.dart';

enum LoginStatus { idle, submitting, error }

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._authService);

  final AuthService _authService;

  LoginScope _scope = LoginScope.head;
  String _email = '';
  String _password = '';
  bool _hasAttemptedSubmit = false;
  bool _obscurePassword = true;
  LoginStatus _status = LoginStatus.idle;
  String? _message;
  AuthSession? _session;

  LoginScope get scope => _scope;
  bool get hasAttemptedSubmit => _hasAttemptedSubmit;
  bool get obscurePassword => _obscurePassword;
  bool get isSubmitting => _status == LoginStatus.submitting;
  bool get hasError => _status == LoginStatus.error;
  String? get message => _message;
  AuthSession? get session => _session;

  void selectScope(LoginScope scope) {
    if (_scope == scope) return;
    _scope = scope;
    _message = null;
    _status = LoginStatus.idle;
    notifyListeners();
  }

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

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter the email for your workspace.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address.';
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
        scope: _scope,
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

  void requestPasswordHelp() {
    _status = LoginStatus.idle;
    _message = 'Ask your workspace administrator to reset your password.';
    notifyListeners();
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
