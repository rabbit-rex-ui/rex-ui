import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rabbit_pdv/core/auth/lock_controller.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/auth/presentation/login_controller.dart';

/// Overlay de bloqueio do terminal. Cobre o PDV sem desmontá-lo — o carrinho
/// em memória é preservado. Exige re-autenticação pra liberar.
class LockOverlay extends StatefulWidget {
  const LockOverlay({super.key});

  @override
  State<LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends State<LockOverlay> {
  final _login = Modular.get<LoginController>();
  final _lock = Modular.get<LockController>();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _codeFocus = FocusNode();
  final _passFocus = FocusNode();

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

  Future<void> _unlock() async {
    final ok = await _login.submit(
      loginCode: _codeCtrl.text,
      password: _passCtrl.text,
    );
    if (!mounted || !ok) return;
    _passCtrl.clear();
    _codeCtrl.clear();
    _lock.unlock(); // libera sem navegar — carrinho intacto
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Overlay local: provê o ancestral que Tooltip/IconButton exigem, SEM
    // criar um Navigator paralelo (que conflita com o showGeneralDialog do
    // modal de pagamento).
    return Overlay(
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
    final loading = _login.loading;
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
            'Identifique-se para voltar. O atendimento foi mantido.',
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
            onChanged: (_) => _login.clearError(),
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
            onChanged: (_) => _login.clearError(),
            onSubmitted: (_) {
              if (!loading) _unlock();
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
            _errorBanner(error, colors),
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
      label: 'Desbloquear',
      child: Material(
        color: colors.accent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: loading ? null : _unlock,
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
                    'Desbloquear',
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
