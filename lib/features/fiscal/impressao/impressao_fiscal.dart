import 'dart:typed_data';

import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/failures/failure_codes.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/fiscal/cupom/cupom_layout.dart';
import 'package:rabbit_pdv/features/fiscal/cupom/cupom_nfce.dart';
import 'package:rabbit_pdv/features/fiscal/cupom/cupom_nfce_xml.dart';
import 'package:rabbit_pdv/features/fiscal/data/arquivo_fiscal_local.dart';
import 'package:rabbit_pdv/features/fiscal/data/nota_fiscal_repository.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_modelo.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/configuracao_impressao.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/escpos/cupom_escpos.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/escpos/pagina_teste_escpos.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/impressora_raw.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/xml_cupom_local.dart';

/// Imprime a nota para o cliente (guia fiscal v2.3 §9). Um ponto só para o
/// painel da nota e para a fila de expedição.
abstract interface class ImpressaoFiscal {
  /// - NFC-e: XML (`/cupom`, ou a cópia local sem internet) → cupom →
  ///   ESC/POS → térmica configurada.
  /// - NF-e: DANFE A4 aberto no visualizador do sistema (provisório, ver
  ///   [ArquivoFiscalLocal]).
  ///
  /// Só nota autorizada e sem cancelamento em andamento (§9.4). Devolve a
  /// mensagem de sucesso para o operador.
  Future<Result<String, Failure>> imprimir({
    required String notaId,
    required NotaModelo modelo,
    required NotaStatus status,
    required bool cancelamentoEmAndamento,
  });

  /// Página de teste na térmica de [configuracao] (ainda não salva).
  Future<Result<String, Failure>> imprimirTeste(
    ConfiguracaoImpressao configuracao,
  );
}

class ImpressaoFiscalImpl implements ImpressaoFiscal {
  ImpressaoFiscalImpl({
    required NotaFiscalRepository repo,
    required XmlCupomLocal xmlLocal,
    required ImpressoraRaw impressora,
    required ConfiguracaoImpressaoStore configuracao,
    required ArquivoFiscalLocal arquivos,
  }) : _repo = repo,
       _xmlLocal = xmlLocal,
       _impressora = impressora,
       _configuracao = configuracao,
       _arquivos = arquivos;

  final NotaFiscalRepository _repo;
  final XmlCupomLocal _xmlLocal;
  final ImpressoraRaw _impressora;
  final ConfiguracaoImpressaoStore _configuracao;
  final ArquivoFiscalLocal _arquivos;

  static const _semImpressora = BusinessRuleFailure(
    'Configure a impressora térmica deste terminal em "Impressoras".',
    code: FailureCodes.impressoraNaoConfigurada,
  );

  static const _naoImprimivel = BusinessRuleFailure(
    'Só nota autorizada e sem cancelamento em andamento vai para o cliente.',
    code: FailureCodes.notaNaoImprimivel,
  );

  @override
  Future<Result<String, Failure>> imprimir({
    required String notaId,
    required NotaModelo modelo,
    required NotaStatus status,
    required bool cancelamentoEmAndamento,
  }) async {
    if (status != NotaStatus.autorizada || cancelamentoEmAndamento) {
      return const Err<String, Failure>(_naoImprimivel);
    }
    return switch (modelo) {
      NotaModelo.nfce => await _imprimirCupom(notaId),
      NotaModelo.nfe => await _abrirDanfe(notaId),
    };
  }

  @override
  Future<Result<String, Failure>> imprimirTeste(
    ConfiguracaoImpressao configuracao,
  ) async {
    final impressora = configuracao.impressoraTermica;
    if (impressora == null || impressora.isEmpty) {
      return const Err<String, Failure>(_semImpressora);
    }
    final bytes = PaginaTesteEscPos.gerar(
      colunas: configuracao.colunas,
      moduloQr: configuracao.moduloQr,
    );
    return _enviar(
      impressora,
      bytes,
      documento: 'Teste de impressão',
      sucesso: 'Teste enviado para "$impressora". Meça o QR com a margem '
          'branca: mínimo 25 mm.',
    );
  }

  // ── NFC-e ──

  Future<Result<String, Failure>> _imprimirCupom(String notaId) async {
    final configuracao = await _configuracao.ler();
    final impressora = configuracao.impressoraTermica;
    if (impressora == null || impressora.isEmpty) {
      return const Err<String, Failure>(_semImpressora);
    }
    final xml = await _obterXml(notaId);
    return switch (xml) {
      Err(:final failure) => Err<String, Failure>(failure),
      Ok(:final value) => await _imprimirXml(value, configuracao, impressora),
    };
  }

  Future<Result<String, Failure>> _imprimirXml(
    String xml,
    ConfiguracaoImpressao configuracao,
    String impressora,
  ) async {
    return switch (CupomNfceXml.ler(xml)) {
      // XML incompleto: NUNCA imprime um cupom pela metade (§9.2).
      Err(:final failure) => Err<String, Failure>(failure),
      Ok(:final value) => await _enviar(
        impressora,
        _bytesDoCupom(value, configuracao),
        documento: 'NFC-e ${value.numero}',
        sucesso: 'Cupom enviado para "$impressora".',
      ),
    };
  }

  Uint8List _bytesDoCupom(CupomNfce cupom, ConfiguracaoImpressao c) =>
      CupomEscPos.gerar(
        CupomLayout.montar(cupom, colunas: c.colunas),
        colunas: c.colunas,
        moduloQr: c.moduloQr,
      );

  /// O XML vem do backend e é guardado no terminal. Sem resposta do
  /// servidor (sem rede, timeout), a reimpressão usa a cópia local (§9.4).
  /// Erro COM resposta — ex.: 404 de nota que foi cancelada — não cai na
  /// cópia: cancelada não se imprime para o cliente.
  Future<Result<String, Failure>> _obterXml(String notaId) async {
    final remoto = await _repo.baixarCupomXml(notaId);
    if (remoto case Ok(:final value)) {
      await _xmlLocal.salvar(notaId, value);
      return remoto;
    }
    if (remoto case Err(failure: NetworkFailure(statusCode: null))) {
      final local = await _xmlLocal.ler(notaId);
      if (local != null) return Ok(local);
    }
    return remoto;
  }

  // ── NF-e ──

  Future<Result<String, Failure>> _abrirDanfe(String notaId) async {
    final baixado = await _repo.baixarDanfe(notaId);
    return switch (baixado) {
      Err(:final failure) => Err<String, Failure>(failure),
      Ok(:final value) =>
        (await _arquivos.abrirDanfe(
          value,
          nomeBase: 'danfe-$notaId',
        )).fold<Result<String, Failure>>(
          onOk: (_) => const Ok(
            'DANFE aberto no visualizador do sistema. Imprima por lá '
            '(Ctrl+P).',
          ),
          onErr: (f) => Err(f),
        ),
    };
  }

  // ── Envio ──

  Future<Result<String, Failure>> _enviar(
    String impressora,
    Uint8List bytes, {
    required String documento,
    required String sucesso,
  }) async {
    final enviado = await _impressora.enviar(
      impressora,
      bytes,
      documento: documento,
    );
    return enviado.fold<Result<String, Failure>>(
      onOk: (_) => Ok(sucesso),
      onErr: (f) => Err(f),
    );
  }
}
