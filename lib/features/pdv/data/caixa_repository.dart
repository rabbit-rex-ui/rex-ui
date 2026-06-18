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
}
