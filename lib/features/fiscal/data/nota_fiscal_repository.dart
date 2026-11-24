import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/json/pagina_response.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/network/arquivo_baixado.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/fiscal/data/cenario_mock_fiscal.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/cancelar_nota_request.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/nota_fiscal_response.dart';

/// Acesso à API de notas fiscais (`/fis/notas`, guia fiscal v2.0 §6). Um
/// método por endpoint.
///
/// Roteamento de erros (códigos em `FailureCodes`): 409/422 viram
/// `BusinessRuleFailure` com o sufixo do `type`; 503
/// (`provedor-fiscal-indisponivel`) vira `NetworkFailure(statusCode: 503)`.
abstract interface class NotaFiscalRepository {
  /// GET /fis/notas/{id} — detalhe e polling. Requer `fis.invoice.view`.
  Future<Result<NotaFiscalResponse, Failure>> buscar(String notaId);

  /// GET /fis/notas?vendaId= — todas as notas da venda, mais recente primeiro.
  /// Logo depois do faturar pode vir vazia por ~1 s (guia §7). Requer
  /// `fis.invoice.view`.
  Future<Result<List<NotaFiscalResponse>, Failure>> listarPorVenda(
    String vendaId,
  );

  /// GET /fis/notas/atencao — notas com `requerAtencao = true`, mais antigas
  /// primeiro (guia v2.3 §6.6). [size] de 1 a 100. Requer `fis.invoice.view`.
  Future<Result<PaginaResponse<NotaFiscalResponse>, Failure>> listarAtencao({
    int page = 0,
    int size = 20,
  });

  /// POST /fis/notas/vendas/{vendaId}/emitir → 202 com a nota em PENDING.
  /// Emissão manual / reemissão depois de rejeição ou cancelamento (guia
  /// §6.1). Requer `fis.invoice.issue`. [cenarioMock] só vale no modo mock.
  Future<Result<NotaFiscalResponse, Failure>> emitir(
    String vendaId, {
    String? cenarioMock,
  });

  /// POST /fis/notas/{id}/cancelar — síncrono: o 200 já traz a nota
  /// CANCELLED, e repetir sobre nota cancelada também dá 200 (idempotente).
  /// 503 = resultado incerto (guia §8.4). Requer `fis.invoice.cancel`.
  Future<Result<NotaFiscalResponse, Failure>> cancelar(
    String notaId,
    CancelarNotaRequest request, {
    String? cenarioMock,
  });

  /// POST /fis/notas/{id}/consultar — "Consultar SEFAZ": consulta o provedor
  /// agora e aplica a resposta (nota presa ou cancelamento em andamento).
  /// Requer `fis.invoice.issue`.
  Future<Result<NotaFiscalResponse, Failure>> consultar(String notaId);

  /// GET /fis/notas/{id}/cupom — XML autorizado da NFC-e, fonte do cupom
  /// (guia v2.3 §6.5). Só NFC-e AUTHORIZED; NF-e, não autorizada ou
  /// cancelada → 404 `arquivo-fiscal-indisponivel`. Requer `fis.invoice.view`.
  Future<Result<String, Failure>> baixarCupomXml(String notaId);

  /// GET /fis/notas/{id}/danfe — NF-e em PDF A4 (impresso na expedição,
  /// guia v2.2 §9.5); NFC-e em HTML (só retaguarda). Decida pelo tipo de mídia
  /// do arquivo, não pelo modelo. Requer `fis.invoice.view`.
  Future<Result<ArquivoBaixado, Failure>> baixarDanfe(String notaId);

  /// Só no modo mock: POST /fis/mock/notas/{id}/desfecho?cenario= conclui na
  /// hora uma nota SENT ("SEFAZ terminou", guia §11). Em produção, 403.
  Future<Result<void, Failure>> mockDesfecho(String notaId, String cenario);
}

class NotaFiscalRepositoryImpl implements NotaFiscalRepository {
  NotaFiscalRepositoryImpl(this._api);
  final ApiClient _api;

  static const _base = '/fis/notas';

  @override
  Future<Result<NotaFiscalResponse, Failure>> buscar(String notaId) {
    return _api.send<NotaFiscalResponse>(
      (dio) => dio.get<dynamic>('$_base/$notaId'),
      decode: _nota,
    );
  }

  @override
  Future<Result<List<NotaFiscalResponse>, Failure>> listarPorVenda(
    String vendaId,
  ) {
    return _api.send<List<NotaFiscalResponse>>(
      (dio) => dio.get<dynamic>(
        _base,
        queryParameters: <String, dynamic>{'vendaId': vendaId},
      ),
      decode: (data) => (data as List<dynamic>).map(_nota).toList(),
    );
  }

  @override
  Future<Result<PaginaResponse<NotaFiscalResponse>, Failure>> listarAtencao({
    int page = 0,
    int size = 20,
  }) {
    return _api.send<PaginaResponse<NotaFiscalResponse>>(
      (dio) => dio.get<dynamic>(
        '$_base/atencao',
        queryParameters: <String, dynamic>{'page': page, 'size': size},
      ),
      decode: (data) => PaginaResponse<NotaFiscalResponse>.fromJson(
        data as Map<String, dynamic>,
        NotaFiscalResponse.fromJson,
      ),
    );
  }

  @override
  Future<Result<NotaFiscalResponse, Failure>> emitir(
    String vendaId, {
    String? cenarioMock,
  }) {
    return _api.send<NotaFiscalResponse>(
      (dio) => dio.post<dynamic>(
        '$_base/vendas/$vendaId/emitir',
        options: _comCenarioMock(cenarioMock),
      ),
      decode: _nota,
    );
  }

  @override
  Future<Result<NotaFiscalResponse, Failure>> cancelar(
    String notaId,
    CancelarNotaRequest request, {
    String? cenarioMock,
  }) {
    return _api.send<NotaFiscalResponse>(
      (dio) => dio.post<dynamic>(
        '$_base/$notaId/cancelar',
        data: request.toJson(),
        options: _comCenarioMock(cenarioMock),
      ),
      decode: _nota,
    );
  }

  @override
  Future<Result<NotaFiscalResponse, Failure>> consultar(String notaId) {
    return _api.send<NotaFiscalResponse>(
      (dio) => dio.post<dynamic>('$_base/$notaId/consultar'),
      decode: _nota,
    );
  }

  @override
  Future<Result<String, Failure>> baixarCupomXml(String notaId) async {
    final result = await _api.download('$_base/$notaId/cupom');
    return switch (result) {
      Ok(:final value) => _comoTexto(value),
      Err(:final failure) => Err<String, Failure>(failure),
    };
  }

  /// O XML da NF-e é UTF-8 por especificação.
  static Result<String, Failure> _comoTexto(ArquivoBaixado arquivo) {
    try {
      return Ok(utf8.decode(arquivo.bytes));
    } on FormatException catch (e) {
      return Err(
        UnknownFailure('XML do cupom em codificação inválida.', cause: e),
      );
    }
  }

  @override
  Future<Result<ArquivoBaixado, Failure>> baixarDanfe(String notaId) =>
      _api.download('$_base/$notaId/danfe');

  @override
  Future<Result<void, Failure>> mockDesfecho(String notaId, String cenario) {
    return _api.send<void>(
      (dio) => dio.post<dynamic>(
        '/fis/mock/notas/$notaId/desfecho',
        queryParameters: <String, dynamic>{'cenario': cenario},
      ),
      decode: (_) {},
    );
  }

  static NotaFiscalResponse _nota(dynamic data) =>
      NotaFiscalResponse.fromJson(data as Map<String, dynamic>);

  static Options? _comCenarioMock(String? cenario) => cenario == null
      ? null
      : Options(headers: {CenarioMockFiscal.header: cenario});
}
