import 'package:flutter_test/flutter_test.dart';
import 'package:rabbit_pdv/core/json/json_read.dart';

void main() {
  group('JsonRead.decimal', () {
    test('aceita num e string numérica', () {
      expect(JsonRead.decimal(19.8), 19.8);
      expect(JsonRead.decimal(2), 2.0);
      expect(JsonRead.decimal('3.5'), 3.5);
    });

    test('ausente ou inválido vira 0', () {
      expect(JsonRead.decimal(null), 0);
      expect(JsonRead.decimal('abc'), 0);
    });

    test('decimalOrNull devolve null quando ausente ou inválido', () {
      expect(JsonRead.decimalOrNull(null), isNull);
      expect(JsonRead.decimalOrNull('x'), isNull);
      expect(JsonRead.decimalOrNull('1.25'), 1.25);
    });
  });

  group('JsonRead.integer', () {
    test('aceita int, num e string', () {
      expect(JsonRead.integer(7), 7);
      expect(JsonRead.integer(7.9), 7);
      expect(JsonRead.integer('12'), 12);
      expect(JsonRead.integer(null), 0);
    });
  });

  group('JsonRead.instant', () {
    test('converte UTC para o fuso local preservando o instante', () {
      final d = JsonRead.instant('2026-11-19T14:03:27.123456Z');
      expect(d.isUtc, isFalse);
      expect(d.toUtc(), DateTime.utc(2026, 11, 19, 14, 3, 27, 123, 456));
    });

    test('obrigatório ausente lança (divergência de contrato)', () {
      expect(() => JsonRead.instant(null), throwsA(anything));
    });

    test('instantOrNull é tolerante', () {
      expect(JsonRead.instantOrNull(null), isNull);
      expect(JsonRead.instantOrNull(''), isNull);
      expect(JsonRead.instantOrNull('não é data'), isNull);
      expect(JsonRead.instantOrNull('2026-11-19T14:03:27Z'), isNotNull);
    });
  });
}
