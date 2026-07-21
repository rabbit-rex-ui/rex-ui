import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rabbit_pdv/core/security/terminal_context_store.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/auth/presentation/login_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _controller = Modular.get<LoginController>();
  final _loginCodeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _loginCodeFocus = FocusNode();
  final _passwordFocus = FocusNode();

  /// Otimista até o storage responder — evita piscar o aviso no primeiro frame.
  bool _terminalAtivado = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loginCodeFocus.requestFocus(),
    );
    _carregarContextoTerminal();
  }

  @override
  void dispose() {
    _passwordCtrl.clear(); // não deixa a senha residual em memória
    _loginCodeCtrl.dispose();
    _passwordCtrl.dispose();
    _loginCodeFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Lê a identidade do terminal do secure storage. Sem contexto salvo, o
  /// terminal não foi provisionado (gate de ativação).
  Future<void> _carregarContextoTerminal() async {
    final store = Modular.get<TerminalContextStore>();
    await store.carregar();
    if (!mounted) return;
    setState(() => _terminalAtivado = store.ativado);
  }

  Future<void> _submit() async {
    final ok = await _controller.submit(
      loginCode: _loginCodeCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted || !ok) return;
    _passwordCtrl.clear(); // não mantém a senha em memória após o sucesso
    Modular.to.navigate(
      _controller.passwordMustChange ? '/trocar-senha/' : '/pdv/',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _card(colors),
          ),
        ),
      ),
    );
  }

  Widget _card(AppColors colors) {
    final loading = _controller.loading;
    final error = _controller.errorMessage;

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
          Center(child: _brandMark(colors)),
          const SizedBox(height: 24),
          Text(
            'Entrar no caixa',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use seu código de login e senha.',
            style: TextStyle(fontSize: 12.5, color: colors.textMute),
          ),

          // Gate: terminal sem identidade registrada.
          if (!_terminalAtivado) ...[
            const SizedBox(height: 16),
            _avisoTerminalInativo(colors),
          ],

          const SizedBox(height: 20),

          _label('Código de login', colors),
          const SizedBox(height: 6),
          TextField(
            controller: _loginCodeCtrl,
            focusNode: _loginCodeFocus,
            enabled: !loading,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _controller.clearError(),
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono', // confira a família mono no pubspec
              fontSize: 15,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            decoration: _input(colors, hint: '10000001'),
          ),
          const SizedBox(height: 14),

          _label('Senha', colors),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            enabled: !loading,
            obscureText: _controller.obscurePassword,
            autofillHints: const [], // hardware compartilhado: sem sugestões
            textInputAction: TextInputAction.done,
            onChanged: (_) => _controller.clearError(),
            onSubmitted: (_) {
              if (!loading) _submit();
            },
            style: TextStyle(fontSize: 15, color: colors.text),
            decoration: _input(
              colors,
              hint: '••••••',
              suffix: IconButton(
                tooltip: _controller.obscurePassword
                    ? 'Mostrar senha'
                    : 'Ocultar senha',
                onPressed: _controller.toggleObscure,
                icon: Icon(
                  _controller.obscurePassword
                      ? LucideIcons.eye
                      : LucideIcons.eyeOff,
                  size: 18,
                  color: colors.textMute,
                ),
              ),
            ),
          ),

          if (error != null) ...[
            const SizedBox(height: 14),
            _errorBanner(error, colors),
          ],

          const SizedBox(height: 20),
          _submitButton(colors, loading),

          // Back-office do gestor: emitir token de provisionamento.
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => Modular.to.navigate('/provisionar-terminal/'),
              icon: Icon(
                LucideIcons.settings,
                size: 15,
                color: colors.textMute,
              ),
              label: Text(
                'Configurar terminal',
                style: TextStyle(fontSize: 12.5, color: colors.textMute),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Gate: terminal não provisionado ───
  Widget _avisoTerminalInativo(AppColors colors) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    decoration: BoxDecoration(
      color: colors.warn.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: colors.warn.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Icon(LucideIcons.triangleAlert, size: 16, color: colors.warn),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Terminal não ativado.',
            style: TextStyle(fontSize: 12, color: colors.warn),
          ),
        ),
        TextButton(
          onPressed: () => Modular.to.navigate('/ativar-terminal/'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Ativar',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.warn,
            ),
          ),
        ),
      ],
    ),
  );

  // ─── Marca (logo "R" + nome), montada por tokens (spec 04 · Brand lg) ───
  Widget _brandMark(AppColors colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.accent,
            borderRadius: BorderRadius.circular(34 / 4),
          ),
          child: Text(
            'R',
            style: TextStyle(
              color: colors.accentInk,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rabbit PDV',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.text,
                height: 1.2,
              ),
            ),
            Text(
              'Loja 01 · Caixa 03', // ajuste p/ a identificação real do terminal
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: colors.textMute,
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── CTA primário, montado por tokens (spec 04 · Btn primary/lg) ───
  Widget _submitButton(AppColors colors, bool loading) {
    return Semantics(
      button: true,
      enabled: !loading,
      label: 'Entrar',
      child: Material(
        color: colors.accent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: loading ? null : _submit,
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
                    'Entrar',
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

  Widget _errorBanner(String message, AppColors colors) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: colors.danger.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: colors.danger.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Icon(LucideIcons.circleAlert, size: 16, color: colors.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 12.5, color: colors.danger),
          ),
        ),
      ],
    ),
  );
}
