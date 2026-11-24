import 'package:rabbit_pdv/features/fiscal/cupom/cupom_layout.dart';

/// Renderiza as linhas do cupom como texto puro de largura fixa — o mesmo
/// formato dos `*.esperado.txt` de `fixtures-cupom-nfce`. Serve para os testes
/// do conversor e para pré-visualizar o cupom sem impressora.
abstract final class CupomTexto {
  /// Marcador do QR (no papel, a impressora desenha o QR de verdade).
  static const marcadorQr =
      '[ QR CODE >= 25 mm com o conteúdo de infNFeSupl/qrCode ]';

  /// Marcador do corte entre as vias da contingência.
  static const marcadorCorte = '- - - - - corte - - - - -';

  static String renderizar(List<LinhaCupom> linhas, {required int colunas}) {
    final saida = <String>[];
    for (final linha in linhas) {
      switch (linha) {
        case LinhaTexto(:final texto, :final alinhamento):
          saida.add(
            alinhamento == AlinhamentoLinha.centro
                ? _centralizar(texto, colunas)
                : texto,
          );
        case LinhaSeparadora():
          saida.add('-' * colunas);
        case LinhaQrCode():
          for (final l in quebrarEmLinhas(marcadorQr, colunas)) {
            saida.add(_centralizar(l, colunas));
          }
        case LinhaCorte():
          saida.addAll(['', marcadorCorte, '']);
      }
    }
    return '${saida.join('\n')}\n';
  }

  static String _centralizar(String texto, int colunas) {
    final sobra = colunas - texto.length;
    return sobra <= 0 ? texto : '${' ' * (sobra ~/ 2)}$texto';
  }
}
