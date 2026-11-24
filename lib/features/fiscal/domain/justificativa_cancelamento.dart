/// Regra da justificativa de cancelamento (guia fiscal §6.2): vai para a
/// SEFAZ e precisa ter de 15 a 255 caracteres. O backend valida de novo
/// (400 `justificativa-invalida`); validamos aqui para não gastar a ida.
abstract final class JustificativaCancelamento {
  static const minimo = 15;
  static const maximo = 255;

  /// Mensagem de erro para a tela, ou `null` se o texto é válido. Conta o
  /// texto sem espaços nas pontas — é o que será enviado.
  static String? validar(String texto) {
    final tamanho = texto.trim().length;
    if (tamanho < minimo) {
      return 'A justificativa precisa de pelo menos $minimo caracteres.';
    }
    if (tamanho > maximo) {
      return 'A justificativa pode ter no máximo $maximo caracteres.';
    }
    return null;
  }
}
