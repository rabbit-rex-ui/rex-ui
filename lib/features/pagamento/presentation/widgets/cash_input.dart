import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';

/// Input "Valor recebido" + linha de troco/falta. Aparece inline no
/// SliceCard apenas quando o método selecionado é dinheiro.
///
/// O input aceita números com vírgula ou ponto e converte pra `double`.
/// Troco aparece em verde quando há sobra; "Faltam" em danger quando
/// está abaixo do total.
class CashInput extends StatefulWidget {
  final double total;
  final double valorRecebido;
  final double troco;
  final double faltam;
  final ValueChanged<double> onChange;
  final VoidCallback? onSubmit;

  const CashInput({
    super.key,
    required this.total,
    required this.valorRecebido,
    required this.troco,
    required this.faltam,
    required this.onChange,
    this.onSubmit,
  });

  @override
  State<CashInput> createState() => _CashInputState();
}

class _CashInputState extends State<CashInput> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _formatForEdit(widget.valorRecebido));
    _focus = FocusNode();
    // Foco automático: quando o operador escolhe "Dinheiro", já abre
    // direto no campo. Próximo frame pra garantir tree montada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant CashInput old) {
    super.didUpdateWidget(old);
    // Resync quando o controller externo mudou o valor (ex: prefill com
    // total ao trocar de método). Evita sobrescrever enquanto operador
    // digita: só atualiza se o valor numérico divergiu.
    final externoTxt = _formatForEdit(widget.valorRecebido);
    final internoNum = _parse(_ctrl.text);
    if ((widget.valorRecebido - internoNum).abs() > 0.001) {
      _ctrl.text = externoTxt;
      _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrl.text.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _formatForEdit(double v) =>
      v == 0 ? '' : v.toStringAsFixed(2).replaceAll('.', ',');

  /// Parser tolerante: aceita "1234,56", "1234.56", "1.234,56", "1234".
  double _parse(String raw) {
    if (raw.trim().isEmpty) return 0;
    // Remove tudo que não é dígito, vírgula ou ponto.
    var s = raw.replaceAll(RegExp(r'[^\d,\.]'), '');
    // Se tem ambos . e ,: assume formato BR (`.` milhar, `,` decimal).
    if (s.contains(',') && s.contains('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (s.contains(',')) {
      s = s.replaceAll(',', '.');
    }
    return double.tryParse(s) ?? 0;
  }

  void _handleChange(String raw) {
    final v = _parse(raw);
    widget.onChange(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasOverflow = widget.troco > 0;
    final hasShortfall = widget.faltam > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'VALOR RECEBIDO',
          style: AppText.overline.copyWith(color: c.textMute),
        ),
        const SizedBox(height: 6),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasShortfall ? c.danger : c.border,
              width: hasShortfall ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                'R\$',
                style: AppText.monoMd.copyWith(
                  color: c.textMute,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d,\.]')),
                  ],
                  style: AppText.monoLg.copyWith(
                    color: c.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: '0,00',
                  ),
                  onChanged: _handleChange,
                  onSubmitted: (_) => widget.onSubmit?.call(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Linha de troco/falta. Sempre presente pra evitar jitter de layout.
        SizedBox(
          height: 28,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasShortfall ? 'Faltam' : 'Troco',
                style: AppText.bodySm.copyWith(
                  color: c.textMute,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                BrlFormatter.format(
                  hasShortfall ? widget.faltam : widget.troco,
                ),
                style: AppText.monoMd.copyWith(
                  color: hasShortfall
                      ? c.danger
                      : (hasOverflow ? c.success : c.textDim),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
