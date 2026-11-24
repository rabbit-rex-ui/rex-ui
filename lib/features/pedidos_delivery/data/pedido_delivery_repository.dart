import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/json/pagina_response.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/criar_pedido_request.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/criar_pedido_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/faturar_pedido_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/motivo_pedido_request.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/pedido_detalhe_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/pedido_resumo_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/pedido_transicao_requests.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/separar_pedido_request.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';

/// Acesso à API de pedidos de delivery (`/pdv/pedidos`, guia v2).
///
/// Largura total: um método por endpoint. Cobre criação (§4.1), consulta
/// (filas §4.12, detalhe §4.13), transições sem corpo (§4.2, §4.4, §4.5, §4.6),
/// separação (§4.3), fim feliz com corpo (§4.7 entregar, §4.8 concluir) e as
/// transições de exceção (§4.9 nao-entregue, §4.10 pagamento-recusado,
/// §4.11 devolver, §4.14 cancelar).
abstract interface class PedidoDeliveryRepository {
  /// POST /pdv/pedidos → cria um pedido no estado RECEBIDO (guia §4.1).
  ///
  /// [idempotencyKey] deve ser um UUIDv7 gerado UMA vez no início do fluxo e
  /// reusado em cada retry — nunca regenerado (idempotência da criação, §4.1).
  /// Chave repetida devolve o pedido já criado (200) sem duplicar.
  Future<Result<CriarPedidoResponse, Failure>> criar(
    CriarPedidoRequest request, {
    required String idempotencyKey,
  });

  /// GET /pdv/pedidos → fila paginada, mais recentes primeiro (guia §4.12).
  ///
  /// [status] omitido lista todos; um status por fila (ex.: SEPARANDO = fila de
  /// separação, EM_ROTA = fila de entrega). Requer `sls.order.view_own` ou
  /// `sls.order.view_all`.
  Future<Result<PaginaResponse<PedidoResumoResponse>, Failure>> listar({
    PedidoStatus? status,
    int page = 0,
    int size = 20,
  });

  /// GET /pdv/pedidos/{id} → detalhe completo (guia §4.13). É daqui que sai o
  /// `momentoPagamento` (decide o `formaPagamento` no concluir) e o `status`
  /// que define as ações. Requer `sls.order.view_own`/`view_all`.
  Future<Result<PedidoDetalheResponse, Failure>> detalhe(String id);

  /// POST /pdv/pedidos/{id}/confirmar → RECEBIDO → CONFIRMANDO (guia §4.2).
  /// Requer `sls.order.confirm`.
  Future<Result<void, Failure>> confirmar(String id);

  /// POST /pdv/pedidos/{id}/separar → RECEBIDO|CONFIRMANDO → SEPARANDO
  /// (guia §4.3). [request] traz as quantidades separadas / itens indisponíveis
  /// por linha. Requer `sls.order.separate`.
  Future<Result<void, Failure>> separar(
    String id,
    SepararPedidoRequest request,
  );

  /// POST /pdv/pedidos/{id}/conferir → SEPARANDO → CONFERIDO (guia §4.4).
  /// Exige que nenhum item siga SOLICITADO (todo item separado ou marcado
  /// indisponível). Requer `sls.order.confer`.
  Future<Result<void, Failure>> conferir(String id);

  /// POST /pdv/pedidos/{id}/faturar → CONFERIDO → AGUARDANDO_EXPEDICAO
  /// (guia §4.5). Materializa a venda e dispara a emissão da nota de forma
  /// assíncrona; responde 200 com o `vendaId` (guia fiscal v2.2 §7 — era 204).
  /// Requer `sls.order.invoice`.
  Future<Result<FaturarPedidoResponse, Failure>> faturar(String id);

  /// POST /pdv/pedidos/{id}/expedir → AGUARDANDO_EXPEDICAO → EM_ROTA
  /// (guia §4.6). Gate fiscal: se a nota ainda não está autorizada, retorna
  /// 409 `expedicao-bloqueada` → o PDV deve tentar de novo em alguns segundos.
  /// Requer `sls.order.dispatch`.
  Future<Result<void, Failure>> expedir(String id);

  /// POST /pdv/pedidos/{id}/entregar → EM_ROTA → ENTREGUE (guia §4.7).
  /// [request] carrega `recebidoPor` (prova de entrega, obrigatório).
  /// Requer `sls.order.deliver`.
  Future<Result<void, Failure>> entregar(
    String id,
    EntregarPedidoRequest request,
  );

  /// POST /pdv/pedidos/{id}/concluir → ENTREGUE → CONCLUIDO (guia §4.8).
  /// [request] nulo para ANTECIPADO (corpo omitido); para NA_ENTREGA (COD) é
  /// obrigatório com `formaPagamento`. Requer `sls.order.conclude`.
  Future<Result<void, Failure>> concluir(
    String id,
    ConcluirPedidoRequest? request,
  );

  /// POST /pdv/pedidos/{id}/nao-entregue → EM_ROTA → NAO_ENTREGUE (guia §4.9).
  /// [request] carrega `motivo` (obrigatório). Requer `sls.order.deliver`.
  Future<Result<void, Failure>> naoEntregue(
    String id,
    MotivoPedidoRequest request,
  );

  /// POST /pdv/pedidos/{id}/pagamento-recusado → ENTREGUE → PAGAMENTO_RECUSADO
  /// (guia §4.10). [request] opcional (`motivo` pode ser omitido → passe null).
  /// Requer `sls.order.deliver`.
  Future<Result<void, Failure>> pagamentoRecusado(
    String id,
    MotivoPedidoRequest? request,
  );

  /// POST /pdv/pedidos/{id}/devolver → NAO_ENTREGUE|PAGAMENTO_RECUSADO →
  /// DEVOLVIDO (guia §4.11). [request] carrega `motivo` (obrigatório).
  /// Requer `sls.order.return`.
  Future<Result<void, Failure>> devolver(
    String id,
    MotivoPedidoRequest request,
  );

  /// POST /pdv/pedidos/{id}/cancelar → RECEBIDO|CONFIRMANDO|SEPARANDO|CONFERIDO
  /// → CANCELADO (guia §4.14). Cancelamento limpo, pré-emissão. [request]
  /// carrega `motivo` (obrigatório). Requer `sls.order.cancel`.
  Future<Result<void, Failure>> cancelar(
    String id,
    MotivoPedidoRequest request,
  );
}

class PedidoDeliveryRepositoryImpl implements PedidoDeliveryRepository {
  PedidoDeliveryRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<CriarPedidoResponse, Failure>> criar(
    CriarPedidoRequest request, {
    required String idempotencyKey,
  }) {
    return _api.send<CriarPedidoResponse>(
      (dio) => dio.post<dynamic>(
        '/pdv/pedidos',
        data: request.toJson(),
        options: ApiClient.idempotent(idempotencyKey),
      ),
      decode: (data) =>
          CriarPedidoResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Result<PaginaResponse<PedidoResumoResponse>, Failure>> listar({
    PedidoStatus? status,
    int page = 0,
    int size = 20,
  }) {
    return _api.send<PaginaResponse<PedidoResumoResponse>>(
      (dio) => dio.get<dynamic>(
        '/pdv/pedidos',
        queryParameters: <String, dynamic>{
          'page': page,
          'size': size,
          if (status != null) 'status': status.wire,
        },
      ),
      decode: (data) => PaginaResponse<PedidoResumoResponse>.fromJson(
        data as Map<String, dynamic>,
        PedidoResumoResponse.fromJson,
      ),
    );
  }

  @override
  Future<Result<PedidoDetalheResponse, Failure>> detalhe(String id) {
    return _api.send<PedidoDetalheResponse>(
      (dio) => dio.get<dynamic>('/pdv/pedidos/$id'),
      decode: (data) =>
          PedidoDetalheResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Result<void, Failure>> confirmar(String id) =>
      _transicaoSemCorpo(id, 'confirmar');

  @override
  Future<Result<void, Failure>> separar(
    String id,
    SepararPedidoRequest request,
  ) {
    return _api.send<void>(
      (dio) =>
          dio.post<dynamic>('/pdv/pedidos/$id/separar', data: request.toJson()),
      decode: (_) {},
    );
  }

  @override
  Future<Result<void, Failure>> conferir(String id) =>
      _transicaoSemCorpo(id, 'conferir');

  @override
  Future<Result<FaturarPedidoResponse, Failure>> faturar(String id) {
    return _api.send<FaturarPedidoResponse>(
      (dio) => dio.post<dynamic>('/pdv/pedidos/$id/faturar'),
      decode: (data) =>
          FaturarPedidoResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Result<void, Failure>> expedir(String id) =>
      _transicaoSemCorpo(id, 'expedir');

  @override
  Future<Result<void, Failure>> entregar(
    String id,
    EntregarPedidoRequest request,
  ) {
    return _api.send<void>(
      (dio) => dio.post<dynamic>(
        '/pdv/pedidos/$id/entregar',
        data: request.toJson(),
      ),
      decode: (_) {},
    );
  }

  @override
  Future<Result<void, Failure>> concluir(
    String id,
    ConcluirPedidoRequest? request,
  ) {
    return _api.send<void>(
      (dio) => dio.post<dynamic>(
        '/pdv/pedidos/$id/concluir',
        data: request?.toJson(),
      ),
      decode: (_) {},
    );
  }

  @override
  Future<Result<void, Failure>> naoEntregue(
    String id,
    MotivoPedidoRequest request,
  ) {
    return _api.send<void>(
      (dio) => dio.post<dynamic>(
        '/pdv/pedidos/$id/nao-entregue',
        data: request.toJson(),
      ),
      decode: (_) {},
    );
  }

  @override
  Future<Result<void, Failure>> pagamentoRecusado(
    String id,
    MotivoPedidoRequest? request,
  ) {
    return _api.send<void>(
      (dio) => dio.post<dynamic>(
        '/pdv/pedidos/$id/pagamento-recusado',
        data: request?.toJson(),
      ),
      decode: (_) {},
    );
  }

  @override
  Future<Result<void, Failure>> devolver(
    String id,
    MotivoPedidoRequest request,
  ) {
    return _api.send<void>(
      (dio) => dio.post<dynamic>(
        '/pdv/pedidos/$id/devolver',
        data: request.toJson(),
      ),
      decode: (_) {},
    );
  }

  @override
  Future<Result<void, Failure>> cancelar(
    String id,
    MotivoPedidoRequest request,
  ) {
    return _api.send<void>(
      (dio) => dio.post<dynamic>(
        '/pdv/pedidos/$id/cancelar',
        data: request.toJson(),
      ),
      decode: (_) {},
    );
  }

  /// POST /pdv/pedidos/{id}/{acao} sem corpo → 204. O `decode` ignora a
  /// resposta vazia; o sucesso apenas sinaliza que a transição passou.
  Future<Result<void, Failure>> _transicaoSemCorpo(String id, String acao) {
    return _api.send<void>(
      (dio) => dio.post<dynamic>('/pdv/pedidos/$id/$acao'),
      decode: (_) {},
    );
  }
}
