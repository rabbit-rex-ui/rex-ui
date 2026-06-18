/// Formatador de Reais brasileiros. Substitui `NumberFormat.simpleCurrency`
/// do `intl` por código local — economiza ~600KB no bundle e evita uma
/// dependência pesada num app desktop simples.
///
/// Formato: `R$ 1.234,56`, separador de milhar `.`, decimal `,`,
/// sempre 2 casas, espaço entre símbolo e número.
class BrlFormatter {
  BrlFormatter._();

  /// `1234.5` → `"R$ 1.234,50"`.
  /// `null` → `"R$ 0,00"`.
  static String format(double? value) {
    final v = value ?? 0;
    final negativo = v < 0;
    final abs = v.abs();

    // Arredondamento half-up em duas casas.
    final cents = (abs * 100).round();
    final inteiro = cents ~/ 100;
    final decimal = cents % 100;

    final inteiroStr = _agruparMilhares(inteiro);
    final decimalStr = decimal.toString().padLeft(2, '0');

    final sinal = negativo ? '-' : '';
    return 'R\$ $sinal$inteiroStr,$decimalStr';
  }

  /// Versão compacta sem o "R\$" — útil em colunas onde o símbolo é redundante.
  /// `1234.5` → `"1.234,50"`.
  static String formatPlain(double? value) {
    return format(value).replaceFirst('R\$ ', '');
  }

  static String _agruparMilhares(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;

    final buffer = StringBuffer();
    final start = s.length % 3;
    if (start > 0) buffer.write(s.substring(0, start));

    for (var i = start; i < s.length; i += 3) {
      if (buffer.isNotEmpty) buffer.write('.');
      buffer.write(s.substring(i, i + 3));
    }
    return buffer.toString();
  }
}
