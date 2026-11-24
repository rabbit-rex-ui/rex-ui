import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/failures/failure_codes.dart';
import 'package:rabbit_pdv/core/network/arquivo_baixado.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/fiscal/data/arquivo_fiscal_local.dart';
import 'package:rabbit_pdv/features/fiscal/data/nota_fiscal_repository.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_modelo.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/configuracao_impressao.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/impressao_fiscal.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/impressora_raw.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/xml_cupom_local.dart';

final _xmlExemplo = File(
  'test/fixtures/cupom_nfce/nfce-01-autorizada-nao-identificado.xml',
).readAsStringSync();

class _Repo implements NotaFiscalRepository {
  Result<String, Failure> cupom = Ok(_xmlExemplo);

  @override
  Future<Result<String, Failure>> baixarCupomXml(String notaId) async => cupom;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _XmlLocal implements XmlCupomLocal {
  final copias = <String, String>{};

  @override
  Future<void> salvar(String notaId, String xml) async => copias[notaId] = xml;

  @override
  Future<String?> ler(String notaId) async => copias[notaId];
}

class _Impressora implements ImpressoraRaw {
  final enviados = <Uint8List>[];

  @override
  Future<Result<void, Failure>> enviar(
    String impressora,
    Uint8List bytes, {
    required String documento,
  }) async {
    enviados.add(bytes);
    return const Ok(null);
  }

  @override
  Future<Result<List<String>, Failure>> listar() async => const Ok([]);
}

class _Config implements ConfiguracaoImpressaoStore {
  _Config(this.valor);
  ConfiguracaoImpressao valor;

  @override
  Future<ConfiguracaoImpressao> ler() async => valor;

  @override
  Future<void> salvar(ConfiguracaoImpressao configuracao) async =>
      valor = configuracao;
}

class _Arquivos implements ArquivoFiscalLocal {
  @override
  Future<Result<String, Failure>> abrirDanfe(
    ArquivoBaixado arquivo, {
    required String nomeBase,
  }) => throw UnimplementedError();
}

void main() {
  late _Repo repo;
  late _XmlLocal xmlLocal;
  late _Impressora impressora;
  late _Config config;
  late ImpressaoFiscal servico;

  setUp(() {
    repo = _Repo();
    xmlLocal = _XmlLocal();
    impressora = _Impressora();
    config = _Config(
      const ConfiguracaoImpressao(impressoraTermica: 'EPSON TM-T20'),
    );
    servico = ImpressaoFiscalImpl(
      repo: repo,
      xmlLocal: xmlLocal,
      impressora: impressora,
      configuracao: config,
      arquivos: _Arquivos(),
    );
  });

  Future<Result<String, Failure>> imprimirNfce({
    NotaStatus status = NotaStatus.autorizada,
    bool cancelamentoEmAndamento = false,
  }) => servico.imprimir(
    notaId: 'n1',
    modelo: NotaModelo.nfce,
    status: status,
    cancelamentoEmAndamento: cancelamentoEmAndamento,
  );

  test('NFC-e autorizada: imprime e guarda a cópia local do XML', () async {
    final r = await imprimirNfce();
    expect(r, isA<Ok<String, Failure>>());
    expect(impressora.enviados, hasLength(1));
    expect(xmlLocal.copias['n1'], _xmlExemplo);
  });

  test('sem rede: reimprime da cópia local (§9.4)', () async {
    xmlLocal.copias['n1'] = _xmlExemplo;
    repo.cupom = const Err(NetworkFailure('Sem conexão com o servidor.'));

    final r = await imprimirNfce();

    expect(r, isA<Ok<String, Failure>>());
    expect(impressora.enviados, hasLength(1));
  });

  test('404 (nota cancelada) NÃO cai na cópia local', () async {
    xmlLocal.copias['n1'] = _xmlExemplo;
    repo.cupom = const Err(NotFoundFailure('Arquivo indisponível'));

    final r = await imprimirNfce();

    expect(r, isA<Err<String, Failure>>());
    expect(impressora.enviados, isEmpty);
  });

  test('nota não autorizada ou com cancelamento em andamento: não imprime',
      () async {
    expect(
      await imprimirNfce(status: NotaStatus.cancelada),
      isA<Err<String, Failure>>(),
    );
    expect(
      await imprimirNfce(cancelamentoEmAndamento: true),
      isA<Err<String, Failure>>(),
    );
    expect(impressora.enviados, isEmpty);
  });

  test('sem térmica configurada: código próprio para a tela oferecer atalho',
      () async {
    config.valor = const ConfiguracaoImpressao();
    final r = await imprimirNfce();
    expect(
      r,
      isA<Err<String, Failure>>().having(
        (e) => (e.failure as BusinessRuleFailure).code,
        'code',
        FailureCodes.impressoraNaoConfigurada,
      ),
    );
  });

  test('XML incompleto: não imprime cupom pela metade', () async {
    repo.cupom = Ok(
      _xmlExemplo.replaceAll(
        RegExp('<infNFeSupl>.*?</infNFeSupl>', dotAll: true),
        '',
      ),
    );
    expect(await imprimirNfce(), isA<Err<String, Failure>>());
    expect(impressora.enviados, isEmpty);
  });
}

