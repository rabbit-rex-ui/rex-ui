import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';

/// Estado de bloqueio do terminal. O bloqueio manual e a expiração detectada
/// pelo AuthInterceptor (refresh falhou) passam por aqui.
class LockController extends ChangeNotifier {
  LockController(this._tokens);
  final TokenStore _tokens;

  bool _locked = false;
  bool get locked => _locked;

  Future<void>? _tokenClearInFlight;

  /// Bloqueia: descarta as credenciais locais (exige senha pra voltar) e cobre
  /// a tela com o overlay. NÃO navega — o PDV e o carrinho em memória ficam.
  void lock() {
    if (_locked) return;
    _locked = true;
    _tokenClearInFlight = _clearTokens();
    notifyListeners();
  }

  Future<void> waitForTokensCleared() => _tokenClearInFlight ?? Future.value();

  Future<void> _clearTokens() async {
    try {
      await _tokens.clear();
    } finally {
      _tokenClearInFlight = null;
    }
  }

  /// Libera após re-autenticação (o login já salvou o token novo).
  void unlock() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }
}
