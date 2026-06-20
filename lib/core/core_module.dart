import 'package:flutter_modular/flutter_modular.dart';
import 'package:rabbit_pdv/core/auth/lock_controller.dart';
import 'package:rabbit_pdv/core/config/env.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';
import 'package:rabbit_pdv/data/repositories/produtos_repository_impl.dart';
import 'package:rabbit_pdv/data/repositories/produtos_repository_mock.dart';
import 'package:rabbit_pdv/domain/repositories/produtos_repository.dart';
import 'package:rabbit_pdv/features/auth/data/auth_repository_impl.dart';
import 'package:rabbit_pdv/features/auth/domain/auth_repository.dart';

class CoreModule extends Module {
  @override
  void exportedBinds(Injector i) {
    i.addSingleton<TokenStore>(InMemoryTokenStore.new);
    i.addSingleton<LockController>(() => LockController(i.get<TokenStore>()));

    i.addSingleton<ApiClient>(
      () => ApiClient(
        baseUrl: Env.apiBaseUrl,
        tenantId: Env.tenantId,
        terminalId: Env.terminalId,
        tokens: i.get<TokenStore>(),
        onSessionExpired: () => i.get<LockController>().lock(),
      ),
    );

    i.addSingleton<AuthRepository>(
      () => AuthRepositoryImpl(i.get<ApiClient>(), i.get<TokenStore>()),
    );

    i.addSingleton<ProdutosRepository>(
      () =>
          ProdutosRepositoryImpl(i.get<ApiClient>(), ProdutosRepositoryMock()),
    );
  }
}
