import 'package:rabbit_pdv/domain/enums/unidade_medida.dart';

/// Formata quantidade respeitando a unidade do produto.
///
/// - [UnidadeMedida.un]: inteiro sem casa decimal (ex: `3`).
/// - [UnidadeMedida.kg]: três casas decimais com sufixo `kg` (ex: `0,842kg`).
class UnidadeFormatter {
  UnidadeFormatter._();

  static String format(double qtd, UnidadeMedida un) {
    return switch (un) {
      UnidadeMedida.un => qtd.toInt().toString(),
      UnidadeMedida.kg => '${qtd.toStringAsFixed(3).replaceAll('.', ',')}kg',
    };
  }

  /// Sufixo da unidade isolado, p.ex. para legendas de preço (`/kg`).
  static String suffix(UnidadeMedida un) {
    return switch (un) {
      UnidadeMedida.un => 'un',
      UnidadeMedida.kg => '/kg',
    };
  }

  /// Incremento padrão do stepper.
  static double step(UnidadeMedida un) {
    return switch (un) {
      UnidadeMedida.un => 1.0,
      UnidadeMedida.kg => 0.1,
    };
  }
}
