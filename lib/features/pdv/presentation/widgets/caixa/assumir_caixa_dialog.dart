import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/auth/presentation/login_controller.dart';
import 'package:rabbit_pdv/features/pdv/data/assumir_caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/assumir_caixa_dtos.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/assumir_caixa_controller.dart';

const double _kDialogMaxWidth = 520;

/// Resultado da posse: resposta do servidor + a escolha de B sobre o carrinho.
class AssumirCaixaOutcome {
  const AssumirCaixaOutcome({
    required this.response,
    required this.cartPreserved,
  });
  final AssumirCaixaResponse response;
  final bool cartPreserved;
}

/// (COM Navigator — fora do lock.) Constrói o controller a partir de
/// [cashRegisterId] (resolve a sessão via GET).
Future<AssumirCaixaOutcome?> showAssumirCaixa(
  BuildContext context, {
  required AssumirCaixaRepository assumirRepo,
  required CaixaRepository caixaRepo,
  required LoginController login,
  required String cashRegisterId,
  String? cartRef,
  int cartItemCount = 0,
  double cartTotal = 0,
}) {
  final controller = AssumirCaixaController(
    assumirRepo: assumirRepo,
    caixaRepo: caixaRepo,
    login: login,
    cashRegisterId: cashRegisterId,
  );
  return showAssumirCaixaWith(
    context,
    controller: controller,
    cartRef: cartRef,
    cartItemCount: cartItemCount,
    cartTotal: cartTotal,
  );
}

/// (COM Navigator.) Recebe um controller já construído. Faz dispose ao fechar.
Future<AssumirCaixaOutcome?> showAssumirCaixaWith(
  BuildContext context, {
  required AssumirCaixaController controller,
  String? cartRef,
  int cartItemCount = 0,
  double cartTotal = 0,
}) {
  return showGeneralDialog<AssumirCaixaOutcome>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Assumir caixa',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (ctx, _, __) => _AssumirCaixaDialog(
      controller: controller,
      cartRef: cartRef,
      cartItemCount: cartItemCount,
      cartTotal: cartTotal,
      onClose: (outcome) => Navigator.of(ctx).pop(outcome),
    ),
  ).whenComplete(controller.dispose);
}

/// (SEM Navigator — dentro do LockOverlay.) Insere o diálogo como [OverlayEntry]
/// no [overlay] fornecido. Resolve o Future quando o diálogo fecha.
Future<AssumirCaixaOutcome?> showAssumirCaixaInOverlay(
  OverlayState overlay, {
  required AssumirCaixaController controller,
  String? cartRef,
  int cartItemCount = 0,
  double cartTotal = 0,
}) {
  final completer = Completer<AssumirCaixaOutcome?>();
  late final OverlayEntry entry;

  void close(AssumirCaixaOutcome? outcome) {
    if (completer.isCompleted) return;
    entry.remove();
    controller.dispose();
    completer.complete(outcome);
  }

  entry = OverlayEntry(
    builder: (context) {
      final colors = context.colors;
      final maxH = MediaQuery.of(context).size.height * 0.92;
      return Stack(
        children: [
          const ModalBarrier(dismissible: false, color: Colors.black54),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _kDialogMaxWidth,
                maxHeight: maxH,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => _AssumirCaixaDialog(
                    controller: controller,
                    cartRef: cartRef,
                    cartItemCount: cartItemCount,
                    cartTotal: cartTotal,
                    onClose: close,
                    embedded: true,
                    colorsOverride: colors,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  overlay.insert(entry);
  return completer.future;
}

class _AssumirCaixaDialog extends StatefulWidget {
  const _AssumirCaixaDialog({
    required this.controller,
    required this.cartRef,
    required this.cartItemCount,
    required this.cartTotal,
    required this.onClose,
    this.embedded = false,
    this.colorsOverride,
  });

  final AssumirCaixaController controller;
  final String? cartRef;
  final int cartItemCount;
  final double cartTotal;
  final void Function(AssumirCaixaOutcome? outcome) onClose;
  final bool embedded;
  final AppColors? colorsOverride;

  @override
  State<_AssumirCaixaDialog> createState() => _AssumirCaixaDialogState();
}

class _AssumirCaixaDialogState extends State<_AssumirCaixaDialog> {
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  final _justCtrl = TextEditingController();

  CxTakeoverReason _reason = CxTakeoverReason.suddenAbsence;
  bool _cashVerified = false;
  late bool _cartPreserved = widget.cartItemCount > 0;

  AssumirCaixaResponse? _reveal;
  String? _localError;

  bool get _temCarrinho => widget.cartItemCount > 0;

  @override
  void dispose() {
    _passCtrl.clear();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _noteCtrl.dispose();
    _cashCtrl.dispose();
    _justCtrl.dispose();
    super.dispose();
  }

  void _clearErrors() {
    if (_localError != null) setState(() => _localError = null);
    widget.controller.clearError();
  }

  void _setLocalError(String m) => setState(() => _localError = m);

  Future<void> _submit() async {
    final c = widget.controller;
    if (_codeCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      _setLocalError('Informe o código de login e a senha de quem assume.');
      return;
    }
    if (_reason == CxTakeoverReason.other && _noteCtrl.text.trim().isEmpty) {
      _setLocalError('Descreva o motivo (obrigatório para "Outro").');
      return;
    }
    if (_cashVerified && _centsFromText(_cashCtrl.text) == 0) {
      _setLocalError('Informe o valor contado.');
      return;
    }

    final outcome = await c.assumir(
      loginCode: _codeCtrl.text,
      password: _passCtrl.text,
      reason: _reason,
      reasonNote: _reason == CxTakeoverReason.other
          ? _noteCtrl.text.trim()
          : null,
      cashVerified: _cashVerified,
      countedCash: _cashVerified ? _centsFromText(_cashCtrl.text) / 100 : null,
      cartPreserved: _temCarrinho && _cartPreserved,
      cartRef: (_temCarrinho && _cartPreserved) ? widget.cartRef : null,
      justificationNote: _justCtrl.text.trim().isEmpty
          ? null
          : _justCtrl.text.trim(),
    );

    if (!mounted || outcome == null) return;

    if (outcome.cashVerified) {
      setState(() => _reveal = outcome);
    } else {
      _concluir(outcome);
    }
  }

  void _concluir(AssumirCaixaResponse r) {
    _passCtrl.clear();
    widget.onClose(
      AssumirCaixaOutcome(
        response: r,
        cartPreserved: _temCarrinho && _cartPreserved,
      ),
    );
  }

  AppColors _colors(BuildContext context) =>
      widget.colorsOverride ?? context.colors;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);
    final card = AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => _card(colors),
    );

    if (widget.embedded) return card;

    final maxH = MediaQuery.of(context).size.height * 0.92;
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _kDialogMaxWidth,
            maxHeight: maxH,
          ),
          child: card,
        ),
      ),
    );
  }

  Widget _card(AppColors colors) {
    final c = widget.controller;
    final loading = c.loading;
    final error = _localError ?? c.errorMessage;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _reveal != null
              ? _revealBody(colors, _reveal!)
              : _formBody(colors, loading, error),
        ),
      ),
    );
  }

  // ─── Formulário ───
  List<Widget> _formBody(AppColors colors, bool loading, String? error) {
    final c = widget.controller;
    return [
      Row(
        children: [
          Icon(LucideIcons.userCog, size: 20, color: colors.accent),
          const SizedBox(width: 10),
          Text(
            'Assumir caixa',
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
        'Tomada de posse formal. A custódia A→B fica registrada. '
        'Identifique-se com suas próprias credenciais.',
        style: TextStyle(fontSize: 12.5, color: colors.textMute),
      ),
      const SizedBox(height: 20),

      // Credenciais lado a lado (economiza altura).
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('Código de login', colors),
                const SizedBox(height: 6),
                TextField(
                  controller: _codeCtrl,
                  enabled: !loading,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _clearErrors(),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 15,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  decoration: _input(colors, hint: '10000002'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('Senha', colors),
                const SizedBox(height: 6),
                TextField(
                  controller: _passCtrl,
                  enabled: !loading,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _clearErrors(),
                  style: TextStyle(fontSize: 15, color: colors.text),
                  decoration: _input(colors, hint: '••••••'),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),

      _label('Motivo', colors),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final r in CxTakeoverReason.values)
            _reasonChip(colors, r, disabled: loading),
        ],
      ),
      if (_reason == CxTakeoverReason.other) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _noteCtrl,
          enabled: !loading,
          minLines: 1,
          maxLines: 2,
          onChanged: (_) => _clearErrors(),
          style: TextStyle(fontSize: 14, color: colors.text),
          decoration: _input(colors, hint: 'Descreva o motivo'),
        ),
      ],
      const SizedBox(height: 18),

      _label('Conferência de caixa', colors),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _segBtn(
              colors,
              'Conferir',
              selected: _cashVerified,
              disabled: loading,
              onTap: () => setState(() {
                _cashVerified = true;
                _clearErrors();
              }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _segBtn(
              colors,
              'Sem conferir',
              selected: !_cashVerified,
              disabled: loading,
              onTap: () => setState(() {
                _cashVerified = false;
                _clearErrors();
              }),
            ),
          ),
        ],
      ),
      if (_cashVerified) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _cashCtrl,
          enabled: !loading,
          keyboardType: TextInputType.number,
          inputFormatters: [_MoedaInputFormatter()],
          onChanged: (_) => _clearErrors(),
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: _input(colors, hint: r'R$ 0,00'),
        ),
        const SizedBox(height: 6),
        Text(
          'Contagem cega: o valor esperado só é revelado após confirmar.',
          style: TextStyle(fontSize: 11.5, color: colors.textDim),
        ),
      ],

      if (_temCarrinho) ...[
        const SizedBox(height: 18),
        _label('Atendimento em curso', colors),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.borderSoft),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.shoppingCart, size: 16, color: colors.textMute),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.cartItemCount} '
                  '${widget.cartItemCount == 1 ? 'item' : 'itens'} · '
                  '${_brl((widget.cartTotal * 100).round())}',
                  style: TextStyle(fontSize: 13, color: colors.text),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _segBtn(
                colors,
                'Preservar',
                selected: _cartPreserved,
                disabled: loading,
                onTap: () => setState(() => _cartPreserved = true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _segBtn(
                colors,
                'Começar do zero',
                selected: !_cartPreserved,
                disabled: loading,
                onTap: () => setState(() => _cartPreserved = false),
              ),
            ),
          ],
        ),
      ],

      if (c.precisaJustificativa) ...[
        const SizedBox(height: 18),
        _label('Justificativa da divergência', colors),
        const SizedBox(height: 6),
        TextField(
          controller: _justCtrl,
          enabled: !loading,
          minLines: 2,
          maxLines: 3,
          autofocus: true,
          onChanged: (_) => _clearErrors(),
          style: TextStyle(fontSize: 14, color: colors.text),
          decoration: _input(colors, hint: 'Ex.: faltava troco no caixa'),
        ),
      ],

      if (error != null) ...[
        const SizedBox(height: 14),
        _errorBanner(error, colors),
      ],

      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(
            child: _ghostBtn(
              colors,
              'Cancelar',
              disabled: loading,
              onTap: () => widget.onClose(null),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _primaryBtn(
              colors,
              'Assumir caixa',
              loading: loading,
              onTap: _submit,
            ),
          ),
        ],
      ),
    ];
  }

  // ─── Revelação da divergência ───
  List<Widget> _revealBody(AppColors colors, AssumirCaixaResponse r) {
    final variance = r.cashVariance ?? 0;
    final cor = variance < 0
        ? colors.danger
        : (variance > 0 ? colors.warn : colors.success);
    final rotulo = variance < 0
        ? 'Falta'
        : (variance > 0 ? 'Sobra' : 'Confere');
    return [
      Row(
        children: [
          Icon(LucideIcons.scale, size: 20, color: cor),
          const SizedBox(width: 10),
          Text(
            'Posse registrada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _revealRow(colors, 'Esperado', r.expectedCashSnapshot),
      const SizedBox(height: 8),
      _revealRow(colors, 'Contado', r.countedCash ?? 0),
      const Divider(height: 24),
      _revealRow(colors, rotulo, variance, accent: cor, bold: true),
      const SizedBox(height: 24),
      _primaryBtn(
        colors,
        'Concluir',
        loading: false,
        onTap: () => _concluir(r),
      ),
    ];
  }

  Widget _revealRow(
    AppColors colors,
    String label,
    double valor, {
    Color? accent,
    bool bold = false,
  }) {
    final cents = (valor.abs() * 100).round();
    final sinal = valor < 0 ? '−' : (valor > 0 && bold ? '+' : '');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: accent ?? colors.textMute,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        Text(
          '$sinal${_brl(cents)}',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: bold ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: accent ?? colors.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // ─── Helpers de estilo ───
  Widget _reasonChip(
    AppColors colors,
    CxTakeoverReason r, {
    required bool disabled,
  }) {
    final sel = _reason == r;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: disabled
          ? null
          : () => setState(() {
              _reason = r;
              _clearErrors();
            }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? colors.accent.withValues(alpha: 0.12) : colors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel ? colors.accent : colors.border,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Text(
          r.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
            color: sel ? colors.accent : colors.text,
          ),
        ),
      ),
    );
  }

  Widget _segBtn(
    AppColors colors,
    String label, {
    required bool selected,
    required bool disabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: disabled ? null : onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.12)
              : colors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? colors.accent : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colors.accent : colors.text,
          ),
        ),
      ),
    );
  }

  Widget _primaryBtn(
    AppColors colors,
    String label, {
    required bool loading,
    required VoidCallback onTap,
  }) {
    return Material(
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
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.accentInk,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _ghostBtn(
    AppColors colors,
    String label, {
    required bool disabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: disabled ? null : onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.text,
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

  InputDecoration _input(AppColors colors, {required String hint}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.textDim),
        filled: true,
        fillColor: colors.surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
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

// ─── Moeda (centavos → BRL) ───
String _brl(int cents) {
  final reais = cents ~/ 100;
  final cs = (cents % 100).toString().padLeft(2, '0');
  final r = reais.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  return 'R\$ $r,$cs';
}

int _centsFromText(String s) {
  final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? 0 : int.parse(digits);
}

class _MoedaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cents = _centsFromText(newValue.text);
    if (cents == 0) return const TextEditingValue(text: '');
    final txt = _brl(cents);
    return TextEditingValue(
      text: txt,
      selection: TextSelection.collapsed(offset: txt.length),
    );
  }
}
