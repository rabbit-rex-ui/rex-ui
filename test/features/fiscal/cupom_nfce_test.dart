import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/fiscal/cupom/cupom_layout.dart';
import 'package:rabbit_pdv/features/fiscal/cupom/cupom_nfce.dart';
import 'package:rabbit_pdv/features/fiscal/cupom/cupom_nfce_xml.dart';
import 'package:rabbit_pdv/features/fiscal/cupom/cupom_texto.dart';

/// Fixtures do backend (`fixtures-cupom-nfce`, guia fiscal v2.2 §9.2): cada
/// XML tem um `*.esperado.txt` com a referência de CONTEÚDO e ORDEM. O
/// espaçamento é ilustrativo, então a comparação ignora espaços.
const _pasta = 'test/fixtures/cupom_nfce';
const _exemplos = [
  'nfce-01-autorizada-nao-identificado',
  'nfce-02-autorizada-cpf-producao',
  'nfce-03-delivery-pagamento-na-entrega',
  'nfce-04-contingencia-pendente',
  'nfce-05-contingencia-efetivada',
  'nfce-06-descricao-longa-e-casas-decimais',
];

String _xml(String nome) => File('$_pasta/$nome.xml').readAsStringSync();

CupomNfce _ler(String xml) => switch (CupomNfceXml.ler(xml)) {
  Ok(:final value) => value,
  Err(:final failure) => fail(failure.message),
};

String _texto(CupomNfce cupom, {int colunas = 48}) => CupomTexto.renderizar(
  CupomLayout.montar(cupom, colunas: colunas),
  colunas: colunas,
);

/// Tira os marcadores de via (`=== … ===`), que só existem na referência.
String _esperado(String nome) => File('$_pasta/$nome.esperado.txt')
    .readAsLinesSync()
    .where((l) => !l.startsWith('==='))
    .join('\n');

String _semEspacos(String s) => s.replaceAll(RegExp(r'\s'), '');

void main() {
  group('conteúdo e ordem iguais à referência do backend', () {
    for (final nome in _exemplos) {
      test(nome, () {
        final nosso = _texto(_ler(_xml(nome)));
        expect(_semEspacos(nosso), _semEspacos(_esperado(nome)));
      });
    }
  });

  group('largura', () {
    for (final colunas in [48, 42]) {
      test('nenhuma linha passa de $colunas colunas', () {
        for (final nome in _exemplos) {
          final linhas = _texto(_ler(_xml(nome)), colunas: colunas).split('\n');
          for (final l in linhas) {
            expect(l.length, lessThanOrEqualTo(colunas), reason: '$nome: "$l"');
          }
        }
      });
    }
  });

  group('regras do §9.2', () {
    test('QR copiado do XML, texto exato', () {
      final xml = _xml(_exemplos[0]);
      final qr = RegExp('<qrCode>(.*?)</qrCode>').firstMatch(xml)!.group(1);
      final linhas = CupomLayout.montar(_ler(xml));
      expect(linhas.whereType<LinhaQrCode>().single.conteudo, qr);
    });

    test('contingência pendente: 2 vias, corte entre elas, sem protocolo', () {
      final cupom = _ler(_xml('nfce-04-contingencia-pendente'));
      final linhas = CupomLayout.montar(cupom);
      final texto = _texto(cupom);

      expect(cupom.pendenteDeAutorizacao, isTrue);
      expect(linhas.whereType<LinhaCorte>(), hasLength(1));
      expect(linhas.whereType<LinhaQrCode>(), hasLength(2));
      expect(
        RegExp('Via do Estabelecimento').allMatches(texto),
        hasLength(1),
      );
      expect(texto, isNot(contains('Protocolo')));
      // Abaixo do cabeçalho e da identificação, nas duas vias.
      expect(RegExp('Pendente de autorização').allMatches(texto), hasLength(4));
    });

    test('contingência efetivada: protocolo e sem "Pendente"', () {
      final texto = _texto(_ler(_xml('nfce-05-contingencia-efetivada')));
      expect(texto, contains('Protocolo de autorização'));
      expect(texto, contains('EMITIDA EM CONTINGÊNCIA'));
      expect(texto, isNot(contains('Pendente de autorização')));
    });

    test('produção não tem a mensagem de homologação', () {
      final texto = _texto(_ler(_xml('nfce-02-autorizada-cpf-producao')));
      expect(texto, isNot(contains('HOMOLOGAÇÃO')));
      expect(texto, contains('CONSUMIDOR CPF 123.456.789-09'));
    });

    test('tPag 99 usa o xPag', () {
      final texto = _texto(_ler(_xml('nfce-03-delivery-pagamento-na-entrega')));
      expect(texto, contains('Pagamento na entrega'));
    });

    test('descrição longa quebra por palavra, continuação recuada (v2.3)', () {
      final linhas = _texto(
        _ler(_xml('nfce-06-descricao-longa-e-casas-decimais')),
      ).split('\n');
      expect(linhas, contains('001 Arroz Parboilizado Tipo 1 Pacote Econômico'));
      expect(linhas, contains('    Família 5kg Edição Especial'));
    });

    test('casas significativas sem arredondar: qCom 1.2345, vUnCom 5.995', () {
      final texto = _texto(
        _ler(_xml('nfce-06-descricao-longa-e-casas-decimais')),
      );
      expect(texto, contains('HORT-001  1,2345 KG x 5,995'));
      expect(texto, contains('MERC-002  2 UN x 24,90'));
    });

    test('data/hora como no XML, sem converter fuso', () {
      final texto = _texto(_ler(_xml(_exemplos[0])));
      expect(texto, contains('19/11/2026 11:03:27'));
    });
  });

  group('robustez', () {
    test('ignora assinatura, impostos e elementos novos', () {
      final original = _xml(_exemplos[0]);
      final enriquecido = original
          .replaceFirst(
            '</prod>',
            '</prod><imposto><vTotTrib>0.00</vTotTrib><IBSCBS><CST>000</CST>'
                '</IBSCBS></imposto>',
          )
          .replaceFirst(
            '</infNFeSupl>',
            '</infNFeSupl><Signature xmlns="http://www.w3.org/2000/09/'
                'xmldsig#"><SignedInfo/></Signature>',
          );
      expect(_texto(_ler(enriquecido)), _texto(_ler(original)));
    });

    test('sem infNFeSupl: não imprime (Err), nunca cupom incompleto', () {
      final semSupl = _xml(_exemplos[0]).replaceAll(
        RegExp('<infNFeSupl>.*?</infNFeSupl>', dotAll: true),
        '',
      );
      expect(CupomNfceXml.ler(semSupl), isA<Err<CupomNfce, Failure>>());
    });

    test('XML ilegível: Err', () {
      expect(CupomNfceXml.ler('<nfeProc>'), isA<Err<CupomNfce, Failure>>());
    });
  });
}
