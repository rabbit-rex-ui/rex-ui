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

  /// Bloqueia: descarta as credenciais locais (exige senha pra voltar) e cobre
  /// a tela com o overlay. NÃO navega — o PDV e o carrinho em memória ficam.
  void lock() {
    if (_locked) return;
    unawaited(_tokens.clear());
    _locked = true;
    notifyListeners();
  }

  /// Libera após re-autenticação (o login já salvou o token novo).
  void unlock() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }
}
