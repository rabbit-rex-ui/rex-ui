import 'package:flutter/services.dart';
import 'package:rabbit_pdv/core/format/brl_formatter.dart';

/// Formata a digitação como moeda BRL no padrão "centavos": o operador digita
/// só dígitos e o valor cresce da direita para a esquerda — `1` → `R$ 0,01`,
/// `1234` → `R$ 12,34`. Sem ponto/vírgula manual, entrada rápida típica de PDV.
///
/// O texto exibido usa [BrlFormatter]; o valor numérico (em reais) é lido com
/// [MoedaInputFormatter.parse].
class MoedaInputFormatter extends TextInputFormatter {
  const MoedaInputFormatter({this.maxDigits = 9}); // até R$ 9.999.999,99

  /// Teto de dígitos aceitos (proteção contra overflow visual/numérico).
  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final cents = int.parse(digits);
    final text = BrlFormatter.format(cents / 100);
    // Cursor sempre no fim: a digitação empurra da direita para a esquerda.
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Lê o valor numérico (em reais) a partir do texto formatado ou de dígitos
  /// crus. `"R$ 12,34"` → `12.34`; `""` → `0`.
  static double parse(String formatted) {
    final digits = formatted.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.parse(digits) / 100;
  }
}
