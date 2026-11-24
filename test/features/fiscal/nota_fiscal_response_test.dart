import 'package:flutter_test/flutter_test.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/nota_fiscal_response.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_modelo.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';

import 'fiscal_fixtures.dart';

void main() {
  group('NotaFiscalResponse.fromJson', () {
    test('lê o exemplo do guia (§4)', () {
      final n = NotaFiscalResponse.fromJson(notaJson());
      expect(n.modelo, NotaModelo.nfce);
      expect(n.status, NotaStatus.autorizada);
      expect(n.serie, 1);
      expect(n.numero, 123);
      expect(n.valorTotal, 19.80);
      expect(n.chaveAcesso, hasLength(44));
      expect(n.emContingencia, isFalse);
      expect(n.cancelavelAte, isNotNull);
    });

    test('campos omitidos viram null (guia §3)', () {
      final json = notaJson(status: 'PENDING')
        ..remove('serie')
        ..remove('numero')
        ..remove('chaveAcesso')
        ..remove('protocolo')
        ..remove('autorizadaEm');
      final n = NotaFiscalResponse.fromJson(json);
      expect(n.numero, isNull);
      expect(n.chaveAcesso, isNull);
      expect(n.cancelavelAte, isNull);
    });

    test('status desconhecido estoura (divergência de contrato)', () {
      expect(
        () => NotaFiscalResponse.fromJson(notaJson(status: 'XPTO')),
        throwsArgumentError,
      );
    });

    test('cStat numérico é aceito como texto', () {
      final json = notaJson(status: 'DENIED')..['codigoRejeicao'] = 539;
      expect(NotaFiscalResponse.fromJson(json).codigoRejeicao, '539');
    });
  });

  group('cancelavelEm (guia §8.3)', () {
    final agora = DateTime.now();

    test('autorizada dentro do prazo pode cancelar', () {
      final n = nota(cancelavelAte: agora.add(const Duration(minutes: 5)));
      expect(n.cancelavelEm(agora), isTrue);
    });

    test('prazo vencido não pode', () {
      final n = nota(
        cancelavelAte: agora.subtract(const Duration(seconds: 1)),
      );
      expect(n.cancelavelEm(agora), isFalse);
    });

    test('cancelamento em andamento não pode (usa "Tentar de novo")', () {
      final n = nota(cancelamentoEmAndamento: true);
      expect(n.cancelavelEm(agora), isFalse);
      expect(n.precisaAcompanhar, isTrue);
    });

    test('nota não autorizada não pode', () {
      expect(nota(status: 'CANCELLED').cancelavelEm(agora), isFalse);
    });
  });

  group('NotaStatus', () {
    test('ativa = ocupa a venda (PENDING/SENT/AUTHORIZED)', () {
      expect(NotaStatus.pendente.ativa, isTrue);
      expect(NotaStatus.enviada.ativa, isTrue);
      expect(NotaStatus.autorizada.ativa, isTrue);
      expect(NotaStatus.rejeitada.ativa, isFalse);
      expect(NotaStatus.cancelada.ativa, isFalse);
    });

    test('emProcessamento só em PENDING/SENT', () {
      expect(NotaStatus.pendente.emProcessamento, isTrue);
      expect(NotaStatus.enviada.emProcessamento, isTrue);
      expect(NotaStatus.autorizada.emProcessamento, isFalse);
    });
  });
}
