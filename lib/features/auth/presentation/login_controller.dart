import 'package:flutter/foundation.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/auth/data/dto/login_dtos.dart';
import 'package:rabbit_pdv/features/auth/domain/auth_repository.dart';
import 'package:rabbit_pdv/features/auth/domain/auth_session.dart';

class LoginController extends ChangeNotifier {
  LoginController(this._repo);

  final AuthRepository _repo;

  bool _loading = false;
  bool get loading => _loading;

  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  AuthSession? _session;
  AuthSession? get session => _session;
  bool get passwordMustChange => _session?.passwordMustChange ?? false;

  void toggleObscure() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Retorna true em sucesso. A PÁGINA decide a navegação.
  Future<bool> submit({
    required String loginCode,
    required String password,
  }) async {
    final code = loginCode.trim();
    if (code.isEmpty || password.isEmpty) {
      _errorMessage = 'Informe o código de login e a senha.';
      notifyListeners();
      return false;
    }

    _loading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repo.login(
      LoginRequest(loginCode: code, password: password),
    );

    switch (result) {
      case Ok(:final value):
        _session = value;
        _loading = false;
        notifyListeners();
        return true;
      case Err(:final failure):
        _errorMessage = failure.message;
        _loading = false;
        notifyListeners();
        return false;
    }
  }

  void reset() {
    _session = null;
    _errorMessage = null;
    _loading = false;
    notifyListeners();
  }
}
