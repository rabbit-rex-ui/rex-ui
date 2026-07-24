import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rabbit_pdv/core/auth/lock_controller.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/auth/domain/sessao_atual.dart';
import 'package:rabbit_pdv/features/auth/presentation/login_controller.dart';
import 'package:rabbit_pdv/features/pdv/data/assumir_caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/assumir_caixa_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/caixa_session_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/sessions_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/caixa/assumir_caixa_dialog.dart';

/// Overlay de bloqueio do terminal. Cobre o PDV sem desmontá-lo — o carrinho
/// em memória é preservado. Exige re-autenticação pra liberar.
///
/// Fluxo unificado (um botão): a pessoa se identifica e o sistema roteia por
/// `currentCustodianId` (autoritativo, vindo do ledger de custódia):
/// - **mesmo custodiante** → desbloqueia, mantém o atendimento;
/// - **outro operador com `cx.takeover`** → fluxo de posse (ledger, contagem);
/// - **outro operador sem `cx.takeover`** → recusa, descarta o login e mantém
///   bloqueado (não pode ficar sessão ativa de quem não opera aqui).
class LockOverlay extends StatefulWidget {
  const LockOverlay({super.key});

  @override
  State<LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends State<LockOverlay> {
  final _login = Modular.get<LoginController>();
  final _lock = Modular.get<LockController>();
  final _tokens = Modular.get<TokenStore>();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _codeFocus = FocusNode();
  final _passFocus = FocusNode();

  // Chave do Overlay interno — é o ancestral usado pra abrir o diálogo de posse
  // (este overlay NÃO tem Navigator, então showGeneralDialog não serve aqui).
  final _overlayKey = GlobalKey<OverlayState>();

  /// Aviso de roteamento (custódia), distinto do erro de credencial.
  String? _avisoLocal;

  /// Trava a UI durante o roteamento pós-login.
  bool _roteando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _codeFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _passCtrl.clear();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _codeFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  /// Ponto de entrada único: autentica UMA vez e roteia por custódia.
  Future<void> _continuar() async {
    setState(() {
      _avisoLocal = null;
      _roteando = true;
    });

    final ok = await _login.submit(
      loginCode: _codeCtrl.text,
      password: _passCtrl.text,
    );
    if (!mounted) return;
    if (!ok) {
      // Credencial inválida: erro já exposto por _login.errorMessage.
      setState(() => _roteando = false);
      return;
    }

    final session = _login.session;
    final caixa = Modular.get<CaixaSessionController>();
    final custodiante = caixa.caixaSessao?.custodianEfetivo;
    final quemLogou = session?.employeeId;

    // (1) Mesmo custodiante → desbloqueio simples, mantém o atendimento.
    if (quemLogou != null && custodiante != null && quemLogou == custodiante) {
      _limparCampos();
      await _rehidratarSessao();
      if (!mounted) return;
      _lock.unlock();
      return;
    }

    // (2)/(3) Outro operador: só prossegue com cx.takeover.
    final podeAssumir = session?.hasPermission('cx.takeover') ?? false;
    if (!podeAssumir) {
      await _descartarLogin(
        'Este caixa está sob responsabilidade de outro operador. '
        'Solicite um supervisor para assumir o caixa.',
      );
      return;
    }

    // (2) Outro operador COM cx.takeover → fluxo formal de posse.
    setState(() => _roteando = false);
    await _assumirJaAutenticado();
  }

  Future<void> _assumirJaAutenticado() async {
    final overlay = _overlayKey.currentState;
    if (overlay == null) return;

    final sessions = Modular.get<SessionsController>();
    final caixaSession = Modular.get<CaixaSessionController>();
    final ativo = sessions.active;
    final temItens = ativo != null && !ativo.estaVazio;

    final controller = AssumirCaixaController(
      assumirRepo: Modular.get<AssumirCaixaRepository>(),
      caixaRepo: Modular.get<CaixaRepository>(),
      login: _login,
      cashSessionId: caixaSession.caixaSessao?.id, // preferido (em memória)
      cashRegisterId: caixaSession.cashRegisterId, // fallback p/ o GET
      jaAutenticado: true, // o overlay já autenticou B — não relogar
    );

    final outcome = await showAssumirCaixaInOverlay(
      overlay,
      controller: controller,
      cartRef: temItens ? ativo.id : null,
      cartItemCount: temItens ? ativo.numItens : 0,
      cartTotal: temItens ? ativo.total : 0,
    );

    if (!mounted) return;

    // Cancelou ou falhou: B está autenticado mas NÃO é o custodiante — não
    // pode seguir operando. Descarta o login e mantém bloqueado.
    if (outcome == null) {
      await _descartarLogin('Posse não concluída. O terminal segue bloqueado.');
      return;
    }

    // B optou por começar do zero → descarta o atendimento de A.
    if (!outcome.cartPreserved && ativo != null) {
      sessions.fechar(ativo.id);
    }

    _limparCampos();
    await _rehidratarSessao();
    if (!mounted) return;
    _lock.unlock(); // libera sem navegar; token de B já vale em tudo
  }

  /// Descarta credenciais de quem autenticou mas não pode operar aqui, e
  /// mantém o terminal bloqueado com a mensagem informada.
  Future<void> _descartarLogin(String aviso) async {
    await _tokens.clear();
    _login.reset();
    if (!mounted) return;
    _passCtrl.clear();
    setState(() {
      _roteando = false;
      _avisoLocal = aviso;
    });
  }

  void _limparCampos() {
    _codeCtrl.clear();
    _passCtrl.clear();
  }

  void _aoDigitar() {
    _login.clearError();
    if (_avisoLocal != null) setState(() => _avisoLocal = null);
  }

  /// Rehidrata o contexto após troca de operador: identidade da venda
  /// (claims do novo token) e dados de exibição (/auth/me).
  Future<void> _rehidratarSessao() async {
    await Modular.get<CaixaSessionController>().bootstrap();
    await Modular.get<SessaoAtual>().carregar();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Overlay local: provê o ancestral que Tooltip/IconButton exigem, SEM
    // criar um Navigator paralelo (que conflita com o showGeneralDialog do
    // modal de pagamento). O diálogo de posse também entra POR AQUI.
    return Overlay(
      key: _overlayKey,
      initialEntries: [
        OverlayEntry(
          builder: (context) => Material(
            color: colors.bg, // opaco: esconde e bloqueia o PDV atrás
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: AnimatedBuilder(
                  animation: _login,
                  builder: (context, _) => _card(colors),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(AppColors colors) {
    final loading = _login.loading || _roteando;
    final error = _login.errorMessage;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.lock, size: 20, color: colors.accent),
              const SizedBox(width: 10),
              Text(
                'Terminal bloqueado',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Identifique-se para continuar. O atendimento foi mantido.',
            style: TextStyle(fontSize: 12.5, color: colors.textMute),
          ),
          const SizedBox(height: 20),

          _label('Código de login', colors),
          const SizedBox(height: 6),
          TextField(
            controller: _codeCtrl,
            focusNode: _codeFocus,
            enabled: !loading,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _aoDigitar(),
            onSubmitted: (_) => _passFocus.requestFocus(),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 15,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            decoration: _input(colors, hint: '10000001'),
          ),
          const SizedBox(height: 14),

          _label('Senha', colors),
          const SizedBox(height: 6),
          TextField(
            controller: _passCtrl,
            focusNode: _passFocus,
            enabled: !loading,
            obscureText: _login.obscurePassword,
            autofillHints: const [],
            textInputAction: TextInputAction.done,
            onChanged: (_) => _aoDigitar(),
            onSubmitted: (_) {
              if (!loading) _continuar();
            },
            style: TextStyle(fontSize: 15, color: colors.text),
            decoration: _input(
              colors,
              hint: '••••••',
              suffix: IconButton(
                tooltip: _login.obscurePassword
                    ? 'Mostrar senha'
                    : 'Ocultar senha',
                onPressed: _login.toggleObscure,
                icon: Icon(
                  _login.obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 18,
                  color: colors.textMute,
                ),
              ),
            ),
          ),

          if (error != null) ...[
            const SizedBox(height: 14),
            _banner(error, colors.danger),
          ],
          if (_avisoLocal != null) ...[
            const SizedBox(height: 14),
            _banner(_avisoLocal!, colors.warn),
          ],

          const SizedBox(height: 20),
          _button(colors, loading),
        ],
      ),
    );
  }

  Widget _button(AppColors colors, bool loading) {
    return Semantics(
      button: true,
      enabled: !loading,
      label: 'Continuar',
      child: Material(
        color: colors.accent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: loading ? null : _continuar,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            child: loading
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(colors.accentInk),
                    ),
                  )
                : Text(
                    'Continuar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.accentInk,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, AppColors colors) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: colors.textMute,
    ),
  );

  InputDecoration _input(
    AppColors colors, {
    required String hint,
    Widget? suffix,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: colors.textDim),
    suffixIcon: suffix,
    filled: true,
    fillColor: colors.surface2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.accent, width: 1.5),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.borderSoft),
    ),
  );

  Widget _banner(String message, Color cor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: cor.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: cor.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Icon(LucideIcons.circleAlert, size: 16, color: cor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: TextStyle(fontSize: 12.5, color: cor)),
        ),
      ],
    ),
  );
}
