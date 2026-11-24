import 'package:shared_preferences/shared_preferences.dart';

import 'package:rabbit_pdv/features/fiscal/cupom/cupom_layout.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/escpos/comandos_escpos.dart';

/// Configuração de impressão DESTE terminal (cada estação tem a sua térmica).
class ConfiguracaoImpressao {
  const ConfiguracaoImpressao({
    this.impressoraTermica,
    this.colunas = CupomLayout.colunasPadrao,
    this.moduloQr = moduloQrPadrao,
    this.imprimirNaExpedicao = false,
  });

  /// 48 na fonte A em 80 mm; 42 em alguns modelos (guia §9.3).
  static const colunasPermitidas = [48, 42];

  /// 4 ou 5 numa térmica de 203 dpi; confirmar com a régua no teste.
  static const moduloQrPadrao = 5;

  /// Nome da fila no Windows; `null` = não configurada.
  final String? impressoraTermica;
  final int colunas;
  final int moduloQr;

  /// Esta é a estação de expedição: imprime a nota sozinha, uma vez, quando
  /// ela fica autorizada na fila (guia §7.1). Desligado nos demais caixas —
  /// senão todo terminal com a fila aberta imprimiria.
  final bool imprimirNaExpedicao;

  bool get termicaConfigurada => (impressoraTermica ?? '').isNotEmpty;

  ConfiguracaoImpressao copyWith({
    String? impressoraTermica,
    int? colunas,
    int? moduloQr,
    bool? imprimirNaExpedicao,
  }) => ConfiguracaoImpressao(
    impressoraTermica: impressoraTermica ?? this.impressoraTermica,
    colunas: colunas ?? this.colunas,
    moduloQr: moduloQr ?? this.moduloQr,
    imprimirNaExpedicao: imprimirNaExpedicao ?? this.imprimirNaExpedicao,
  );
}

abstract interface class ConfiguracaoImpressaoStore {
  Future<ConfiguracaoImpressao> ler();
  Future<void> salvar(ConfiguracaoImpressao configuracao);
}

/// Guarda a configuração nas preferências locais do terminal.
class ConfiguracaoImpressaoPrefs implements ConfiguracaoImpressaoStore {
  static const _chaveImpressora = 'fiscal.impressao.termica';
  static const _chaveColunas = 'fiscal.impressao.colunas';
  static const _chaveModuloQr = 'fiscal.impressao.moduloQr';
  static const _chaveExpedicao = 'fiscal.impressao.automaticaNaExpedicao';

  @override
  Future<ConfiguracaoImpressao> ler() async {
    final prefs = await SharedPreferences.getInstance();
    final colunas = prefs.getInt(_chaveColunas);
    final modulo = prefs.getInt(_chaveModuloQr);
    return ConfiguracaoImpressao(
      impressoraTermica: prefs.getString(_chaveImpressora),
      // Valor fora do permitido (preferência corrompida) volta ao padrão.
      colunas: ConfiguracaoImpressao.colunasPermitidas.contains(colunas)
          ? colunas!
          : CupomLayout.colunasPadrao,
      moduloQr:
          modulo != null &&
              modulo >= ComandosEscPos.moduloQrMinimo &&
              modulo <= ComandosEscPos.moduloQrMaximo
          ? modulo
          : ConfiguracaoImpressao.moduloQrPadrao,
      imprimirNaExpedicao: prefs.getBool(_chaveExpedicao) ?? false,
    );
  }

  @override
  Future<void> salvar(ConfiguracaoImpressao configuracao) async {
    final prefs = await SharedPreferences.getInstance();
    final impressora = configuracao.impressoraTermica;
    if (impressora == null || impressora.isEmpty) {
      await prefs.remove(_chaveImpressora);
    } else {
      await prefs.setString(_chaveImpressora, impressora);
    }
    await prefs.setInt(_chaveColunas, configuracao.colunas);
    await prefs.setInt(_chaveModuloQr, configuracao.moduloQr);
    await prefs.setBool(_chaveExpedicao, configuracao.imprimirNaExpedicao);
  }
}
