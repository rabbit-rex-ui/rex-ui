import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/auth/presentation/trocar_senha_controller.dart';

class TrocarSenhaPage extends StatefulWidget {
  const TrocarSenhaPage({super.key});

  @override
  State<TrocarSenhaPage> createState() => _TrocarSenhaPageState();
}

class _TrocarSenhaPageState extends State<TrocarSenhaPage> {
  final _controller = Modular.get<TrocarSenhaController>();
  final _atualCtrl = TextEditingController();
  final _novaCtrl = TextEditingController();
  final _confirmaCtrl = TextEditingController();
  final _atualFocus = FocusNode();
  final _novaFocus = FocusNode();
  final _confirmaFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _atualFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    // Segurança: zera os campos sensíveis ao sair da tela.
    _atualCtrl.clear();
    _novaCtrl.clear();
    _confirmaCtrl.clear();
    _atualCtrl.dispose();
    _novaCtrl.dispose();
    _confirmaCtrl.dispose();
    _atualFocus.dispose();
    _novaFocus.dispose();
    _confirmaFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final outcome = await _controller.submit(
      senhaAtual: _atualCtrl.text,
      novaSenha: _novaCtrl.text,
      confirmacao: _confirmaCtrl.text,
    );
    if (!mounted) return;
    switch (outcome) {
      case TrocaSenhaOutcome.sucesso:
        _atualCtrl.clear();
        _novaCtrl.clear();
        _confirmaCtrl.clear();
        Modular.to.navigate('/pdv/');
      case TrocaSenhaOutcome.sessaoExpirada:
        Modular.to.navigate('/'); // volta pro login
      case TrocaSenhaOutcome.falha:
        break; // mensagem já está em controller.errorMessage
    }
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
            'Trocar senha',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Defina uma nova senha para continuar.',
            style: TextStyle(fontSize: 12.5, color: colors.textMute),
          ),
          const SizedBox(height: 20),

          _label('Senha atual', colors),
          const SizedBox(height: 6),
          TextField(
            controller: _atualCtrl,
            focusNode: _atualFocus,
            enabled: !loading,
            obscureText: _controller.obscureAtual,
            autofillHints: const [],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _controller.clearError(),
            onSubmitted: (_) => _novaFocus.requestFocus(),
            style: TextStyle(fontSize: 15, color: colors.text),
            decoration: _input(
              colors,
              hint: '••••••',
              suffix: _eyeToggle(
                colors,
                obscured: _controller.obscureAtual,
                onTap: _controller.toggleObscureAtual,
              ),
            ),
          ),
          const SizedBox(height: 14),

          _label('Nova senha', colors),
          const SizedBox(height: 6),
          TextField(
            controller: _novaCtrl,
            focusNode: _novaFocus,
            enabled: !loading,
            obscureText: _controller.obscureNova,
            autofillHints: const [],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _controller.clearError(),
            onSubmitted: (_) => _confirmaFocus.requestFocus(),
            style: TextStyle(fontSize: 15, color: colors.text),
            decoration: _input(
              colors,
              hint: '••••••',
              suffix: _eyeToggle(
                colors,
                obscured: _controller.obscureNova,
                onTap: _controller.toggleObscureNova,
              ),
            ),
          ),
          const SizedBox(height: 14),

          _label('Confirmar nova senha', colors),
          const SizedBox(height: 6),
          TextField(
            controller: _confirmaCtrl,
            focusNode: _confirmaFocus,
            enabled: !loading,
            obscureText: _controller.obscureNova,
            autofillHints: const [],
            textInputAction: TextInputAction.done,
            onChanged: (_) => _controller.clearError(),
            onSubmitted: (_) {
              if (!loading) _submit();
            },
            style: TextStyle(fontSize: 15, color: colors.text),
            decoration: _input(colors, hint: '••••••'),
          ),

          if (error != null) ...[
            const SizedBox(height: 14),
            _errorBanner(error, colors),
          ],

          const SizedBox(height: 20),
          _submitButton(colors, loading),
        ],
      ),
    );
  }

  Widget _eyeToggle(
    AppColors colors, {
    required bool obscured,
    required VoidCallback onTap,
  }) => IconButton(
    tooltip: obscured ? 'Mostrar senha' : 'Ocultar senha',
    onPressed: onTap,
    icon: Icon(
      obscured ? LucideIcons.eye : LucideIcons.eyeOff,
      size: 18,
      color: colors.textMute,
    ),
  );

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
              'Loja 01 · Caixa 03',
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

  Widget _submitButton(AppColors colors, bool loading) {
    return Semantics(
      button: true,
      enabled: !loading,
      label: 'Salvar nova senha',
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
                    'Salvar nova senha',
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
