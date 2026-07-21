import 'package:flutter_modular/flutter_modular.dart';
import 'package:rabbit_pdv/core/auth/lock_controller.dart';
import 'package:rabbit_pdv/core/auth/trusted_device_store.dart';
import 'package:rabbit_pdv/core/config/env.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';
import 'package:rabbit_pdv/data/repositories/produtos_repository_impl.dart';
import 'package:rabbit_pdv/data/repositories/produtos_repository_mock.dart';
import 'package:rabbit_pdv/domain/repositories/produtos_repository.dart';
import 'package:rabbit_pdv/features/auth/data/auth_repository_impl.dart';
import 'package:rabbit_pdv/features/auth/domain/auth_repository.dart';
import 'package:rabbit_pdv/core/security/dev_terminal_key_store.dart';
import 'package:rabbit_pdv/core/security/terminal_context_store.dart';
import 'package:rabbit_pdv/core/security/terminal_key_store.dart';
import 'package:rabbit_pdv/features/provisionamento/data/caixa_fisico_repository.dart';

class CoreModule extends Module {
  @override
  void exportedBinds(Injector i) {
    i.addSingleton<TokenStore>(InMemoryTokenStore.new);
    i.addSingleton<LockController>(() => LockController(i.get<TokenStore>()));
    i.addSingleton<TrustedDeviceStore>(() => TrustedDeviceStore());

    i.addSingleton<TerminalContextStore>(() => TerminalContextStore());
    // ⚠️ Trocar por CngTerminalKeyStore antes de release.
    i.addSingleton<TerminalKeyStore>(() => DevTerminalKeyStore());

    i.addSingleton<CaixaFisicoRepository>(
      () => CaixaFisicoRepositoryImpl(i.get<ApiClient>()),
    );

    i.addSingleton<ApiClient>(
      () => ApiClient(
        baseUrl: Env.apiBaseUrl,
        tokens: i.get<TokenStore>(),
        trustedDevices: i.get<TrustedDeviceStore>(),
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
