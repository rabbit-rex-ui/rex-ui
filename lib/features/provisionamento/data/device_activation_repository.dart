import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/provisionamento/data/dto/device_activation_dtos.dart';

abstract interface class DeviceActivationRepository {
  Future<Result<DeviceActivationResponse, Failure>> ativar(
    DeviceActivationRequest request,
  );
}

class DeviceActivationRepositoryImpl implements DeviceActivationRepository {
  DeviceActivationRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<DeviceActivationResponse, Failure>> ativar(
    DeviceActivationRequest request,
  ) async {
    final r = await _api.send<DeviceActivationResponse>(
      (dio) => dio.post<dynamic>('/devices/activate', data: request.toJson()),
      decode: (data) =>
          DeviceActivationResponse.fromJson(data as Map<String, dynamic>),
    );
    return r.fold(onOk: Ok.new, onErr: (f) => Err(_traduzir(f)));
  }

  Failure _traduzir(Failure f) {
    if (f is NotFoundFailure) {
      return const BusinessRuleFailure(
        'Token inválido ou já utilizado.',
        code: 'ENROLLMENT_INVALIDO',
      );
    }
    if (f is NetworkFailure && f.statusCode == 409) {
      return const BusinessRuleFailure(
        'Este caixa já possui um terminal ativo.',
        code: 'CAIXA_JA_ATIVO',
      );
    }
    if (f is NetworkFailure && f.statusCode == 410) {
      return const BusinessRuleFailure(
        'Token expirado. Emita um novo no back-office.',
        code: 'ENROLLMENT_EXPIRADO',
      );
    }
    return f;
  }
}
