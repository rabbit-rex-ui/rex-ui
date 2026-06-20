import 'package:flutter_modular/flutter_modular.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';

class AuthGuard extends RouteGuard {
  @override
  Future<bool> canActivate(String path, ParallelRoute<dynamic> route) async {
    final hasToken = Modular.get<TokenStore>().accessToken != null;
    if (!hasToken) Modular.to.navigate('/');
    return hasToken;
  }
}
