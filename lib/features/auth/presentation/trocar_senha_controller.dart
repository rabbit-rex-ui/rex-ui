import 'package:flutter/foundation.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/auth/data/dto/login_dtos.dart';
import 'package:rabbit_pdv/features/auth/domain/auth_repository.dart';

/// Decisão de navegação que a página toma após o submit.
enum TrocaSenhaOutcome { sucesso, falha, sessaoExpirada }

class TrocarSenhaController extends ChangeNotifier {
  TrocarSenhaController(this._repo);
  final AuthRepository _repo;

  bool _loading = false;
  bool get loading => _loading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _obscureAtual = true;
  bool get obscureAtual => _obscureAtual;
  bool _obscureNova = true;
  bool get obscureNova => _obscureNova;

  void toggleObscureAtual() {
    _obscureAtual = !_obscureAtual;
    notifyListeners();
  }

  void toggleObscureNova() {
    _obscureNova = !_obscureNova;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Validação leve no cliente; a POLÍTICA real de senha é do backend
  /// (devolve 400/422 com `detail`, que exibimos). Não recalculamos regra.
  Future<TrocaSenhaOutcome> submit({
    required String senhaAtual,
    required String novaSenha,
    required String confirmacao,
  }) async {
    if (senhaAtual.isEmpty || novaSenha.isEmpty) {
      return _falhaLocal('Preencha a senha atual e a nova senha.');
    }
    if (novaSenha != confirmacao) {
      return _falhaLocal('A confirmação não corresponde à nova senha.');
    }
    if (novaSenha == senhaAtual) {
      return _falhaLocal('A nova senha deve ser diferente da atual.');
    }

    _loading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repo.trocarSenha(
      TrocarSenhaRequest(senhaAtual: senhaAtual, novaSenha: novaSenha),
    );
    _loading = false;

    return switch (result) {
      Ok() => _sucesso(),
      Err(:final failure) => _tratarFalha(failure),
    };
  }

  TrocaSenhaOutcome _sucesso() {
    notifyListeners();
    return TrocaSenhaOutcome.sucesso;
  }

  TrocaSenhaOutcome _falhaLocal(String msg) {
    _errorMessage = msg;
    notifyListeners();
    return TrocaSenhaOutcome.falha;
  }

  TrocaSenhaOutcome _tratarFalha(Failure f) {
    // Token morreu no meio do fluxo → manda de volta pro login.
    if (f is NetworkFailure && f.statusCode == 401) {
      _errorMessage = 'Sessão expirada. Faça login novamente.';
      notifyListeners();
      return TrocaSenhaOutcome.sessaoExpirada;
    }
    _errorMessage = f.message; // inclui o detalhe de política do backend
    notifyListeners();
    return TrocaSenhaOutcome.falha;
  }
}
