import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/provisionamento/data/dto/device_enrollment_dtos.dart';

abstract interface class DeviceEnrollmentRepository {
  /// POST /admin/device-enrollments (JWT + iam.device.manage + headers device).
  Future<Result<DeviceEnrollmentResponse, Failure>> emitir(
    DeviceEnrollmentRequest request,
  );

  /// POST /admin/devices/{deviceId}/revogar → 204. Libera o caixa para receber
  /// um novo terminal. Requer iam.device.manage + estação confiável.
  Future<Result<void, Failure>> revogar(String deviceId, {String? motivo});
}

class DeviceEnrollmentRepositoryImpl implements DeviceEnrollmentRepository {
  DeviceEnrollmentRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<DeviceEnrollmentResponse, Failure>> emitir(
    DeviceEnrollmentRequest request,
  ) {
    return _api.send<DeviceEnrollmentResponse>(
      (dio) => dio.post<dynamic>(
        '/admin/device-enrollments',
        data: request.toJson(),
      ),
      decode: (data) =>
          DeviceEnrollmentResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Result<void, Failure>> revogar(String deviceId, {String? motivo}) {
    final m = motivo?.trim();
    return _api.send<void>(
      (dio) => dio.post<dynamic>(
        '/admin/devices/$deviceId/revogar',
        data: (m == null || m.isEmpty) ? null : {'motivo': m},
      ),
      decode: (_) {},
    );
  }
}
