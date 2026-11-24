import 'dart:typed_data';

import 'package:rabbit_pdv/features/fiscal/cupom/cupom_layout.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/escpos/code_page_850.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/escpos/comandos_escpos.dart';

/// Traduz as linhas do cupom ([CupomLayout]) em bytes ESC/POS para a térmica
/// (guia fiscal v2.3 §9.3). O conteúdo e a ordem já vêm decididos pelo
/// layout; aqui só entram alinhamento, negrito, QR nativo e corte.
abstract final class CupomEscPos {
  static Uint8List gerar(
    List<LinhaCupom> linhas, {
    required int colunas,
    required int moduloQr,
  }) {
    final c = ComandosEscPos()
      ..inicializar()
      ..selecionarCodePage(CodePage850.numeroEscPos);

    for (final linha in linhas) {
      switch (linha) {
        case LinhaTexto(:final texto, :final alinhamento, :final negrito):
          c
            ..alinhar(alinhamento)
            ..negrito(ligado: negrito)
            ..linha(texto);
          if (negrito) c.negrito(ligado: false);
        case LinhaSeparadora():
          c
            ..alinhar(AlinhamentoLinha.esquerda)
            ..linha('-' * colunas);
        case LinhaQrCode(:final conteudo):
          c
            ..alinhar(AlinhamentoLinha.centro)
            ..qrCode(conteudo, modulo: moduloQr)
            ..avancar(1);
        case LinhaCorte():
          // Entre as vias da contingência (guia §9.3).
          c
            ..avancar(3)
            ..cortar();
      }
    }

    return (c
          ..alinhar(AlinhamentoLinha.esquerda)
          ..avancar(3)
          ..cortar())
        .bytes;
  }
}
