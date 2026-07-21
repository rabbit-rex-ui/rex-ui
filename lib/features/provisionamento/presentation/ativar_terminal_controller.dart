import 'package:flutter/foundation.dart';

import 'package:rabbit_pdv/core/security/terminal_context_store.dart';
import 'package:rabbit_pdv/core/security/terminal_key_store.dart';
import 'package:rabbit_pdv/features/provisionamento/data/device_activation_repository.dart';
import 'package:rabbit_pdv/features/provisionamento/data/dto/device_activation_dtos.dart';

class AtivarTerminalController extends ChangeNotifier {
  AtivarTerminalController(this._repo, this._keys, this._context);

  final DeviceActivationRepository _repo;
  final TerminalKeyStore _keys;
  final TerminalContextStore _context;

  bool _loading = false;
  bool get loading => _loading;

  String? _erro;
  String? get erro => _erro;

  bool _sucesso = false;
  bool get sucesso => _sucesso;

  TerminalContext? get contexto => _context.atual;

  void clearError() {
    if (_erro == null) return;
    _erro = null;
    notifyListeners();
  }

  /// Fluxo: gera o par (se ainda não existe) → exporta a pública em PEM →
  /// consome o token → persiste a identidade do terminal.
  Future<bool> ativar(String token) async {
    final t = token.trim();
    if (t.isEmpty) {
      _erro = 'Cole o token de ativação gerado no back-office.';
      notifyListeners();
      return false;
    }

    _loading = true;
    _erro = null;
    notifyListeners();

    try {
      final pem = await _keys.ensureKeyPairAndExportPublicPem();
      final r = await _repo.ativar(
        DeviceActivationRequest(enrollmentToken: t, publicKeyPem: pem),
      );

      return await r.fold(
        onOk: (resp) async {
          await _context.salvar(
            TerminalContext(
              deviceId: resp.deviceId,
              tenantId: resp.tenantId,
              cashRegisterId: resp.cashRegisterId,
            ),
          );
          _sucesso = true;
          _loading = false;
          notifyListeners();
          return true;
        },
        onErr: (f) async {
          _erro = f.message;
          _loading = false;
          notifyListeners();
          return false;
        },
      );
    } catch (e) {
      _erro = 'Falha ao gerar a identidade do terminal: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }
}
