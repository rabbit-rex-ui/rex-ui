import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/format/unidade_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/domain/entities/item_atendimento.dart';
import 'package:rabbit_pdv/features/pdv/data/anulacao_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/anular_item_dtos.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/anular_item_controller.dart';

/// Abre o fluxo de liberação (fiscal/gerente) para anular [item].
///
/// Cria um [AnularItemController] descartável (eventId único), exibe o diálogo
/// via `showGeneralDialog` e devolve a resposta do servidor em 2xx; null se o
/// operador cancelar. O CHAMADOR só deve remover o item local quando o retorno
/// for não-nulo. Em erro, o diálogo permanece aberto para nova tentativa
/// (reusando o mesmo eventId).
Future<AnularItemResponse?> showAnularItem(
  BuildContext context, {
  required AnulacaoRepository repo,
  required ItemAtendimento item,
  required String cashSessionId,
  String? cartRef,
}) async {
  final controller = AnularItemController(
    repo,
    cashSessionId: cashSessionId,
    cartRef: cartRef,
    produtoId: item.produtoId,
    sku: item.sku,
    productName: item.nome,
    quantity: item.qtd,
    unitPrice: item.preco,
    lineDiscountAmount: item.descontoLinha ?? 0,
  );

  try {
    return await showGeneralDialog<AnularItemResponse>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Liberação do supervisor',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, _, _) =>
          _AnularItemDialog(controller: controller, item: item),
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

class _AnularItemDialog extends StatefulWidget {
  const _AnularItemDialog({required this.controller, required this.item});

  final AnularItemController controller;
  final ItemAtendimento item;

  @override
  State<_AnularItemDialog> createState() => _AnularItemDialogState();
}

class _AnularItemDialogState extends State<_AnularItemDialog> {
  final _loginCodeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _loginCodeFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loginCodeFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _passwordCtrl.clear(); // não deixa a senha residual em memória
    _loginCodeCtrl.dispose();
    _passwordCtrl.dispose();
    _noteCtrl.dispose();
    _loginCodeFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _autorizar() async {
    final resp = await widget.controller.autorizar(
      loginCode: _loginCodeCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted || resp == null) return;
    _passwordCtrl.clear();
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
          constraints: const BoxConstraints(maxWidth: 440),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): _cancelar,
            },
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) => _card(colors),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(AppColors colors) {
    final ctrl = widget.controller;
    final loading = ctrl.loading;
    final error = ctrl.errorMessage;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(colors),
          const SizedBox(height: 18),
          _itemBox(colors),
          const SizedBox(height: 18),

          _label('MOTIVO DA ANULAÇÃO', colors),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in ReasonCategory.values) _reasonChip(r, colors),
            ],
          ),

          if (ctrl.reason == ReasonCategory.other) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              enabled: !loading,
              onChanged: ctrl.setReasonNote,
              textInputAction: TextInputAction.next,
              style: TextStyle(fontSize: 14, color: colors.text),
              decoration: _input(colors, hint: 'Descreva o motivo'),
            ),
          ],

          const SizedBox(height: 16),
          _label('CÓDIGO DO SUPERVISOR', colors),
          const SizedBox(height: 6),
          TextField(
            controller: _loginCodeCtrl,
            focusNode: _loginCodeFocus,
            enabled: !loading,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            onChanged: (_) => ctrl.clearError(),
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 15,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            decoration: _input(colors, hint: '10000001'),
          ),
          const SizedBox(height: 14),

          _label('SENHA DO SUPERVISOR', colors),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            enabled: !loading,
            obscureText: ctrl.obscurePassword,
            autofillHints: const [],
            textInputAction: TextInputAction.done,
            onChanged: (_) => ctrl.clearError(),
            onSubmitted: (_) {
              if (ctrl.podeAutorizar) _autorizar();
            },
            style: TextStyle(fontSize: 15, color: colors.text),
            decoration: _input(
              colors,
              hint: '••••••',
              suffix: IconButton(
                tooltip: ctrl.obscurePassword
                    ? 'Mostrar senha'
                    : 'Ocultar senha',
                onPressed: ctrl.toggleObscure,
                icon: Icon(
                  ctrl.obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
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
          Row(
            children: [
              Expanded(
                child: _ghostButton(
                  'Cancelar',
                  colors,
                  onTap: loading ? null : _cancelar,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _primaryButton(
                  colors,
                  loading: loading,
                  enabled: ctrl.podeAutorizar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(AppColors colors) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.dangerTint,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(LucideIcons.lock, size: 19, color: colors.danger),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Liberação do supervisor',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Anular item exige autorização do fiscal ou gerente.',
              style: TextStyle(fontSize: 12, color: colors.textMute),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _itemBox(AppColors colors) {
    final item = widget.item;
    final skuTail = item.sku.length > 7
        ? item.sku.substring(item.sku.length - 7)
        : item.sku;
    final qtdLabel = UnidadeFormatter.format(item.qtd, item.un);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.shoppingBag, size: 18, color: colors.textMute),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$skuTail · $qtdLabel × ${BrlFormatter.format(item.preco)}',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    color: colors.textMute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            BrlFormatter.format(item.total),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reasonChip(ReasonCategory r, AppColors colors) {
    final selected = widget.controller.reason == r;
    return GestureDetector(
      onTap: widget.controller.loading
          ? null
          : () => widget.controller.setReason(r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? colors.accent : colors.border),
        ),
        child: Text(
          r.label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colors.accentInk : colors.text,
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(
    AppColors colors, {
    required bool loading,
    required bool enabled,
  }) {
    final active = enabled && !loading;
    return Opacity(
      opacity: active ? 1 : 0.6,
      child: Material(
        color: colors.accent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: active ? _autorizar : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 48,
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
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.check,
                        size: 17,
                        color: colors.accentInk,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Autorizar exclusão',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: colors.accentInk,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _ghostButton(String label, AppColors colors, {VoidCallback? onTap}) =>
      Material(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textMute,
              ),
            ),
          ),
        ),
      );

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
