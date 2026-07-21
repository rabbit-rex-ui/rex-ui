import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/provisionamento/data/dto/pdv_fisico.dart';

abstract interface class CaixaFisicoRepository {
  /// GET /pdv/caixas-fisicos?code=PDV-01 → objeto único. 404 = code inexistente.
  Future<Result<PdvFisico, Failure>> buscarPorCode(String code);
  Future<Result<PdvFisico, Failure>> buscarPorId(String id);
}

class CaixaFisicoRepositoryImpl implements CaixaFisicoRepository {
  CaixaFisicoRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<PdvFisico, Failure>> buscarPorCode(String code) async {
    final result = await _api.send<PdvFisico>(
      (dio) => dio.get<dynamic>(
        '/pdv/caixas-fisicos',
        queryParameters: {'code': code},
      ),
      decode: (data) => PdvFisico.fromJson(data as Map<String, dynamic>),
    );
    // Traduz 404 (NotFoundFailure) para mensagem específica de code.
    return result.fold(
      onOk: Ok.new,
      onErr: (f) => Err(
        f is NotFoundFailure
            ? const NotFoundFailure('Caixa não encontrado para este código.')
            : f,
      ),
    );
  }

  @override
  Future<Result<PdvFisico, Failure>> buscarPorId(String id) async {
    final result = await _api.send<PdvFisico>(
      (dio) => dio.get<dynamic>('/pdv/caixas-fisicos/$id'),
      decode: (data) => PdvFisico.fromJson(data as Map<String, dynamic>),
    );
    return result.fold(
      onOk: Ok.new,
      onErr: (f) => Err(
        f is NotFoundFailure
            ? const NotFoundFailure('Caixa físico não encontrado.')
            : f,
      ),
    );
  }
}
