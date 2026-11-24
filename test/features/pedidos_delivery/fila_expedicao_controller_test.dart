import 'package:flutter_test/flutter_test.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/json/pagina_response.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/nota_fiscal_resumo.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_modelo.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/configuracao_impressao.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/impressao_fiscal.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/pedido_resumo_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/pedido_delivery_repository.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_canal.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/fila_expedicao_controller.dart';

PedidoResumoResponse _pedido({
  NotaStatus? nota,
  NotaModelo modelo = NotaModelo.nfce,
}) => PedidoResumoResponse(
  pedidoId: 'p1',
  orderNumber: 1042,
  status: PedidoStatus.aguardandoExpedicao,
  canal: PedidoCanal.whatsapp,
  customerName: 'Carlos Dias',
  valorEstimado: 19.8,
  criadoEm: DateTime(2026, 11, 19),
  vendaId: 'v1',
  notaFiscal: nota == null
      ? null
      : NotaFiscalResumo(
          id: 'n1',
          modelo: modelo,
          status: nota,
          aptaParaExpedir: nota == NotaStatus.autorizada,
          cancelamentoEmAndamento: false,
          requerAtencao: false,
        ),
);

class _Pedidos implements PedidoDeliveryRepository {
  List<PedidoResumoResponse> fila = const [];

  @override
  Future<Result<PaginaResponse<PedidoResumoResponse>, Failure>> listar({
    PedidoStatus? status,
    int page = 0,
    int size = 20,
  }) async => Ok(
    PaginaResponse(
      conteudo: fila,
      pagina: 0,
      tamanho: size,
      total: fila.length,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Impressao implements ImpressaoFiscal {
  final impressas = <String>[];

  @override
  Future<Result<String, Failure>> imprimir({
    required String notaId,
    required NotaModelo modelo,
    required NotaStatus status,
    required bool cancelamentoEmAndamento,
  }) async {
    impressas.add(notaId);
    return const Ok('impresso');
  }

  @override
  Future<Result<String, Failure>> imprimirTeste(
    ConfiguracaoImpressao configuracao,
  ) => throw UnimplementedError();
}

class _Config implements ConfiguracaoImpressaoStore {
  _Config({required this.automatica});
  bool automatica;

  @override
  Future<ConfiguracaoImpressao> ler() async =>
      ConfiguracaoImpressao(imprimirNaExpedicao: automatica);

  @override
  Future<void> salvar(ConfiguracaoImpressao configuracao) async {}
}

void main() {
  late _Pedidos pedidos;
  late _Impressao impressao;
  late _Config config;
  late FilaExpedicaoController fila;
  var pausado = false;

  setUp(() {
    pedidos = _Pedidos();
    impressao = _Impressao();
    config = _Config(automatica: true);
    pausado = false;
    fila = FilaExpedicaoController(
      pedidos: pedidos,
      impressao: impressao,
      configuracao: config,
      pausado: () => pausado,
    );
  });

  tearDown(() => fila.dispose());

  test('imprime UMA vez quando a nota fica autorizada diante do terminal',
      () async {
    pedidos.fila = [_pedido(nota: NotaStatus.pendente)];
    await fila.atualizar();
    expect(impressao.impressas, isEmpty);

    pedidos.fila = [_pedido(nota: NotaStatus.autorizada)];
    await fila.atualizar();
    expect(impressao.impressas, ['n1']);

    await fila.atualizar(); // segue autorizada: não reimprime
    expect(impressao.impressas, ['n1']);
    expect(fila.foiImpressa(pedidos.fila.single.notaFiscal!), isTrue);
  });

  test('logo após o faturar (sem nota) também conta como "em andamento"',
      () async {
    pedidos.fila = [_pedido()];
    await fila.atualizar();
    pedidos.fila = [_pedido(nota: NotaStatus.autorizada)];
    await fila.atualizar();
    expect(impressao.impressas, ['n1']);
  });

  test('nota que já chega autorizada ao abrir a fila não sai sozinha',
      () async {
    pedidos.fila = [_pedido(nota: NotaStatus.autorizada)];
    await fila.atualizar();
    await fila.atualizar();
    expect(impressao.impressas, isEmpty);
  });

  test('terminal que não é a estação de expedição não imprime sozinho',
      () async {
    config.automatica = false;
    pedidos.fila = [_pedido(nota: NotaStatus.enviada)];
    await fila.atualizar();
    pedidos.fila = [_pedido(nota: NotaStatus.autorizada)];
    await fila.atualizar();
    expect(impressao.impressas, isEmpty);
  });

  test('NF-e não sai sozinha (DANFE ainda abre no visualizador)', () async {
    pedidos.fila = [_pedido(nota: NotaStatus.pendente, modelo: NotaModelo.nfe)];
    await fila.atualizar();
    pedidos.fila = [
      _pedido(nota: NotaStatus.autorizada, modelo: NotaModelo.nfe),
    ];
    await fila.atualizar();
    expect(impressao.impressas, isEmpty);
  });

  test('rejeitada não imprime', () async {
    pedidos.fila = [_pedido(nota: NotaStatus.pendente)];
    await fila.atualizar();
    pedidos.fila = [_pedido(nota: NotaStatus.rejeitada)];
    await fila.atualizar();
    expect(impressao.impressas, isEmpty);
  });

  test('terminal bloqueado: não consulta nem imprime', () async {
    pausado = true;
    pedidos.fila = [_pedido(nota: NotaStatus.autorizada)];
    await fila.atualizar();
    expect(fila.itens, isEmpty);
    expect(impressao.impressas, isEmpty);
  });

  test('reimpressão manual marca a nota como impressa', () async {
    pedidos.fila = [_pedido(nota: NotaStatus.autorizada)];
    await fila.atualizar();
    await fila.imprimir(pedidos.fila.single);
    expect(impressao.impressas, ['n1']);
    expect(fila.aviso?.erro, isFalse);
  });
}
