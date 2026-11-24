import 'dart:typed_data';

import 'package:rabbit_pdv/features/fiscal/impressao/escpos/tabelas_cp850.dart';

/// Converte texto Unicode para os bytes da code page PC850 da impressora
/// térmica (guia fiscal v2.3 §9.3). A PC850 tem os acentos do português, `º`
/// e `ª`.
///
/// Regra: **substituir, nunca falhar a impressão** — as descrições vêm do
/// cadastro e podem trazer qualquer caractere:
/// 1. ASCII imprimível passa direto;
/// 2. caractere de controle vira espaço — nunca deixa um texto injetar um
///    comando ESC/POS (ex.: abrir a gaveta);
/// 3. tipografia comum vira o equivalente simples (`–` → `-`, `…` → `...`);
/// 4. o que existe na PC850 vai com o byte dela (`ã` → 0xC6);
/// 5. letra latina de outra língua perde o acento (`ő` → `o`);
/// 6. o resto vira `?`.
abstract final class CodePage850 {
  /// `ESC t n` da PC850 no padrão Epson (o mais comum nas térmicas).
  static const numeroEscPos = 2;

  static const _interrogacao = 0x3F;
  static const _espaco = 0x20;

  /// Substituições do §9.3.
  static const _substituicoes = {
    0x2013: '-', // – travessão curto
    0x2014: '-', // — travessão
    0x201C: '"', // “
    0x201D: '"', // ”
    0x2018: "'", // ‘
    0x2019: "'", // ’
    0x2026: '...', // …
    0x2022: '*', // •
    0x00A0: ' ', // espaço não separável
  };

  static Uint8List codificar(String texto) {
    final saida = <int>[];
    for (final codigo in texto.runes) {
      _codificar(codigo, saida);
    }
    return Uint8List.fromList(saida);
  }

  static void _codificar(int codigo, List<int> saida) {
    if (codigo >= 0x20 && codigo < 0x7F) {
      saida.add(codigo);
      return;
    }
    if (codigo < 0x20 || codigo == 0x7F) {
      saida.add(_espaco);
      return;
    }
    final substituto = _substituicoes[codigo];
    if (substituto != null) {
      saida.addAll(substituto.codeUnits);
      return;
    }
    final byte = cp850PorCodigo[codigo];
    if (byte != null) {
      saida.add(byte);
      return;
    }
    final semAcento = semAcentoPorCodigo[codigo];
    saida.addAll(semAcento?.codeUnits ?? const [_interrogacao]);
  }
}
