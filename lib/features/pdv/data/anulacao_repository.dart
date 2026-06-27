import 'package:dio/dio.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/anular_item_dtos.dart';

abstract interface class AnulacaoRepository {
  /// POST /pdv/itens/anular — síncrono e bloqueante. Sucesso (201/200) só
  /// deve disparar a remoção do item no carrinho local.
  Future<Result<AnularItemResponse, Failure>> anularItem(
    AnularItemRequest request,
  );
}

class AnulacaoRepositoryImpl implements AnulacaoRepository {
  AnulacaoRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<AnularItemResponse, Failure>> anularItem(
    AnularItemRequest request,
  ) async {
    final res = await _api.send<AnularItemResponse>(
      (dio) => dio.post<dynamic>(
        '/pdv/itens/anular',
        data: request.toJson(),
        // O 401 aqui é credencial do SUPERVISOR no corpo, não a sessão do
        // operador. NÃO acionar refresh/logout do token do operador.
        options: Options(extra: const {'skipAuthRefresh': true}),
      ),
      decode: (data) =>
          AnularItemResponse.fromJson(data as Map<String, dynamic>),
    );

    return res.fold(
      onOk: (r) => Ok<AnularItemResponse, Failure>(r),
      onErr: (f) => Err<AnularItemResponse, Failure>(_traduzir(f)),
    );
  }

  /// Reescreve falhas genéricas do ApiClient para a semântica da anulação.
  Failure _traduzir(Failure f) {
    // ApiClient mapeia 401 → NetworkFailure('Sessão expirada'). No /anular,
    // 401 = login/senha do supervisor inválidos.
    if (f is NetworkFailure && f.statusCode == 401) {
      return const BusinessRuleFailure(
        'Código ou senha do supervisor inválidos.',
        code: 'SUPERVISOR_INVALIDO',
      );
    }
    // 403/409/422 já chegam como BusinessRuleFailure com `detail` do servidor;
    // 400 como ValidationFailure. A UI mostra `failure.message` direto.
    return f;
  }
}
