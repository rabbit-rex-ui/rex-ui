import 'package:flutter/foundation.dart';

import 'package:rabbit_pdv/core/security/terminal_context_store.dart';
import 'package:rabbit_pdv/core/security/terminal_key_store.dart';
import 'package:rabbit_pdv/features/provisionamento/data/device_enrollment_repository.dart';

/// Revogação do terminal ativado NESTA máquina. Ação destrutiva: o caixa fica
/// livre para receber outro terminal e esta máquina precisa ser reativada.
///
/// Após revogar no servidor, descarta a identidade local (contexto + par de
/// chaves) — se a chave antiga permanecesse, uma reativação bateria em
/// `device_fingerprint_conflict`.
class RevogarTerminalController extends ChangeNotifier {
  RevogarTerminalController(this._repo, this._contexto, this._keys);

  final DeviceEnrollmentRepository _repo;
  final TerminalContextStore _contexto;
  final TerminalKeyStore _keys;

  TerminalContext? _terminal;
  TerminalContext? get terminal => _terminal;

  bool _loading = false;
  bool get loading => _loading;

  String? _erro;
  String? get erro => _erro;

  bool _revogado = false;
  bool get revogado => _revogado;

  /// Carrega a identidade local. Sem contexto salvo, não há o que revogar.
  Future<void> carregar() async {
    _terminal = await _contexto.carregar();
    notifyListeners();
  }

  void clearError() {
    if (_erro == null) return;
    _erro = null;
    notifyListeners();
  }

  Future<void> revogar({String? motivo}) async {
    final ctx = _terminal;
    if (ctx == null) {
      _erro = 'Nenhum terminal ativado nesta máquina.';
      notifyListeners();
      return;
    }

    _loading = true;
    _erro = null;
    notifyListeners();

    final r = await _repo.revogar(ctx.deviceId, motivo: motivo);

    await r.fold(
      onOk: (_) async {
        // Identidade local não vale mais: descarta contexto e chave.
        await _contexto.limpar();
        try {
          await _keys.destroy();
        } catch (e) {
          if (kDebugMode) debugPrint('[revogar] destroy() falhou: $e');
        }
        _terminal = null;
        _revogado = true;
        _loading = false;
        notifyListeners();
      },
      onErr: (f) async {
        _erro = f.message;
        _loading = false;
        notifyListeners();
      },
    );
  }
}
