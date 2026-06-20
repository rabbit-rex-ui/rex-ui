import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/auth/data/dto/login_dtos.dart';
import 'package:rabbit_pdv/features/auth/domain/auth_session.dart';

abstract interface class AuthRepository {
  Future<Result<AuthSession, Failure>> login(LoginRequest request);
  Future<Result<void, Failure>> logout();
  Future<Result<void, Failure>> trocarSenha(TrocarSenhaRequest request);
}
