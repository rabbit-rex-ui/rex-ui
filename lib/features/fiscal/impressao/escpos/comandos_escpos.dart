import 'dart:convert';
import 'dart:typed_data';

import 'package:rabbit_pdv/features/fiscal/cupom/cupom_layout.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/escpos/code_page_850.dart';

/// Montador dos poucos comandos ESC/POS que o cupom usa. Sem dependência de
/// terceiros: o conjunto é pequeno e assim controlamos code page e QR.
///
/// Referência: Epson ESC/POS Command Reference (TM-T20/T88), seguida também
/// pelas térmicas nacionais em modo ESC/POS (Elgin, Bematech, Daruma).
class ComandosEscPos {
  static const _esc = 0x1B;
  static const _gs = 0x1D;
  static const _lf = 0x0A;

  /// Módulo do QR (lado de cada "pixel" em pontos). Numa térmica de 203 dpi,
  /// 4 ou 5 dão ≥ 25 mm com a margem branca — meça uma vez com régua.
  static const moduloQrMinimo = 3;
  static const moduloQrMaximo = 8;

  final _bytes = BytesBuilder(copy: false);

  Uint8List get bytes => _bytes.toBytes();

  /// `ESC @` — volta a impressora ao estado padrão.
  void inicializar() => _comando([_esc, 0x40]);

  /// `ESC t n` — tabela de caracteres.
  void selecionarCodePage(int numero) => _comando([_esc, 0x74, numero]);

  /// `ESC a n` — alinhamento da linha.
  void alinhar(AlinhamentoLinha alinhamento) => _comando([
    _esc,
    0x61,
    alinhamento == AlinhamentoLinha.centro ? 1 : 0,
  ]);

  /// `ESC E n` — negrito.
  void negrito({required bool ligado}) =>
      _comando([_esc, 0x45, ligado ? 1 : 0]);

  /// Texto + quebra de linha, já convertido para a PC850.
  void linha(String texto) {
    _bytes.add(CodePage850.codificar(texto));
    _comando([_lf]);
  }

  /// `ESC d n` — avança [linhas] linhas.
  void avancar(int linhas) => _comando([_esc, 0x64, linhas]);

  /// QR Code nativo (`GS ( k`), modelo 2, correção **M** (guia §9.3). O
  /// [conteudo] vai byte a byte, sem alteração — na contingência ele carrega
  /// assinatura.
  void qrCode(String conteudo, {required int modulo}) {
    if (modulo < moduloQrMinimo || modulo > moduloQrMaximo) {
      throw ArgumentError.value(modulo, 'modulo', 'fora de 3..8');
    }
    final dados = utf8.encode(conteudo);
    final tamanho = dados.length + 3;
    _comando([_gs, 0x28, 0x6B, 4, 0, 0x31, 0x41, 0x32, 0x00]); // modelo 2
    _comando([_gs, 0x28, 0x6B, 3, 0, 0x31, 0x43, modulo]); // módulo
    _comando([_gs, 0x28, 0x6B, 3, 0, 0x31, 0x45, 0x31]); // correção M
    _comando([_gs, 0x28, 0x6B, tamanho & 0xFF, tamanho >> 8, 0x31, 0x50, 0x30]);
    _bytes.add(dados); // guarda os dados
    _comando([_gs, 0x28, 0x6B, 3, 0, 0x31, 0x51, 0x30]); // imprime
  }

  /// `GS V 66 n` — avança até a guilhotina (+ n) e faz corte parcial.
  void cortar() => _comando([_gs, 0x56, 0x42, 0x03]);

  void _comando(List<int> bytes) => _bytes.add(bytes);
}
