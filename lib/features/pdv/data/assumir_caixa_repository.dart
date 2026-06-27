import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/failures/failure_codes.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/assumir_caixa_dtos.dart';

abstract interface class AssumirCaixaRepository {
  /// POST /pdv/caixas/{cashSessionId}/assumir — tomada de posse (custódia A→B),
  /// autenticada como B (próprio JWT).
  ///
  /// Sucesso: **201** (gravado agora) ou **200** (idempotente — replay do mesmo
  /// [AssumirCaixaRequest.eventId]). Atribuição de venda é por token: sem rebind.
  Future<Result<AssumirCaixaResponse, Failure>> assumir({
    required String cashSessionId,
    required AssumirCaixaRequest request,
  });
}

class AssumirCaixaRepositoryImpl implements AssumirCaixaRepository {
  AssumirCaixaRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<AssumirCaixaResponse, Failure>> assumir({
    required String cashSessionId,
    required AssumirCaixaRequest request,
  }) async {
    // SEM skipAuthRefresh (≠ anulação): o bearer aqui é o do próprio B. Um 401
    // significa token de B expirado → o AuthInterceptor renova normalmente.
    final res = await _api.send<AssumirCaixaResponse>(
      (dio) => dio.post<dynamic>(
        '/pdv/caixas/$cashSessionId/assumir',
        data: request.toJson(),
      ),
      decode: (data) =>
          AssumirCaixaResponse.fromJson(data as Map<String, dynamic>),
    );

    return res.fold(
      onOk: (r) => Ok<AssumirCaixaResponse, Failure>(r),
      onErr: (f) => Err<AssumirCaixaResponse, Failure>(_traduzir(f)),
    );
  }

  /// O 403 vem sem corpo (barrado no SecurityFilterChain) → o ApiClient o reduz
  /// a `SEM_PERMISSAO`; aqui dou contexto de posse. Os demais já chegam roteáveis
  /// pelo `code` estável do corpo de erro tipado (contrato §8) → passam direto.
  Failure _traduzir(Failure f) {
    if (f is BusinessRuleFailure && f.code == FailureCodes.semPermissao) {
      return const BusinessRuleFailure(
        'Você não tem permissão para assumir o caixa (cx.takeover).',
        code: FailureCodes.semPermissao,
      );
    }
    return f;
  }
}
