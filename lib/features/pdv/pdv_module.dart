import 'package:flutter_modular/flutter_modular.dart';
import 'package:rabbit_pdv/core/core_module.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';
import 'package:rabbit_pdv/domain/repositories/produtos_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/anulacao_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/assumir_caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/vendas_repository.dart';
import 'package:rabbit_pdv/features/pdv/guards/auth_guard.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/caixa_session_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/sessions_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/ui_controllers.dart';
import 'package:rabbit_pdv/features/pdv/presentation/pages/pdv_page.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/controllers/payment_session_store.dart';

class PdvModule extends Module {
  @override
  List<Module> get imports => [CoreModule()];

  @override
  void binds(Injector i) {
    i.addSingleton<CaixaRepository>(
      () => CaixaRepositoryImpl(i.get<ApiClient>()),
    );
    i.addSingleton<VendasRepository>(
      () => VendasRepositoryImpl(i.get<ApiClient>()),
    );
    i.addSingleton<AnulacaoRepository>(
      () => AnulacaoRepositoryImpl(i.get<ApiClient>()),
    );
    i.addSingleton<CaixaSessionController>(
      () =>
          CaixaSessionController(i.get<CaixaRepository>(), i.get<TokenStore>()),
    );
    i.addSingleton<SessionsController>(
      () => SessionsController(i.get<ProdutosRepository>()),
    );
    i.addSingleton<ViewController>(ViewController.new);
    i.addSingleton<ScannerController>(ScannerController.new);
    i.addSingleton<PaymentSessionStore>(
      () => PaymentSessionStore(i.get<SessionsController>()),
    );
    i.addSingleton<AssumirCaixaRepository>(
      () => AssumirCaixaRepositoryImpl(i.get<ApiClient>()),
    );
  }

  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const PdvPage(), guards: [AuthGuard()]);
  }
}
