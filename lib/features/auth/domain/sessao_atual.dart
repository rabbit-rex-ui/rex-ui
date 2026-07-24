import 'package:flutter/foundation.dart';
import 'package:rabbit_pdv/features/auth/data/auth_me_repository.dart';
import 'package:rabbit_pdv/features/auth/data/dto/auth_me_dto.dart';

/// Contexto do usuário logado (GET /auth/me). Carregado após login e após
/// trocar-tenant; lido pela topbar e pela regra de desbloqueio (cx.takeover).
class SessaoAtual extends ChangeNotifier {
  SessaoAtual(this._repo);
  final AuthMeRepository _repo;

  AuthMe? _me;
  AuthMe? get me => _me;

  bool temPermissao(String code) => _me?.temPermissao(code) ?? false;

  /// Falha silenciosa: a ausência do contexto degrada a UI, não quebra o fluxo.
  Future<void> carregar() async {
    final r = await _repo.me();
    r.fold(
      onOk: (m) {
        _me = m;
        notifyListeners();
      },
      onErr: (_) {
        /* mantém o que tinha; topbar cai no fallback */
      },
    );
  }

  void limpar() {
    _me = null;
    notifyListeners();
  }
}
