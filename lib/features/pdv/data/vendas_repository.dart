import 'package:dio/dio.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/registrar_venda_request.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/registrar_venda_response.dart';

abstract interface class VendasRepository {
  Future<Result<RegistrarVendaResponse, Failure>> registrar(
    RegistrarVendaRequest req,
  );
  Future<Result<void, Failure>> cancelar({
    required String vendaId,
    required String actorId,
  });
}

class VendasRepositoryImpl implements VendasRepository {
  VendasRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<RegistrarVendaResponse, Failure>> registrar(
    RegistrarVendaRequest req,
  ) {
    return _api.send<RegistrarVendaResponse>(
      (dio) => dio.post<dynamic>('/pdv/vendas', data: req.toJson()),
      decode: (data) =>
          RegistrarVendaResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Result<void, Failure>> cancelar({
    required String vendaId,
    required String actorId,
  }) {
    // Idempotente: cancelar venda já cancelada não dá erro (§5.4).
    return _api.send<void>(
      (dio) => dio.post<dynamic>(
        '/pdv/vendas/$vendaId/cancelar',
        options: Options(headers: {'X-Actor-Id': actorId}),
      ),
      decode: (_) {},
    );
  }
}
