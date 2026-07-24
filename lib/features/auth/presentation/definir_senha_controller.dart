import 'package:flutter/foundation.dart';

import 'package:rabbit_pdv/features/auth/data/recuperacao_senha_repository.dart';

/// Definição/redefinição de senha por token. Cobre o primeiro acesso (gestor
/// criado no provisionamento do tenant) e o reset comum.
class DefinirSenhaController extends ChangeNotifier {
  DefinirSenhaController(this._repo);
  final RecuperacaoSenhaRepository _repo;

  bool _loading = false;
  bool get loading => _loading;

  String? _erro;
  String? get erro => _erro;

  bool _concluido = false;
  bool get concluido => _concluido;

  /// Mensagem neutra após solicitar o token (não confirma existência da conta).
  String? _avisoSolicitacao;
  String? get avisoSolicitacao => _avisoSolicitacao;

  bool _obscura = true;
  bool get obscura => _obscura;

  void toggleObscura() {
    _obscura = !_obscura;
    notifyListeners();
  }

  void clearError() {
    if (_erro == null && _avisoSolicitacao == null) return;
    _erro = null;
    _avisoSolicitacao = null;
    notifyListeners();
  }

  /// Mínimo local. A política real é do servidor — se ele recusar, a mensagem
  /// dele prevalece.
  String? _validar(String token, String senha, String confirmacao) {
    if (token.trim().isEmpty) return 'Informe o token recebido.';
    if (senha.length < 8) return 'A senha deve ter ao menos 8 caracteres.';
    if (senha != confirmacao) return 'As senhas não conferem.';
    return null;
  }

  Future<void> definir({
    required String token,
    required String senha,
    required String confirmacao,
  }) async {
    final invalido = _validar(token, senha, confirmacao);
    if (invalido != null) {
      _erro = invalido;
      notifyListeners();
      return;
    }

    _loading = true;
    _erro = null;
    _avisoSolicitacao = null;
    notifyListeners();

    final r = await _repo.redefinir(token: token, novaSenha: senha);
    r.fold(
      onOk: (_) {
        _concluido = true;
        _loading = false;
        notifyListeners();
      },
      onErr: (f) {
        _erro = f.message;
        _loading = false;
        notifyListeners();
      },
    );
  }

  /// Solicita um novo token. Resposta é sempre neutra por design do backend.
  Future<void> solicitarToken(String loginCode) async {
    if (loginCode.trim().isEmpty) {
      _erro = 'Informe o código de login.';
      notifyListeners();
      return;
    }

    _loading = true;
    _erro = null;
    _avisoSolicitacao = null;
    notifyListeners();

    final r = await _repo.solicitar(loginCode);
    r.fold(
      onOk: (_) {
        _avisoSolicitacao =
            'Se o código existir, um link de definição de senha foi enviado.';
        _loading = false;
        notifyListeners();
      },
      onErr: (f) {
        _erro = f.message;
        _loading = false;
        notifyListeners();
      },
    );
  }
}
