import 'dart:typed_data';

import 'package:rabbit_pdv/features/fiscal/cupom/cupom_layout.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/escpos/code_page_850.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/escpos/comandos_escpos.dart';

/// Página de teste da térmica (diálogo "Impressoras"). Serve para:
/// - medir o QR com régua: com a margem branca, ≥ 25 mm (guia §9.1/§9.3);
/// - conferir as colunas: a régua precisa caber em UMA linha;
/// - conferir os acentos e as substituições da code page.
abstract final class PaginaTesteEscPos {
  static const conteudoQr = 'https://rabbit-rex.com/teste-de-impressao';

  static Uint8List gerar({required int colunas, required int moduloQr}) {
    final regua = List.generate(colunas, (i) => '${(i + 1) % 10}').join();
    final c = ComandosEscPos()
      ..inicializar()
      ..selecionarCodePage(CodePage850.numeroEscPos)
      ..alinhar(AlinhamentoLinha.centro)
      ..negrito(ligado: true)
      ..linha('TESTE DE IMPRESSÃO')
      ..negrito(ligado: false)
      ..linha('Rabbit Rex PDV')
      ..alinhar(AlinhamentoLinha.esquerda)
      ..linha('-' * colunas)
      ..linha('A régua abaixo deve caber em UMA linha ($colunas colunas):')
      ..linha(regua)
      ..linha('-' * colunas)
      ..linha('Acentos: Goiânia, Ação, Pão, Avó, Café, Útil')
      ..linha('Maiúsculas: ÇÃÕ ÁÉÍÓÚ ÂÊÔ À  Ordinais: 1ª 2º')
      ..linha('Substituídos: – “aspas” ‘simples’ … •')
      ..linha('-' * colunas)
      ..alinhar(AlinhamentoLinha.centro)
      ..qrCode(conteudoQr, modulo: moduloQr)
      ..avancar(1)
      ..linha('Meça o QR com a margem branca:')
      ..negrito(ligado: true)
      ..linha('mínimo 25 x 25 mm')
      ..negrito(ligado: false)
      ..linha('Módulo do QR: $moduloQr')
      ..avancar(3)
      ..cortar();
    return c.bytes;
  }
}
