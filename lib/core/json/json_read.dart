/// Leitura de campos JSON vindos do backend, num lugar só.
///
/// Antes, cada DTO tinha a sua cópia de `_money`/`_date`/`_dOpt`… com nomes
/// diferentes e comportamento quase igual. Use estes métodos em todo `fromJson`.
///
/// Regra geral:
/// - campo **obrigatório** ausente/inválido → lança (o `ApiClient` converte a
///   exceção em `UnknownFailure('Resposta inválida do servidor.')`). Divergência
///   de contrato deve estourar cedo, não virar zero silencioso;
/// - campo **opcional** (`…OrNull`) ausente/inválido → `null`.
abstract final class JsonRead {
  /// Número decimal (valor monetário ou quantidade). Aceita `num` ou string
  /// numérica. Ausente/inválido → `0`.
  static double decimal(Object? v) => decimalOrNull(v) ?? 0;

  /// Como [decimal], mas ausente/inválido → `null`.
  static double? decimalOrNull(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Inteiro. Aceita `num` ou string numérica. Ausente/inválido → `0`.
  static int integer(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// Instante ISO-8601 obrigatório (o backend manda em UTC), convertido para o
  /// fuso local. Lança se ausente ou inválido.
  static DateTime instant(Object? v) => DateTime.parse(v as String).toLocal();

  /// Instante ISO-8601 opcional, convertido para o fuso local. Ausente, vazio
  /// ou inválido → `null`.
  static DateTime? instantOrNull(Object? v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v)?.toLocal();
  }
}
