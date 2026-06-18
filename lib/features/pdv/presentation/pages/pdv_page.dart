import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/domain/enums/cliente_tipo.dart';
import 'package:rabbit_pdv/domain/repositories/produtos_repository.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/pages/payment_modal.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/caixa_session_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/sessions_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/ui_controllers.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/items/items_panel.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/scanner/scanner.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/side_panel/action_row.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/side_panel/side_panel.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/tabs/tabs_bar.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/topbar/topbar.dart';
import 'package:rabbit_pdv/features/pdv/data/mappers/venda_request_mapper.dart';
import 'package:rabbit_pdv/features/pdv/data/vendas_repository.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/finalizar_venda.dart';

/// Tela completa do PDV. Layout 1280×800 conforme `docs/03-layout.md`.
///
/// Responsabilidades:
/// - Compor as regiões (Topbar / TabsBar / LeftPanel / RightPanel).
/// - Capturar atalhos globais de teclado (F-keys, Ctrl+N etc.).
/// - Manter o foco no scanner como prioridade.
class PdvPage extends StatefulWidget {
  const PdvPage({super.key});

  @override
  State<PdvPage> createState() => _PdvPageState();
}

class _PdvPageState extends State<PdvPage> {
  late final CaixaSessionController caixaSession;
  late final VendasRepository vendasRepo;
  late final SessionsController sessions;
  late final ViewController view;
  late final ScannerController scanner;
  late final ClockController clock;
  late final ThemeController theme;
  late final ProdutosRepository repo;

  final _scannerFocus = FocusNode(debugLabel: 'scanner');

  @override
  void initState() {
    super.initState();
    sessions = Modular.get<SessionsController>();
    view = Modular.get<ViewController>();
    scanner = Modular.get<ScannerController>();
    clock = Modular.get<ClockController>();
    theme = Modular.get<ThemeController>();
    repo = Modular.get<ProdutosRepository>();
    caixaSession = Modular.get<CaixaSessionController>();
    vendasRepo = Modular.get<VendasRepository>();

    // Dispara login + abertura de caixa (auto-bootstrap do controller).
    Modular.get<CaixaSessionController>();

    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusScanner());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _scannerFocus.dispose();
    super.dispose();
  }

  void _focusScanner() {
    if (mounted) _scannerFocus.requestFocus();
  }

  /// Retorna `true` quando consome o evento (impede propagação a widgets
  /// focados), `false` quando ignora (evento segue normalmente).
  ///
  /// Quando há um modal/dialog em cima da página (rota não é a corrente),
  /// não interceptamos nada — o modal cuida dos próprios atalhos.
  bool _onKey(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent) return false;

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;

    final key = event.logicalKey;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    if (key == LogicalKeyboardKey.f1) {
      _focusScanner();
      return true;
    }
    if (key == LogicalKeyboardKey.f5) {
      _finalizar();
      return true;
    }
    if (key == LogicalKeyboardKey.f9) {
      sessions.pausarAtivo();
      return true;
    }
    if (isCtrl && key == LogicalKeyboardKey.keyN) {
      sessions.novoAtendimento();
      _focusScanner();
      return true;
    }

    return false;
  }

  Future<void> _finalizar() async {
    final ativo = sessions.active;
    if (ativo == null || ativo.estaVazio) return;

    // Guard: sem caixa/login pronto, não dá pra vender.
    if (!caixaSession.pronto || caixaSession.cashierId == null) {
      _toast(
        'Caixa não está pronto. ${caixaSession.erro ?? "Aguarde o login."}',
      );
      return;
    }

    sessions.marcarProntoParaPagamento();
    final alvo = sessions.active!;

    final pagamentos = await showPaymentModal(context, atendimento: alvo);
    if (!mounted) return;

    if (pagamentos == null) {
      sessions.retomarDigitacao();
      _focusScanner();
      return;
    }

    final cliente = alvo.cliente;
    final identificado = cliente.tipo != ClienteTipo.anonimo;

    final req = montarVendaRequest(
      terminalId: caixaSession.terminalId,
      cashierId: caixaSession.cashierId!,
      defaultWarehouseId: caixaSession.defaultWarehouseId,
      itens: alvo.itens,
      pagamentos: pagamentos,
      // Anônimo → tudo null. Só identificado vai pra nota.
      customerId: cliente.id, // já é null se não cadastrado
      customerDoc: identificado ? cliente.doc : null,
      customerName: identificado ? cliente.nome : null,
      headerDiscount: alvo.desconto, // ⚠️ último a confirmar (ver abaixo)
    );

    final outcome = await finalizarVenda(vendasRepo, req);
    if (!mounted) return;

    switch (outcome) {
      case VendaConcluida(:final venda):
        sessions.finalizarVenda(pagamentos); // limpa a aba (mock local)
        _focusScanner();
        _toast(
          'Venda #${venda.saleNumber} · '
          'Total R\$ ${venda.total.toStringAsFixed(2)}'
          '${venda.change > 0 ? " · Troco R\$ ${venda.change.toStringAsFixed(2)}" : ""}',
        );
      case CaixaBloqueado(:final mensagem):
        // §6.3 — sangria de supervisor (próximo passo). Por ora, avisa.
        sessions.retomarDigitacao();
        _toast('Caixa bloqueado: $mensagem');
      case SessaoExpirada():
        sessions.retomarDigitacao();
        _toast('Sessão expirada. Refaça o login.');
      case VendaRejeitada(:final failure):
        sessions.retomarDigitacao();
        _toast('Venda recusada: ${failure.message}');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Topbar(clock: clock, theme: theme),
            TabsBar(sessions: sessions),
            Expanded(
              child: ListenableBuilder(
                listenable: sessions,
                builder: (_, __) {
                  final ativo = sessions.active;
                  if (ativo == null) return const SizedBox.shrink();
                  return Row(
                    children: [
                      // ---- LEFT PANEL ----
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              Scanner(
                                controller: scanner,
                                sessions: sessions,
                                repo: repo,
                                focusNode: _scannerFocus,
                                onAfterSubmit: _focusScanner,
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: ItemsPanel(
                                  session: ativo,
                                  sessions: sessions,
                                  view: view,
                                  repo: repo,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ActionRow(
                                onDesconto: () {
                                  // TODO modal de desconto
                                },
                                onPausar: sessions.pausarAtivo,
                                onDevolucao: () {},
                                onHistorico: () {},
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ---- RIGHT PANEL ----
                      SidePanel(
                        session: ativo,
                        onTapCliente: () {
                          // TODO modal cliente
                        },
                        onFinalizar: _finalizar,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
