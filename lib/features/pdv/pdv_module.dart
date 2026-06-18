import 'package:flutter_modular/flutter_modular.dart';
import 'package:rabbit_pdv/core/config/env.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';
import 'package:rabbit_pdv/data/repositories/produtos_repository_impl.dart';
import 'package:rabbit_pdv/data/repositories/produtos_repository_mock.dart';
import 'package:rabbit_pdv/domain/repositories/produtos_repository.dart';
import 'package:rabbit_pdv/features/auth/data/auth_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/vendas_repository.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/caixa_session_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/sessions_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/ui_controllers.dart';
import 'package:rabbit_pdv/features/pdv/presentation/pages/pdv_page.dart';

class PdvModule extends Module {
  @override
  void binds(Injector i) {
    i.addSingleton<ProdutosRepository>(
      () =>
          ProdutosRepositoryImpl(i.get<ApiClient>(), ProdutosRepositoryMock()),
    );

    // Infra de rede.
    i.addSingleton<TokenStore>(InMemoryTokenStore.new);
    i.addSingleton<ApiClient>(
      () => ApiClient(
        baseUrl: Env.apiBaseUrl,
        tenantId: Env.tenantId,
        terminalId: Env.terminalId,
        tokens: i.get<TokenStore>(),
      ),
    );

    // Repositórios de backend.
    i.addSingleton<AuthRepository>(
      () => AuthRepositoryImpl(i.get<ApiClient>()),
    );
    i.addSingleton<CaixaRepository>(
      () => CaixaRepositoryImpl(i.get<ApiClient>()),
    );
    i.addSingleton<VendasRepository>(
      () => VendasRepositoryImpl(i.get<ApiClient>()),
    );

    // Sessão de runtime (login + caixa).
    i.addSingleton<CaixaSessionController>(
      () => CaixaSessionController(
        i.get<AuthRepository>(),
        i.get<CaixaRepository>(),
        i.get<TokenStore>(),
      ),
    );

    // Controllers de tela.
    i.addSingleton<SessionsController>(
      () => SessionsController(i.get<ProdutosRepository>()),
    );
    i.addSingleton<ViewController>(ViewController.new);
    i.addSingleton<ScannerController>(ScannerController.new);
  }

  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const PdvPage());
  }
}
