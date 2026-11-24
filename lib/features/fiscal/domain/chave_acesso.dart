/// Chave de acesso (44 dígitos) em blocos de 4, como no DANFE e no cupom:
/// `5226 1183 8769 …`. Usada na tela e no papel — um lugar só.
String chaveAcessoEmBlocos(String chave) => [
  for (var i = 0; i < chave.length; i += 4)
    chave.substring(i, i + 4 > chave.length ? chave.length : i + 4),
].join(' ');
