import 'package:dio/dio.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/caixa_dtos.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/cx_config.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/movimento_caixa_dtos.dart';

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

  /// Config do PDV por tenant (contrato v3 §5). Lida no boot para ajustar a UX
  /// (ex.: mostrar/esconder o destino COFRE na sangria). É informativa, não um
  /// gate: em erro, o chamador deve seguir com [CxConfigResponse.fallback] — o
  /// boot do caixa NÃO deve falhar por causa dela.
  Future<Result<CxConfigResponse, Failure>> cxConfig();

  /// Registra um movimento de caixa — sangria/reforço/suprimento (contrato v3
  /// §3). [idempotencyKey] é um UUIDv7 gerado UMA vez por operação e reusado em
  /// todo retry, inclusive no reenvio pós-403 do step-up (a MESMA chave — o 403
  /// não persiste nada). Roteie o erro pelo `code` do [BusinessRuleFailure] no
  /// controller.
  Future<Result<MovimentoCaixaResponse, Failure>> registrarMovimento(
    String sessionId,
    MovimentoCaixaRequest req, {
    required String idempotencyKey,
  });

  /// Sugestão de sangria (contrato v3 §4). Opcional: `404`
  /// (Err(NotFoundFailure)) quando a sessão não existe/não está aberta → o
  /// controller cai em entrada manual.
  Future<Result<SugestaoSangriaResponse, Failure>> sugestaoSangria(
    String sessionId,
  );
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

  @override
  Future<Result<CxConfigResponse, Failure>> cxConfig() {
    return _api.send<CxConfigResponse>(
      (dio) => dio.get<dynamic>('/pdv/cx-config'),
      decode: (d) => CxConfigResponse.fromJson(d as Map<String, dynamic>),
    );
  }

  @override
  Future<Result<MovimentoCaixaResponse, Failure>> registrarMovimento(
    String sessionId,
    MovimentoCaixaRequest req, {
    required String idempotencyKey,
  }) {
    return _api.send<MovimentoCaixaResponse>(
      (dio) => dio.post<dynamic>(
        '/pdv/caixas/$sessionId/movimentos',
        data: req.toJson(),
        options: Options(
          headers: {'Idempotency-Key': idempotencyKey},
          // Só quando há credencial de supervisor no corpo (step-up Imediata):
          // um 401 aqui é stepup-invalid-credential, NÃO token expirado.
          // Impede o AuthInterceptor de refresh+replay e mascarar o erro real.
          extra: req.temStepUp ? const {'skipAuthRefresh': true} : null,
        ),
      ),
      decode: (d) => MovimentoCaixaResponse.fromJson(d as Map<String, dynamic>),
    );
  }

  @override
  Future<Result<SugestaoSangriaResponse, Failure>> sugestaoSangria(
    String sessionId,
  ) {
    return _api.send<SugestaoSangriaResponse>(
      (dio) => dio.get<dynamic>('/pdv/caixas/$sessionId/sugestao-sangria'),
      decode: (d) =>
          SugestaoSangriaResponse.fromJson(d as Map<String, dynamic>),
    );
  }
}
