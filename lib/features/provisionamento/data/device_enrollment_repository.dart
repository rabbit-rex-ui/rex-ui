import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/provisionamento/data/dto/device_enrollment_dtos.dart';

abstract interface class DeviceEnrollmentRepository {
  /// POST /admin/device-enrollments (JWT + iam.device.manage + headers device).
  Future<Result<DeviceEnrollmentResponse, Failure>> emitir(
    DeviceEnrollmentRequest request,
  );
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
}
