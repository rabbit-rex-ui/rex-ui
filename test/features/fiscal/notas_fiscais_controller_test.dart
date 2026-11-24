import 'package:flutter_test/flutter_test.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/failures/failure_codes.dart';
import 'package:rabbit_pdv/core/json/pagina_response.dart';
import 'package:rabbit_pdv/core/network/arquivo_baixado.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/cancelar_nota_request.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/nota_fiscal_response.dart';
import 'package:rabbit_pdv/features/fiscal/data/nota_fiscal_repository.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_modelo.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/configuracao_impressao.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/impressao_fiscal.dart';
import 'package:rabbit_pdv/features/fiscal/presentation/notas_fiscais_controller.dart';

import 'fiscal_fixtures.dart';

/// Repositório falso: cada teste programa só o que usa.
class _RepoFalso implements NotaFiscalRepository {
  Result<List<NotaFiscalResponse>, Failure> lista = const Ok([]);
  Result<NotaFiscalResponse, Failure>? respostaCancelar;
  Result<NotaFiscalResponse, Failure>? respostaEmitir;
  int chamadasCancelar = 0;

  @override
  Future<Result<List<NotaFiscalResponse>, Failure>> listarPorVenda(
    String vendaId,
  ) async => lista;

  @override
  Future<Result<NotaFiscalResponse, Failure>> cancelar(
    String notaId,
    CancelarNotaRequest request, {
    String? cenarioMock,
  }) async {
    chamadasCancelar++;
    return respostaCancelar!;
  }

  @override
  Future<Result<NotaFiscalResponse, Failure>> emitir(
    String vendaId, {
    String? cenarioMock,
  }) async => respostaEmitir!;

  @override
  Future<Result<NotaFiscalResponse, Failure>> buscar(String notaId) =>
      throw UnimplementedError();

  @override
  Future<Result<NotaFiscalResponse, Failure>> consultar(String notaId) =>
      throw UnimplementedError();

  @override
  Future<Result<String, Failure>> baixarCupomXml(String notaId) =>
      throw UnimplementedError();

  @override
  Future<Result<PaginaResponse<NotaFiscalResponse>, Failure>> listarAtencao({
    int page = 0,
    int size = 20,
  }) => throw UnimplementedError();

  @override
  Future<Result<ArquivoBaixado, Failure>> baixarDanfe(String notaId) =>
      throw UnimplementedError();

  @override
  Future<Result<void, Failure>> mockDesfecho(String notaId, String cenario) =>
      throw UnimplementedError();
}

class _ImpressaoFalsa implements ImpressaoFiscal {
  @override
  Future<Result<String, Failure>> imprimir({
    required String notaId,
    required NotaModelo modelo,
    required NotaStatus status,
    required bool cancelamentoEmAndamento,
  }) => throw UnimplementedError();

  @override
  Future<Result<String, Failure>> imprimirTeste(
    ConfiguracaoImpressao configuracao,
  ) => throw UnimplementedError();
}

void main() {
  late _RepoFalso repo;
  late NotasFiscaisController ctrl;

  setUp(() {
    repo = _RepoFalso();
    ctrl = NotasFiscaisController(
      repo: repo,
      impressao: _ImpressaoFalsa(),
      vendaId: 'venda-1',
    );
  });

  tearDown(() => ctrl.dispose());

  const justificativa = 'Cliente desistiu da compra no caixa';

  test('carrega a lista; nota autorizada não deixa emitir de novo', () async {
    repo.lista = Ok([nota()]);
    await ctrl.carregar();

    expect(ctrl.notaAtual?.status, NotaStatus.autorizada);
    expect(ctrl.podeEmitir, isFalse);
    expect(ctrl.erroCarga, isNull);
  });

  test('nota cancelada libera "Emitir de novo"', () async {
    repo.lista = Ok([nota(status: 'CANCELLED')]);
    await ctrl.carregar();
    expect(ctrl.podeEmitir, isTrue);
  });

  test('justificativa curta é barrada sem chamar o backend', () async {
    repo.lista = Ok([nota()]);
    await ctrl.carregar();

    await ctrl.cancelar('curta');

    expect(repo.chamadasCancelar, 0);
    expect(ctrl.aviso?.erro, isTrue);
  });

  test('cancelamento homologado substitui a nota', () async {
    repo.lista = Ok([nota()]);
    await ctrl.carregar();
    repo.respostaCancelar = Ok(nota(status: 'CANCELLED'));

    await ctrl.cancelar(justificativa);

    expect(ctrl.notaAtual?.status, NotaStatus.cancelada);
    expect(ctrl.aviso?.erro, isFalse);
    expect(ctrl.ocupado, isFalse);
  });

  test('503 no cancelamento: resultado incerto e lista ressincronizada '
      '(guia §8.4)', () async {
    repo.lista = Ok([nota()]);
    await ctrl.carregar();
    repo.respostaCancelar = const Err(
      NetworkFailure('Provedor fiscal indisponível', statusCode: 503),
    );
    // O backend passa a marcar o cancelamento em andamento.
    repo.lista = Ok([nota(cancelamentoEmAndamento: true)]);

    await ctrl.cancelar(justificativa);

    expect(ctrl.notaAtual?.cancelamentoEmAndamento, isTrue);
    expect(ctrl.aviso?.texto, contains('em andamento'));
    expect(ctrl.ultimaJustificativa, justificativa);
  });

  test('recusa 422 mostra a orientação do backend e mantém a nota', () async {
    repo.lista = Ok([nota()]);
    await ctrl.carregar();
    repo.respostaCancelar = const Err(
      BusinessRuleFailure(
        'Prazo de cancelamento expirado.',
        code: FailureCodes.prazoCancelamentoExpirado,
        details: {
          'motivo': 'PRAZO_EXPIRADO',
          'orientacao': 'Emita nota de devolução.',
        },
      ),
    );

    await ctrl.cancelar(justificativa);

    expect(ctrl.notaAtual?.status, NotaStatus.autorizada);
    expect(ctrl.aviso?.orientacao, 'Emita nota de devolução.');
    expect(ctrl.aviso?.texto, contains('continua autorizada'));
  });

  test('409 nota ativa existente na reemissão vira mensagem própria', () async {
    repo.lista = Ok([nota(status: 'DENIED')]);
    await ctrl.carregar();
    repo.respostaEmitir = const Err(
      BusinessRuleFailure(
        'Já existe nota ativa',
        code: FailureCodes.notaFiscalAtivaExistente,
      ),
    );

    await ctrl.emitir();

    expect(ctrl.aviso?.texto, contains('Já existe uma nota'));
  });
}
