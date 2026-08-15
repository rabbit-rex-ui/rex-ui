import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/format/moeda_input_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/pdv/data/caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/movimento_caixa_dtos.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/caixa_session_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/sangria_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/dialogs/pdv_dialog_kit.dart';

/// Abre o diálogo de movimento de caixa (sangria ou reforço) e devolve a
/// resposta do servidor em 2xx; `null` se o operador cancelar.
///
/// Cria um [SangriaController] descartável (eventId UUIDv7 único). O CHAMADOR
/// deve reagir à resposta não-nula (ex.: atualizar o semáforo com
/// `resp.cashCeilingStatus`). Em erro, o diálogo permanece aberto para nova
/// tentativa reusando o mesmo eventId; no step-up, os campos de supervisor são
/// revelados sem fechar o diálogo.
Future<MovimentoCaixaResponse?> showSangriaDialog(
  BuildContext context, {
  required CaixaRepository repo,
  required CaixaSessionController session,
  MovimentoTipo tipo = MovimentoTipo.withdrawal,
}) async {
  final sessionId = session.caixaSessao?.id;
  if (sessionId == null || sessionId.isEmpty) return null;

  final controller = SangriaController(repo, sessionId: sessionId, tipo: tipo);
  try {
    return await showGeneralDialog<MovimentoCaixaResponse>(
      context: context,
      barrierDismissible: false,
      barrierLabel: tipo == MovimentoTipo.withdrawal ? 'Sangria' : 'Reforço',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, _, _) =>
          _SangriaDialog(controller: controller, session: session),
      transitionBuilder: (_, anim, _, child) {
        final t = CurvedAnimation(parent: anim, curve: Curves.easeOut).value;
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.98 + 0.02 * t, child: child),
        );
      },
    );
  } finally {
    controller.dispose();
  }
}

class _SangriaDialog extends StatefulWidget {
  const _SangriaDialog({required this.controller, required this.session});

  final SangriaController controller;
  final CaixaSessionController session;

  @override
  State<_SangriaDialog> createState() => _SangriaDialogState();
}

class _SangriaDialogState extends State<_SangriaDialog> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  final _amountFocus = FocusNode();
  final _reasonFocus = FocusNode();
  final _loginFocus = FocusNode();
  final _pwdFocus = FocusNode();

  bool get _isSangria => widget.controller.tipo == MovimentoTipo.withdrawal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Resolve a config (COFRE) e a sugestão sem bloquear a abertura.
      widget.session.garantirCxConfig();
      await widget.controller.carregarSugestao();
      if (!mounted) return;
      _preencherSugestao();
      _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _pwdCtrl.clear(); // não deixa a senha residual em memória
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    _loginCtrl.dispose();
    _pwdCtrl.dispose();
    _amountFocus.dispose();
    _reasonFocus.dispose();
    _loginFocus.dispose();
    _pwdFocus.dispose();
    super.dispose();
  }

  /// Pré-preenche o campo de valor com a sugestão, se houver e o operador ainda
  /// não digitou nada.
  void _preencherSugestao() {
    final ctrl = widget.controller;
    if (ctrl.amount > 0 && _amountCtrl.text.isEmpty) {
      _aplicarValor(ctrl.amount);
    }
  }

  void _aplicarValor(double v) {
    widget.controller.setAmount(v);
    final texto = BrlFormatter.format(v);
    _amountCtrl.value = TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }

  List<MovimentoDestino> get _destinos => [
    if (widget.session.maloteHabilitado) MovimentoDestino.cofre,
    MovimentoDestino.banco,
    MovimentoDestino.tesouraria,
    MovimentoDestino.outro,
  ];

  Future<void> _registrar() async {
    final resp = await widget.controller.registrar(
      supervisorLoginCode: _loginCtrl.text,
      supervisorPassword: _pwdCtrl.text,
    );
    if (!mounted || resp == null) {
      // Se acabou de entrar em step-up, foca o campo de código do supervisor.
      if (mounted && widget.controller.requerSupervisor) {
        _loginFocus.requestFocus();
      }
      return;
    }
    _pwdCtrl.clear();
    Navigator.of(context).pop(resp);
  }

  void _cancelar() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): _cancelar,
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([widget.controller, widget.session]),
              builder: (context, _) => _card(colors),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(AppColors colors) {
    final ctrl = widget.controller;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(colors),
            const SizedBox(height: 18),

            const PdvFieldLabel('VALOR'),
            const SizedBox(height: 6),
            TextField(
              controller: _amountCtrl,
              focusNode: _amountFocus,
              enabled: !ctrl.loading,
              keyboardType: TextInputType.number,
              inputFormatters: const [MoedaInputFormatter()],
              textInputAction: TextInputAction.next,
              onChanged: (t) => ctrl.setAmount(MoedaInputFormatter.parse(t)),
              onSubmitted: (_) => _reasonFocus.requestFocus(),
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: pdvInputDecoration(context, hint: 'R\$ 0,00'),
            ),
            _sugestaoLinha(colors),

            const SizedBox(height: 16),
            PdvFieldLabel(_isSangria ? 'MOTIVO' : 'OBSERVAÇÃO'),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonCtrl,
              focusNode: _reasonFocus,
              enabled: !ctrl.loading,
              onChanged: ctrl.setReason,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (ctrl.podeRegistrar) _registrar();
              },
              style: TextStyle(fontSize: 14, color: colors.text),
              decoration: pdvInputDecoration(
                context,
                hint: _isSangria ? 'Ex.: sangria para o cofre' : 'Opcional',
              ),
            ),

            if (_isSangria) ..._destinoSection(colors),
            if (ctrl.requerSupervisor) ..._supervisorSection(colors),

            if (ctrl.errorMessage != null) ...[
              const SizedBox(height: 14),
              PdvErrorBanner(ctrl.errorMessage!),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PdvGhostButton(
                    'Cancelar',
                    onTap: ctrl.loading ? null : _cancelar,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: PdvPrimaryButton(
                    label: _isSangria
                        ? 'Registrar sangria'
                        : 'Registrar reforço',
                    icon: LucideIcons.check,
                    loading: ctrl.loading,
                    enabled: ctrl.podeRegistrar,
                    onTap: _registrar,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppColors colors) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Icon(LucideIcons.banknote, size: 19, color: colors.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSangria ? 'Sangria' : 'Reforço de caixa',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _isSangria
                    ? 'Retirada de dinheiro do caixa.'
                    : 'Entrada de dinheiro no caixa.',
                style: TextStyle(fontSize: 12, color: colors.textMute),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sugestaoLinha(AppColors colors) {
    final ctrl = widget.controller;
    if (ctrl.carregandoSugestao) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Calculando sugestão…',
          style: TextStyle(fontSize: 12, color: colors.textDim),
        ),
      );
    }
    final s = ctrl.sugestao;
    if (s == null || !s.sangriaRecomendada) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: ctrl.loading
                  ? null
                  : () => _aplicarValor(s.suggestedRounded),
              child: Text(
                'Sugerido: ${BrlFormatter.format(s.suggestedRounded)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ),
          ),
          const Spacer(),
          Text(
            'Em caixa: ${BrlFormatter.format(s.cashLive)}',
            style: TextStyle(fontSize: 12, color: colors.textMute),
          ),
        ],
      ),
    );
  }

  List<Widget> _destinoSection(AppColors colors) {
    final falhou = widget.session.cxConfigStatus == CxConfigStatus.falhou;
    return [
      const SizedBox(height: 16),
      const PdvFieldLabel('DESTINO'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final d in _destinos) _destinoChip(d, colors)],
      ),
      if (falhou) ...[
        const SizedBox(height: 8),
        Text(
          'Não foi possível confirmar a configuração da loja — '
          'destino "Cofre" indisponível no momento.',
          style: TextStyle(fontSize: 11.5, color: colors.textMute),
        ),
      ],
    ];
  }

  Widget _destinoChip(MovimentoDestino d, AppColors colors) {
    final ctrl = widget.controller;
    final selected = ctrl.destino == d;
    return GestureDetector(
      onTap: ctrl.loading
          ? null
          // Toca no selecionado → desmarca (destino é opcional).
          : () => ctrl.setDestino(selected ? null : d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? colors.accent : colors.border),
        ),
        child: Text(
          _destinoLabel(d),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colors.accentInk : colors.text,
          ),
        ),
      ),
    );
  }

  List<Widget> _supervisorSection(AppColors colors) {
    final ctrl = widget.controller;
    return [
      const SizedBox(height: 16),
      const PdvInfoBanner('Esta saída precisa de liberação de um supervisor.'),
      const SizedBox(height: 14),
      const PdvFieldLabel('CÓDIGO DO SUPERVISOR'),
      const SizedBox(height: 6),
      TextField(
        controller: _loginCtrl,
        focusNode: _loginFocus,
        enabled: !ctrl.loading,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: TextInputAction.next,
        onChanged: (_) => ctrl.clearError(),
        onSubmitted: (_) => _pwdFocus.requestFocus(),
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 15,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        decoration: pdvInputDecoration(context, hint: '10000001'),
      ),
      const SizedBox(height: 14),
      const PdvFieldLabel('SENHA DO SUPERVISOR'),
      const SizedBox(height: 6),
      TextField(
        controller: _pwdCtrl,
        focusNode: _pwdFocus,
        enabled: !ctrl.loading,
        obscureText: ctrl.obscurePassword,
        autofillHints: const [],
        textInputAction: TextInputAction.done,
        onChanged: (_) => ctrl.clearError(),
        onSubmitted: (_) {
          if (ctrl.podeRegistrar) _registrar();
        },
        style: TextStyle(fontSize: 15, color: colors.text),
        decoration: pdvInputDecoration(
          context,
          hint: '••••••',
          suffix: IconButton(
            tooltip: ctrl.obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
            onPressed: ctrl.toggleObscure,
            icon: Icon(
              ctrl.obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
              size: 18,
              color: colors.textMute,
            ),
          ),
        ),
      ),
    ];
  }
}

String _destinoLabel(MovimentoDestino d) => switch (d) {
  MovimentoDestino.cofre => 'Cofre',
  MovimentoDestino.banco => 'Banco',
  MovimentoDestino.tesouraria => 'Tesouraria',
  MovimentoDestino.outro => 'Outro',
};
