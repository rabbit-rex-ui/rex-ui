import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/fiscal/cupom/cupom_layout.dart';
import 'package:rabbit_pdv/features/fiscal/cupom/cupom_nfce_xml.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/escpos/code_page_850.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/escpos/comandos_escpos.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/escpos/cupom_escpos.dart';

/// Quantas vezes [agulha] aparece em [palheiro].
int _ocorrencias(List<int> palheiro, List<int> agulha) {
  var total = 0;
  for (var i = 0; i + agulha.length <= palheiro.length; i++) {
    var igual = true;
    for (var j = 0; j < agulha.length; j++) {
      if (palheiro[i + j] != agulha[j]) {
        igual = false;
        break;
      }
    }
    if (igual) total++;
  }
  return total;
}

const _corte = [0x1D, 0x56, 0x42, 0x03]; // GS V 66 3

void main() {
  group('CodePage850 (guia v2.3 §9.3)', () {
    test('acentos do português pelos bytes da PC850', () {
      expect(CodePage850.codificar('Goiânia'), [
        0x47, 0x6F, 0x69, 0x83, 0x6E, 0x69, 0x61, // â = 0x83
      ]);
      expect(CodePage850.codificar('ÇÃã'), [0x80, 0xC7, 0xC6]);
      expect(CodePage850.codificar('1ª 2º'), [0x31, 0xA6, 0x20, 0x32, 0xA7]);
    });

    test('substituições: travessão, aspas, reticências, marcador, nbsp', () {
      expect(
        String.fromCharCodes(
          CodePage850.codificar('a – b — “c” ‘d’ e… •\u00A0f'),
        ),
        'a - b - "c" \'d\' e... * f',
      );
    });

    test('letra latina fora da PC850 perde o acento; o resto vira ?', () {
      // Ł não se decompõe (letra própria) → ?; ó está na PC850; ź → z.
      expect(CodePage850.codificar('Łódź'), [0x3F, 0xA2, 0x64, 0x7A]);
      expect(String.fromCharCodes(CodePage850.codificar('Žő')), 'Zo');
      expect(CodePage850.codificar('中'), [0x3F]);
    });

    test('controle nunca vira comando ESC/POS (vira espaço)', () {
      // ESC p = abrir gaveta: numa descrição de produto, não pode passar.
      expect(
        CodePage850.codificar('A\x1Bp\x00B'),
        [0x41, 0x20, 0x70, 0x20, 0x42],
      );
    });
  });

  group('ComandosEscPos', () {
    test('QR nativo GS ( k: modelo 2, módulo, correção M, dados exatos', () {
      final c = ComandosEscPos()..qrCode('ABC', modulo: 5);
      expect(c.bytes, [
        0x1D, 0x28, 0x6B, 4, 0, 0x31, 0x41, 0x32, 0x00, // modelo 2
        0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x43, 5, // módulo 5
        0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x45, 0x31, // correção M
        0x1D, 0x28, 0x6B, 6, 0, 0x31, 0x50, 0x30, 0x41, 0x42, 0x43, // dados
        0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x51, 0x30, // imprime
      ]);
    });

    test('módulo fora de 3..8 é recusado', () {
      expect(
        () => ComandosEscPos().qrCode('x', modulo: 12),
        throwsArgumentError,
      );
    });
  });

  group('CupomEscPos', () {
    List<int> gerar(String nome) {
      final xml = File('test/fixtures/cupom_nfce/$nome.xml').readAsStringSync();
      final cupom = switch (CupomNfceXml.ler(xml)) {
        Ok(:final value) => value,
        Err(:final failure) => fail(failure.message),
      };
      return CupomEscPos.gerar(
        CupomLayout.montar(cupom),
        colunas: 48,
        moduloQr: 5,
      );
    }

    test('começa inicializando e escolhendo a PC850', () {
      final bytes = gerar('nfce-01-autorizada-nao-identificado');
      expect(bytes.sublist(0, 5), [0x1B, 0x40, 0x1B, 0x74, 2]);
    });

    test('QR com o texto exato do XML', () {
      final bytes = gerar('nfce-01-autorizada-nao-identificado');
      const qr =
          'https://mock.focusnfe.local/nfce/qrcode?p='
          '52261183876972000171650010000001011111111115|2|2';
      expect(_ocorrencias(bytes, qr.codeUnits), 1);
    });

    test('contingência pendente: 2 QR e 2 cortes (entre as vias e no fim)', () {
      final bytes = gerar('nfce-04-contingencia-pendente');
      const imprimeQr = [0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x51, 0x30];
      expect(_ocorrencias(bytes, imprimeQr), 2);
      expect(_ocorrencias(bytes, _corte), 2);
    });

    test('nota normal: 1 corte, no fim', () {
      final bytes = gerar('nfce-02-autorizada-cpf-producao');
      expect(_ocorrencias(bytes, _corte), 1);
      expect(bytes.sublist(bytes.length - 4), _corte);
    });
  });
}
