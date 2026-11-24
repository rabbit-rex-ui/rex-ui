import 'package:flutter_modular/flutter_modular.dart';
import 'package:rabbit_pdv/core/auth/lock_controller.dart';
import 'package:rabbit_pdv/core/core_module.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';
import 'package:rabbit_pdv/core/security/terminal_context_store.dart';
import 'package:rabbit_pdv/domain/repositories/produtos_repository.dart';
import 'package:rabbit_pdv/features/fiscal/data/arquivo_fiscal_local.dart';
import 'package:rabbit_pdv/features/fiscal/data/nota_fiscal_repository.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/configuracao_impressao.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/impressao_fiscal.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/impressora_raw.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/xml_cupom_local.dart';
import 'package:rabbit_pdv/features/fiscal/presentation/notas_atencao_controller.dart';
import 'package:rabbit_pdv/features/pdv/data/anulacao_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/assumir_caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/vendas_repository.dart';
import 'package:rabbit_pdv/features/pdv/guards/auth_guard.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/caixa_session_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/sessions_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/ui_controllers.dart';
import 'package:rabbit_pdv/features/pdv/presentation/pages/pdv_page.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/pedido_delivery_repository.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/controllers/payment_session_store.dart';
import 'package:rabbit_pdv/features/provisionamento/data/caixa_fisico_repository.dart';

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
      () => CaixaSessionController(
        i.get<CaixaRepository>(),
        i.get<TokenStore>(),
        i.get<TerminalContextStore>(),
        i.get<CaixaFisicoRepository>(),
      ),
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
    i.addSingleton<PedidoDeliveryRepository>(
      () => PedidoDeliveryRepositoryImpl(i.get<ApiClient>()),
    );
    i.addSingleton<NotaFiscalRepository>(
      () => NotaFiscalRepositoryImpl(i.get<ApiClient>()),
    );
    i.addSingleton<ArquivoFiscalLocal>(ArquivoFiscalLocalSistema.new);
    // Impressão fiscal (guia v2.3 §9).
    i.addSingleton<ImpressoraRaw>(ImpressoraRawWindows.new);
    i.addSingleton<XmlCupomLocal>(() => XmlCupomLocalArquivos());
    i.addSingleton<ConfiguracaoImpressaoStore>(ConfiguracaoImpressaoPrefs.new);
    i.addSingleton<ImpressaoFiscal>(
      () => ImpressaoFiscalImpl(
        repo: i.get<NotaFiscalRepository>(),
        xmlLocal: i.get<XmlCupomLocal>(),
        impressora: i.get<ImpressoraRaw>(),
        configuracao: i.get<ConfiguracaoImpressaoStore>(),
        arquivos: i.get<ArquivoFiscalLocal>(),
      ),
    );
    i.addSingleton<NotasAtencaoController>(
      () => NotasAtencaoController(
        i.get<NotaFiscalRepository>(),
        pausado: () => i.get<LockController>().locked,
      ),
    );
  }

  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const PdvPage(), guards: [AuthGuard()]);
  }
}
