import 'package:flutter/foundation.dart';

import 'package:rabbit_pdv/features/fiscal/impressao/configuracao_impressao.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/impressao_fiscal.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/impressora_raw.dart';

/// Estado do diálogo "Impressoras": escolher a térmica deste terminal, as
/// colunas e o módulo do QR, imprimir um teste e salvar. Descartável.
class ConfiguracaoImpressaoController extends ChangeNotifier {
  ConfiguracaoImpressaoController({
    required ConfiguracaoImpressaoStore store,
    required ImpressoraRaw impressoras,
    required ImpressaoFiscal impressao,
  }) : _store = store,
       _impressoras = impressoras,
       _impressao = impressao;

  final ConfiguracaoImpressaoStore _store;
  final ImpressoraRaw _impressoras;
  final ImpressaoFiscal _impressao;

  bool _carregando = true;
  bool get carregando => _carregando;

  List<String> _instaladas = const [];

  ConfiguracaoImpressao _configuracao = const ConfiguracaoImpressao();
  ConfiguracaoImpressao get configuracao => _configuracao;

  bool _testando = false;
  bool get testando => _testando;

  bool _salvando = false;
  bool get salvando => _salvando;

  bool get ocupado => _testando || _salvando;

  ({String texto, bool erro})? _mensagem;
  ({String texto, bool erro})? get mensagem => _mensagem;

  bool _descartado = false;

  /// Impressoras para o seletor. A já salva entra mesmo se sumiu do Windows
  /// (o seletor exige que o valor atual esteja na lista).
  List<String> get opcoes {
    final salva = _configuracao.impressoraTermica;
    return [
      ..._instaladas,
      if (salva != null && salva.isNotEmpty && !_instaladas.contains(salva))
        salva,
    ];
  }

  bool estaInstalada(String impressora) => _instaladas.contains(impressora);

  Future<void> carregar() async {
    _carregando = true;
    _mensagem = null;
    notifyListeners();

    _configuracao = await _store.ler();
    final lista = await _impressoras.listar();
    if (_descartado) return;
    lista.fold<void>(
      onOk: (nomes) => _instaladas = nomes,
      onErr: (f) => _mensagem = (texto: f.message, erro: true),
    );
    _carregando = false;
    notifyListeners();
  }

  void escolherImpressora(String? nome) =>
      _alterar(_configuracao.copyWith(impressoraTermica: nome));

  void escolherColunas(int colunas) =>
      _alterar(_configuracao.copyWith(colunas: colunas));

  void escolherModuloQr(int modulo) =>
      _alterar(_configuracao.copyWith(moduloQr: modulo));

  void escolherImprimirNaExpedicao({required bool ligado}) =>
      _alterar(_configuracao.copyWith(imprimirNaExpedicao: ligado));

  Future<void> imprimirTeste() async {
    if (ocupado) return;
    _testando = true;
    _mensagem = null;
    notifyListeners();

    final r = await _impressao.imprimirTeste(_configuracao);
    if (_descartado) return;
    _mensagem = r.fold<({String texto, bool erro})>(
      onOk: (texto) => (texto: texto, erro: false),
      onErr: (f) => (texto: f.message, erro: true),
    );
    _testando = false;
    notifyListeners();
  }

  /// Salva e devolve `true` em sucesso.
  Future<bool> salvar() async {
    if (ocupado) return false;
    _salvando = true;
    notifyListeners();

    await _store.salvar(_configuracao);
    if (_descartado) return true;
    _salvando = false;
    notifyListeners();
    return true;
  }

  void _alterar(ConfiguracaoImpressao nova) {
    _configuracao = nova;
    _mensagem = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
