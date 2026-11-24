import 'package:flutter_test/flutter_test.dart';
import 'package:rabbit_pdv/features/fiscal/domain/chave_acesso.dart';
import 'package:rabbit_pdv/features/fiscal/domain/justificativa_cancelamento.dart';
import 'package:rabbit_pdv/features/fiscal/presentation/nota_fiscal_ui.dart';

void main() {
  group('JustificativaCancelamento (guia §6.2: 15 a 255)', () {
    test('curta demais', () {
      expect(JustificativaCancelamento.validar('curta'), isNotNull);
      expect(JustificativaCancelamento.validar('a' * 14), isNotNull);
    });

    test('limites aceitos', () {
      expect(JustificativaCancelamento.validar('a' * 15), isNull);
      expect(JustificativaCancelamento.validar('a' * 255), isNull);
    });

    test('longa demais', () {
      expect(JustificativaCancelamento.validar('a' * 256), isNotNull);
    });

    test('espaços nas pontas não contam', () {
      expect(JustificativaCancelamento.validar('   ${'a' * 14}   '), isNotNull);
    });
  });

  group('NotaFiscalFormat', () {
    test('chave em blocos de 4', () {
      expect(
        chaveAcessoEmBlocos('52261183876972000171'),
        '5226 1183 8769 7200 0171',
      );
      expect(chaveAcessoEmBlocos('123456'), '1234 56');
    });

    test('tempo restante', () {
      expect(
        NotaFiscalFormat.tempoRestante(const Duration(minutes: 4, seconds: 9)),
        '04:09',
      );
      expect(
        NotaFiscalFormat.tempoRestante(const Duration(hours: 23, minutes: 5)),
        '23h 05min',
      );
    });
  });
}
