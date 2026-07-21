import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/provisionamento/presentation/ativar_terminal_controller.dart';

/// Parte 2: ativação do terminal. NÃO há login aqui — quem autoriza é o
/// token de enrollment emitido no back-office.
class AtivarTerminalPage extends StatefulWidget {
  const AtivarTerminalPage({super.key});

  @override
  State<AtivarTerminalPage> createState() => _AtivarTerminalPageState();
}

class _AtivarTerminalPageState extends State<AtivarTerminalPage> {
  final _ctrl = Modular.get<AtivarTerminalController>();
  final _tokenCtrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _ativar() async {
    final ok = await _ctrl.ativar(_tokenCtrl.text);
    if (!mounted || !ok) return;
    _tokenCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _ctrl.sucesso ? _cardSucesso(c) : _cardForm(c),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardForm(AppColors c) {
    final loading = _ctrl.loading;
    return _card(c, [
      Row(
        children: [
          Icon(LucideIcons.monitorCog, size: 22, color: c.accent),
          const SizedBox(width: 10),
          Text(
            'Ativar terminal',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'Este terminal ainda não foi provisionado. Cole o token gerado no '
        'back-office para ativá-lo.',
        style: TextStyle(fontSize: 12.5, color: c.textMute, height: 1.4),
      ),
      const SizedBox(height: 20),
      Text(
        'TOKEN DE ATIVAÇÃO',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: c.textMute,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: _tokenCtrl,
        focusNode: _focus,
        enabled: !loading,
        maxLines: 3,
        minLines: 2,
        onChanged: (_) => _ctrl.clearError(),
        style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Cole aqui o token do QR code',
          hintStyle: TextStyle(color: c.textDim),
          filled: true,
          fillColor: c.surface2,
          contentPadding: const EdgeInsets.all(14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.accent, width: 1.5),
          ),
        ),
      ),
      if (_ctrl.erro != null) ...[
        const SizedBox(height: 14),
        _banner(_ctrl.erro!, c),
      ],
      const SizedBox(height: 20),
      _botao(c, 'Ativar terminal', loading, _ativar),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: () => Modular.to.navigate('/'),
          child: Text(
            'Voltar ao login',
            style: TextStyle(fontSize: 12.5, color: c.textMute),
          ),
        ),
      ),
    ]);
  }

  Widget _cardSucesso(AppColors c) {
    final ctx = _ctrl.contexto;
    return _card(c, [
      Row(
        children: [
          Icon(LucideIcons.circleCheck, size: 22, color: c.success),
          const SizedBox(width: 10),
          Text(
            'Terminal ativado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'A identidade deste terminal foi registrada. Os operadores já '
        'podem fazer login.',
        style: TextStyle(fontSize: 12.5, color: c.textMute, height: 1.4),
      ),
      if (ctx != null) ...[
        const SizedBox(height: 18),
        _linha(c, 'Terminal', ctx.deviceId),
        _linha(c, 'Caixa', ctx.cashRegisterId),
      ],
      const SizedBox(height: 22),
      _botao(c, 'Ir para o login', false, () => Modular.to.navigate('/')),
    ]);
  }

  Widget _linha(AppColors c, String rotulo, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            rotulo,
            style: TextStyle(fontSize: 11.5, color: c.textMute),
          ),
        ),
        Expanded(
          child: Text(
            valor,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11.5,
              color: c.textMute,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _card(AppColors c, List<Widget> children) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.border),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _botao(AppColors c, String txt, bool loading, VoidCallback? onTap) =>
      Material(
        color: c.accent,
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
                      valueColor: AlwaysStoppedAnimation(c.accentInk),
                    ),
                  )
                : Text(
                    txt,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.accentInk,
                    ),
                  ),
          ),
        ),
      );

  Widget _banner(String msg, AppColors c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: c.danger.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: c.danger.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Icon(LucideIcons.circleAlert, size: 16, color: c.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg, style: TextStyle(fontSize: 12.5, color: c.danger)),
        ),
      ],
    ),
  );
}
