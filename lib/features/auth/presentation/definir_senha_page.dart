import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/auth/presentation/definir_senha_controller.dart';

/// Definição de senha por token. Primeiro acesso (gestor recém-criado) e reset.
/// O token chega pelo canal de recuperação; enquanto o e-mail é stub, o gestor
/// o recebe fora de banda e cola aqui.
class DefinirSenhaPage extends StatefulWidget {
  const DefinirSenhaPage({super.key});

  @override
  State<DefinirSenhaPage> createState() => _DefinirSenhaPageState();
}

class _DefinirSenhaPageState extends State<DefinirSenhaPage> {
  final _ctrl = Modular.get<DefinirSenhaController>();

  final _tokenCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmaCtrl = TextEditingController();

  @override
  void dispose() {
    _senhaCtrl.clear();
    _confirmaCtrl.clear();
    _tokenCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmaCtrl.dispose();
    super.dispose();
  }

  Future<void> _definir() => _ctrl.definir(
    token: _tokenCtrl.text,
    senha: _senhaCtrl.text,
    confirmacao: _confirmaCtrl.text,
  );

  Future<void> _solicitar() async {
    final codeCtrl = TextEditingController();
    final colors = context.colors;

    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Solicitar token',
          style: TextStyle(fontSize: 17, color: colors.text),
        ),
        content: TextField(
          controller: codeCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 15),
          decoration: _input(colors, hint: 'Código de login'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: colors.textMute)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(codeCtrl.text),
            child: Text(
              'Enviar',
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    final valor = code;
    codeCtrl.dispose();
    if (valor == null || !mounted) return;
    await _ctrl.solicitarToken(valor);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'Definir senha',
          style: TextStyle(color: colors.text, fontSize: 16),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: colors.text),
          onPressed: () => Modular.to.navigate('/'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _ctrl.concluido ? _cardSucesso(colors) : _cardForm(colors),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardForm(AppColors colors) {
    final loading = _ctrl.loading;
    return _card(colors, [
      Row(
        children: [
          Icon(LucideIcons.keyRound, size: 20, color: colors.accent),
          const SizedBox(width: 10),
          Text(
            'Definir senha',
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
        'Cole o token recebido e escolha sua senha de acesso.',
        style: TextStyle(fontSize: 12.5, color: colors.textMute, height: 1.4),
      ),
      const SizedBox(height: 20),

      _label('Token', colors),
      const SizedBox(height: 6),
      TextField(
        controller: _tokenCtrl,
        enabled: !loading,
        minLines: 2,
        maxLines: 3,
        onChanged: (_) => _ctrl.clearError(),
        style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13),
        decoration: _input(colors, hint: 'Cole aqui o token recebido'),
      ),
      const SizedBox(height: 14),

      _label('Nova senha', colors),
      const SizedBox(height: 6),
      TextField(
        controller: _senhaCtrl,
        enabled: !loading,
        obscureText: _ctrl.obscura,
        autofillHints: const [],
        onChanged: (_) => _ctrl.clearError(),
        style: TextStyle(fontSize: 15, color: colors.text),
        decoration: _input(
          colors,
          hint: '••••••••',
          suffix: IconButton(
            tooltip: _ctrl.obscura ? 'Mostrar senha' : 'Ocultar senha',
            onPressed: _ctrl.toggleObscura,
            icon: Icon(
              _ctrl.obscura ? LucideIcons.eye : LucideIcons.eyeOff,
              size: 18,
              color: colors.textMute,
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),

      _label('Confirmar senha', colors),
      const SizedBox(height: 6),
      TextField(
        controller: _confirmaCtrl,
        enabled: !loading,
        obscureText: _ctrl.obscura,
        autofillHints: const [],
        onChanged: (_) => _ctrl.clearError(),
        onSubmitted: (_) => loading ? null : _definir(),
        style: TextStyle(fontSize: 15, color: colors.text),
        decoration: _input(colors, hint: '••••••••'),
      ),

      if (_ctrl.erro != null) ...[
        const SizedBox(height: 14),
        _banner(_ctrl.erro!, colors.danger),
      ],
      if (_ctrl.avisoSolicitacao != null) ...[
        const SizedBox(height: 14),
        _banner(_ctrl.avisoSolicitacao!, colors.accent),
      ],

      const SizedBox(height: 20),
      _botao(colors, 'Definir senha', loading, _definir),
      const SizedBox(height: 8),
      Center(
        child: TextButton(
          onPressed: loading ? null : _solicitar,
          child: Text(
            'Não tenho um token',
            style: TextStyle(fontSize: 12.5, color: colors.textMute),
          ),
        ),
      ),
    ]);
  }

  Widget _cardSucesso(AppColors colors) => _card(colors, [
    Row(
      children: [
        Icon(LucideIcons.circleCheck, size: 20, color: colors.success),
        const SizedBox(width: 10),
        Text(
          'Senha definida',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
      ],
    ),
    const SizedBox(height: 6),
    Text(
      'Você já pode entrar com seu código de login e a nova senha.',
      style: TextStyle(fontSize: 12.5, color: colors.textMute, height: 1.4),
    ),
    const SizedBox(height: 22),
    _botao(colors, 'Ir para o login', false, () => Modular.to.navigate('/')),
  ]);

  // ---- helpers de UI ----

  Widget _card(AppColors colors, List<Widget> children) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: colors.border),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _label(String t, AppColors colors) => Text(
    t,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: colors.textMute,
    ),
  );

  Widget _botao(
    AppColors colors,
    String txt,
    bool loading,
    VoidCallback? onTap,
  ) => Material(
    color: colors.accent,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: loading ? null : onTap,
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
                txt,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.accentInk,
                ),
              ),
      ),
    ),
  );

  Widget _banner(String msg, Color cor) => Container(
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
          child: Text(msg, style: TextStyle(fontSize: 12.5, color: cor)),
        ),
      ],
    ),
  );
}

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
