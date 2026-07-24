import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/auth/data/dto/auth_me_dto.dart';

abstract interface class AuthMeRepository {
  Future<Result<AuthMe, Failure>> me();
}

class AuthMeRepositoryImpl implements AuthMeRepository {
  AuthMeRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<AuthMe, Failure>> me() {
    return _api.send<AuthMe>(
      (dio) => dio.get<dynamic>('/auth/me'),
      decode: (data) => AuthMe.fromJson(data as Map<String, dynamic>),
    );
  }
}
