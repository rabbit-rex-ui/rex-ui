import 'package:flutter/foundation.dart';

import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/features/provisionamento/data/caixa_fisico_repository.dart';
import 'package:rabbit_pdv/features/provisionamento/data/device_enrollment_repository.dart';
import 'package:rabbit_pdv/features/provisionamento/data/dto/device_enrollment_dtos.dart';
import 'package:rabbit_pdv/features/provisionamento/data/dto/pdv_fisico.dart';
import 'package:rabbit_pdv/features/provisionamento/data/trusted_device_repository.dart';

/// Etapas da tela de provisionamento (Parte 1 do guia).
enum ProvisionarEtapa { login, formulario, emitido }

class ProvisionarTerminalController extends ChangeNotifier {
  ProvisionarTerminalController(this._trusted, this._caixas, this._enrollment);

  final TrustedDeviceRepository _trusted;
  final CaixaFisicoRepository _caixas;
  final DeviceEnrollmentRepository _enrollment;

  ProvisionarEtapa _etapa = ProvisionarEtapa.login;
  ProvisionarEtapa get etapa => _etapa;

  bool _loading = false;
  bool get loading => _loading;

  String? _erro;
  String? get erro => _erro;

  // Caixa resolvido pelo code.
  PdvFisico? _caixa;
  PdvFisico? get caixa => _caixa;

  // Token emitido (memória apenas — nunca persistido).
  DeviceEnrollmentResponse? _token;
  DeviceEnrollmentResponse? get token => _token;

  /// Chamado após o login do gestor (a LoginPage/embed já autenticou e o token
  /// está no TokenStore). Garante a estação confiável e avança para o form.
  Future<void> aposLogin({required String deviceLabelEstacao}) async {
    _set(loading: true, erro: null);
    if (!await _trusted.jaConfiavel()) {
      final r = await _trusted.registrarEstacao(deviceLabelEstacao);
      final falhou = r.fold(onOk: (_) => null, onErr: (f) => f);
      if (falhou != null) {
        _set(
          loading: false,
          erro: 'Falha ao registrar a estação: ${falhou.message}',
        );
        return;
      }
    }
    _etapa = ProvisionarEtapa.formulario;
    _set(loading: false, erro: null);
  }

  /// Resolve o caixa pelo code (GET ?code=). Preenche [caixa] ou erro.
  Future<void> resolverCaixa(String code) async {
    final c = code.trim();
    if (c.isEmpty) {
      _set(erro: 'Informe o código do caixa (ex.: PDV-01).');
      return;
    }
    _set(loading: true, erro: null, limparCaixa: true);
    final r = await _caixas.buscarPorCode(c);
    r.fold(
      onOk: (pdv) {
        _caixa = pdv;
        _set(
          loading: false,
          erro: pdv.active ? null : 'Atenção: caixa inativo.',
        );
      },
      onErr: (f) => _set(loading: false, erro: f.message),
    );
  }

  /// Emite o token para o caixa já resolvido.
  Future<void> emitir({required String deviceLabel}) async {
    final caixa = _caixa;
    if (caixa == null) {
      _set(erro: 'Resolva o caixa pelo código antes de emitir.');
      return;
    }
    if (deviceLabel.trim().isEmpty) {
      _set(erro: 'Informe um rótulo para o terminal.');
      return;
    }
    _set(loading: true, erro: null);
    final r = await _enrollment.emitir(
      DeviceEnrollmentRequest(
        deviceLabel: deviceLabel.trim(),
        cashRegisterId: caixa.id,
      ),
    );
    r.fold(
      onOk: (tok) {
        _token = tok;
        _etapa = ProvisionarEtapa.emitido;
        _set(loading: false, erro: null);
      },
      onErr: (f) => _set(loading: false, erro: _mensagemEmissao(f)),
    );
  }

  /// Recomeça para emitir outro (limpa o token da memória).
  void novaEmissao() {
    _token = null;
    _caixa = null;
    _etapa = ProvisionarEtapa.formulario;
    _set(erro: null);
  }

  String _mensagemEmissao(Failure f) {
    // 403 aqui = sem iam.device.manage OU estação não confiável (guia §8).
    if (f is BusinessRuleFailure && f.code == 'SEM_PERMISSAO') {
      return 'Sem permissão para provisionar, ou esta estação não é confiável.';
    }
    if (f is NetworkFailure && f.statusCode == 403) {
      return 'Sem permissão para provisionar, ou esta estação não é confiável.';
    }
    return f.message;
  }

  void _set({bool? loading, String? erro, bool limparCaixa = false}) {
    if (loading != null) _loading = loading;
    _erro = erro;
    if (limparCaixa) _caixa = null;
    notifyListeners();
  }

  void clearErrorSuave() {
    if (_erro == null) return;
    _erro = null;
    notifyListeners();
  }
}
