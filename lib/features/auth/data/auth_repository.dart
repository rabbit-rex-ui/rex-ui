import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/auth/data/dto/login_dtos.dart';

abstract interface class AuthRepository {
  Future<Result<LoginResponse, Failure>> login(LoginRequest req);
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<LoginResponse, Failure>> login(LoginRequest req) {
    return _api.send<LoginResponse>(
      (dio) => dio.post<dynamic>('/auth/login', data: req.toJson()),
      decode: (data) => LoginResponse.fromJson(data as Map<String, dynamic>),
    );
  }
}
