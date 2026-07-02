import 'package:dio/dio.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/caixa_dtos.dart';

abstract interface class CaixaRepository {
  Future<Result<CaixaSessionResponse, Failure>> abrir(AbrirCaixaRequest req);

  /// Sessão aberta do caixa físico, ou Err(NotFoundFailure) (404) se não há.
  Future<Result<CaixaSessionResponse, Failure>> sessaoAberta(
    String cashRegisterId,
  );

  /// Sessão por id — usado para reidratar `expectedCash` antes de fechar.
  Future<Result<CaixaSessionResponse, Failure>> consultar(String sessionId);

  /// Fecha a sessão. O corpo decide o modo (limpo / cego / divergência).
  /// Roteie o erro pelo `code` do [BusinessRuleFailure] no controller.
  Future<Result<CaixaSessionResponse, Failure>> fechar(
    String sessionId,
    FecharCaixaRequest req,
  );

  /// Relatório de conferência (serve para sessão aberta ou fechada).
  Future<Result<RelatorioCaixaResponse, Failure>> relatorio(String sessionId);
}

class CaixaRepositoryImpl implements CaixaRepository {
  CaixaRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<CaixaSessionResponse, Failure>> abrir(AbrirCaixaRequest req) {
    return _api.send<CaixaSessionResponse>(
      (dio) => dio.post<dynamic>('/pdv/caixas/abrir', data: req.toJson()),
      decode: (d) => CaixaSessionResponse.fromJson(d as Map<String, dynamic>),
    );
  }

  @override
  Future<Result<CaixaSessionResponse, Failure>> sessaoAberta(
    String cashRegisterId,
  ) {
    return _api.send<CaixaSessionResponse>(
      (dio) => dio.get<dynamic>(
        '/pdv/caixas',
        queryParameters: {'cashRegisterId': cashRegisterId, 'status': 'OPEN'},
      ),
      decode: (d) => CaixaSessionResponse.fromJson(d as Map<String, dynamic>),
    );
  }

  @override
  Future<Result<CaixaSessionResponse, Failure>> consultar(String sessionId) {
    return _api.send<CaixaSessionResponse>(
      (dio) => dio.get<dynamic>('/pdv/caixas/$sessionId'),
      decode: (d) => CaixaSessionResponse.fromJson(d as Map<String, dynamic>),
    );
  }

  @override
  Future<Result<CaixaSessionResponse, Failure>> fechar(
    String sessionId,
    FecharCaixaRequest req,
  ) {
    return _api.send<CaixaSessionResponse>(
      (dio) => dio.post<dynamic>(
        '/pdv/caixas/$sessionId/fechar',
        data: req.toJson(),
        // Só quando há credencial de supervisor no corpo: um 401 aqui é
        // stepup-invalid-credential, NÃO token do operador expirado. Impede o
        // AuthInterceptor de tentar refresh+replay e mascarar o erro real.
        // Fechamento limpo/cego não passa a flag → 401 = sessão expirada mesmo.
        options: req.temStepUp
            ? Options(extra: const {'skipAuthRefresh': true})
            : null,
      ),
      decode: (d) => CaixaSessionResponse.fromJson(d as Map<String, dynamic>),
    );
  }

  @override
  Future<Result<RelatorioCaixaResponse, Failure>> relatorio(String sessionId) {
    return _api.send<RelatorioCaixaResponse>(
      (dio) => dio.get<dynamic>('/pdv/caixas/$sessionId/relatorio'),
      decode: (d) => RelatorioCaixaResponse.fromJson(d as Map<String, dynamic>),
    );
  }
}
