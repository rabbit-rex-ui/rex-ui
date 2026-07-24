import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/result/result.dart';

/// Fluxo de senha por token (rotas públicas — o token É a autorização).
/// Usado tanto no primeiro acesso (gestor recém-criado) quanto no reset.
abstract interface class RecuperacaoSenhaRepository {
  /// POST /auth/recuperar-senha → sempre 200 (anti-enumeração: não revela
  /// se a conta existe). O token chega pelo canal de recuperação.
  Future<Result<void, Failure>> solicitar(String loginCode);

  /// POST /auth/redefinir-senha → 204.
  Future<Result<void, Failure>> redefinir({
    required String token,
    required String novaSenha,
  });
}

class RecuperacaoSenhaRepositoryImpl implements RecuperacaoSenhaRepository {
  RecuperacaoSenhaRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<void, Failure>> solicitar(String loginCode) {
    return _api.send<void>(
      (dio) => dio.post<dynamic>(
        '/auth/recuperar-senha',
        data: {'loginCode': loginCode.trim()},
      ),
      decode: (_) {},
    );
  }

  @override
  Future<Result<void, Failure>> redefinir({
    required String token,
    required String novaSenha,
  }) {
    return _api.send<void>(
      (dio) => dio.post<dynamic>(
        '/auth/redefinir-senha',
        data: {'token': token.trim(), 'novaSenha': novaSenha},
      ),
      decode: (_) {},
    );
  }
}
