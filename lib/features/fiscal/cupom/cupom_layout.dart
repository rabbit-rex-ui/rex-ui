import 'package:rabbit_pdv/features/fiscal/cupom/cupom_nfce.dart';
import 'package:rabbit_pdv/features/fiscal/domain/chave_acesso.dart';

/// Uma linha do cupom já diagramada para N colunas. É a fronteira entre o
/// CONTEÚDO (este arquivo) e a IMPRESSORA: o renderizador de texto (testes,
/// pré-visualização) e o ESC/POS traduzem as mesmas linhas.
sealed class LinhaCupom {
  const LinhaCupom();
}

enum AlinhamentoLinha { esquerda, centro }

/// Texto com no máximo `colunas` caracteres.
final class LinhaTexto extends LinhaCupom {
  const LinhaTexto(
    this.texto, {
    this.alinhamento = AlinhamentoLinha.esquerda,
    this.negrito = false,
  });

  final String texto;
  final AlinhamentoLinha alinhamento;
  final bool negrito;
}

/// Linha tracejada de largura total.
final class LinhaSeparadora extends LinhaCupom {
  const LinhaSeparadora();
}

/// QR Code centralizado com o [conteudo] exato de `infNFeSupl/qrCode`.
final class LinhaQrCode extends LinhaCupom {
  const LinhaQrCode(this.conteudo);
  final String conteudo;
}

/// Corte de papel entre as vias da contingência.
final class LinhaCorte extends LinhaCupom {
  const LinhaCorte();
}

/// Diagrama o cupom NFC-e na ordem dos blocos do Manual do DANFE NFC-e (guia
/// fiscal v2.2 §9.2). Referência de conteúdo e ordem: os `*.esperado.txt` de
/// `fixtures-cupom-nfce`.
abstract final class CupomLayout {
  /// Fonte A em 80 mm. Alguns modelos têm 42.
  static const colunasPadrao = 48;

  /// Linhas de todas as vias. Contingência pendente de autorização sai em 2
  /// vias separadas por [LinhaCorte]; a segunda, "Via do Estabelecimento",
  /// fica na loja até a autorização.
  static List<LinhaCupom> montar(
    CupomNfce cupom, {
    int colunas = colunasPadrao,
  }) {
    if (!cupom.pendenteDeAutorizacao) {
      return _Via(cupom, colunas, viaEstabelecimento: false).montar();
    }
    return [
      ..._Via(cupom, colunas, viaEstabelecimento: false).montar(),
      const LinhaCorte(),
      ..._Via(cupom, colunas, viaEstabelecimento: true).montar(),
    ];
  }
}

/// Monta UMA via do cupom.
class _Via {
  _Via(this.cupom, this.colunas, {required this.viaEstabelecimento});

  final CupomNfce cupom;
  final int colunas;
  final bool viaEstabelecimento;
  final _linhas = <LinhaCupom>[];

  static const _tituloDocumento =
      'Documento Auxiliar da Nota Fiscal de Consumidor Eletrônica';
  static const _contingencia = 'EMITIDA EM CONTINGÊNCIA';
  static const _pendente = 'Pendente de autorização';
  static const _homologacao =
      'EMITIDA EM AMBIENTE DE HOMOLOGAÇÃO – SEM VALOR FISCAL';
  static const _recuoContinuacao = '    ';

  List<LinhaCupom> montar() {
    _cabecalho();
    _itens();
    _totais();
    _consulta();
    _linhas.add(LinhaQrCode(cupom.qrCode));
    _consumidor();
    _identificacao();
    _mensagensFiscais();
    final infCpl = cupom.informacoesComplementares;
    if (infCpl != null) _centro(infCpl);
    return List.unmodifiable(_linhas);
  }

  // I — Cabeçalho
  void _cabecalho() {
    final e = cupom.emitente;
    _centro(e.razaoSocial, negrito: true);
    final ie = e.inscricaoEstadual;
    _centro(
      ie == null ? 'CNPJ ${_cnpj(e.cnpj)}' : 'CNPJ ${_cnpj(e.cnpj)}  IE $ie',
    );
    _centro(_endereco(e.endereco));
    _centro(_tituloDocumento);
    _avisoContingencia();
    _linhas.add(const LinhaSeparadora());
  }

  // II — Itens (sempre todos). Descrição longa quebra por palavra, com a
  // continuação recuada — nada se perde (guia v2.3 §9.2).
  void _itens() {
    for (final item in cupom.itens) {
      _esquerda(
        '${item.numero.toString().padLeft(3, '0')} ${item.descricao}',
        recuo: _recuoContinuacao,
      );
      _esquerdaDireita(
        '${item.codigo}  ${_quantidade(item.quantidade)} ${item.unidade} '
        'x ${_moeda(item.valorUnitario)}',
        _moeda(item.valorTotal),
      );
      final desconto = item.desconto;
      if (_positivo(desconto)) {
        _esquerdaDireita('    desconto', '-${_moeda(desconto!)}');
      }
    }
    _linhas.add(const LinhaSeparadora());
  }

  // III — Totais, pagamento e troco
  void _totais() {
    final t = cupom.totais;
    _esquerdaDireita('Qtde. total de itens', '${cupom.itens.length}');
    _esquerdaDireita('Valor total R\$', _moeda(t.valorProdutos));
    final desconto = t.desconto;
    if (_positivo(desconto)) {
      _esquerdaDireita('Descontos R\$', '-${_moeda(desconto!)}');
      _esquerdaDireita('Valor a pagar R\$', _moeda(t.valorNota));
    }
    _esquerdaDireita('FORMA DE PAGAMENTO', 'VALOR PAGO R\$');
    for (final p in cupom.pagamentos) {
      _esquerdaDireita(_descricaoPagamento(p), _moeda(p.valor));
    }
    _esquerdaDireita('Troco R\$', _moeda(cupom.troco));
    final tributos = t.tributos;
    if (tributos != null) {
      _centro(
        'Tributos totais incidentes (Lei Federal 12.741/2012): '
        'R\$ ${_moeda(tributos)}',
      );
    }
    _linhas.add(const LinhaSeparadora());
  }

  // IV — Consulta pela chave
  void _consulta() {
    _centro('Consulte pela Chave de Acesso em');
    _centro(cupom.urlConsulta);
    _centro(chaveAcessoEmBlocos(cupom.chaveAcesso));
  }

  // VI — Consumidor
  void _consumidor() {
    final c = cupom.consumidor;
    final cpf = c?.cpf;
    final cnpj = c?.cnpj;
    if (cpf != null) {
      _centro('CONSUMIDOR CPF ${_cpf(cpf)}');
    } else if (cnpj != null) {
      _centro('CONSUMIDOR CNPJ ${_cnpj(cnpj)}');
    } else if (c?.nome == null) {
      _centro('CONSUMIDOR NÃO IDENTIFICADO');
      return;
    } else {
      _centro('CONSUMIDOR');
    }
    final nome = c?.nome;
    if (nome != null) _centro(nome);
  }

  // VII — Identificação da nota e protocolo
  void _identificacao() {
    _centro(
      'NFC-e nº ${_numeroNota(cupom.numero)} '
      'Série ${cupom.serie.padLeft(3, '0')}',
      negrito: true,
    );
    final via = viaEstabelecimento ? ' - Via do Estabelecimento' : '';
    _centro('${_dataHora(cupom.emitidaEm)}$via');
    final protocolo = cupom.protocolo;
    if (protocolo != null) {
      _centro('Protocolo de autorização: ${protocolo.numero}');
      _centro('Data de autorização: ${_dataHora(protocolo.recebidoEm)}');
    }
    _avisoContingencia();
  }

  // VIII — Mensagens fiscais
  void _mensagensFiscais() {
    if (!cupom.homologacao) return;
    _linhas.add(const LinhaSeparadora());
    _centro(_homologacao, negrito: true);
  }

  /// Sai abaixo do cabeçalho e abaixo da identificação (guia §9.2).
  void _avisoContingencia() {
    if (!cupom.contingencia) return;
    _centro(_contingencia, negrito: true);
    if (cupom.pendenteDeAutorizacao) _centro(_pendente, negrito: true);
  }

  // ── Primitivas de diagramação ──

  void _centro(String texto, {bool negrito = false}) {
    for (final linha in quebrarEmLinhas(texto, colunas)) {
      _linhas.add(
        LinhaTexto(
          linha,
          alinhamento: AlinhamentoLinha.centro,
          negrito: negrito,
        ),
      );
    }
  }

  void _esquerda(String texto, {String recuo = ''}) {
    for (final linha in quebrarEmLinhas(texto, colunas, recuo: recuo)) {
      _linhas.add(LinhaTexto(linha));
    }
  }

  /// Rótulo à esquerda e valor à direita na mesma linha. Se não couber, o
  /// rótulo quebra e o valor vai alinhado à direita na linha seguinte.
  void _esquerdaDireita(String esquerda, String direita) {
    final espaco = colunas - esquerda.length - direita.length;
    if (espaco >= 1) {
      _linhas.add(LinhaTexto('$esquerda${' ' * espaco}$direita'));
      return;
    }
    _esquerda(esquerda);
    _linhas.add(LinhaTexto(direita.padLeft(colunas)));
  }
}

/// Quebra por palavra em linhas de no máximo [colunas]; palavra maior que a
/// linha (ex.: URL) é cortada em pedaços. Espaços duplos internos são
/// preservados. A partir da 2ª linha, cada uma começa com [recuo] (que conta
/// na largura).
List<String> quebrarEmLinhas(String texto, int colunas, {String recuo = ''}) {
  final linhas = <String>[];
  var atual = '';

  int largura() => linhas.isEmpty ? colunas : colunas - recuo.length;
  void fecharLinha() {
    linhas.add('${linhas.isEmpty ? '' : recuo}${atual.trimRight()}');
    atual = '';
  }

  for (final palavraOriginal in texto.split(' ')) {
    var palavra = palavraOriginal;
    while (palavra.length > largura()) {
      if (atual.trim().isNotEmpty) fecharLinha();
      final corte = largura();
      atual = palavra.substring(0, corte);
      fecharLinha();
      palavra = palavra.substring(corte);
    }
    if (atual.isEmpty) {
      atual = palavra;
    } else if (atual.length + 1 + palavra.length <= largura()) {
      atual = '$atual $palavra';
    } else {
      fecharLinha();
      atual = palavra;
    }
  }
  if (atual.trim().isNotEmpty) fecharLinha();
  return linhas;
}

// ── Formatação (só apresentação; os valores vêm prontos do XML) ──

/// Descrição da forma de pagamento (guia §9.2). `99` usa o `xPag`; código
/// desconhecido vira "Outros".
String _descricaoPagamento(PagamentoCupom p) {
  if (p.codigo == '99') return p.descricaoLivre ?? 'Outros';
  return _formasPagamento[p.codigo] ?? 'Outros';
}

const _formasPagamento = {
  '01': 'Dinheiro',
  '02': 'Cheque',
  '03': 'Cartão de Crédito',
  '04': 'Cartão de Débito',
  '05': 'Crédito Loja',
  '10': 'Vale Alimentação',
  '11': 'Vale Refeição',
  '12': 'Vale Presente',
  '13': 'Vale Combustível',
  '15': 'Boleto Bancário',
  '16': 'Depósito Bancário',
  '17': 'PIX',
  '18': 'Transferência / Carteira Digital',
  '19': 'Fidelidade / Cashback',
  '90': 'Sem pagamento',
};

/// `"1234.5"` → `"1.234,50"`. Casas além da 2ª só aparecem se forem
/// significativas (`vUnCom` aceita até 10): `"5.9950000000"` → `"5,995"`. Não
/// arredonda — copia.
String _moeda(String decimal) {
  var s = decimal.trim();
  final negativo = s.startsWith('-');
  if (negativo) s = s.substring(1);
  final partes = s.split('.');
  final inteiro = partes[0].isEmpty ? '0' : partes[0];
  var fracao = partes.length > 1 ? partes[1] : '';
  while (fracao.length > 2 && fracao.endsWith('0')) {
    fracao = fracao.substring(0, fracao.length - 1);
  }
  fracao = fracao.padRight(2, '0');
  return '${negativo ? '-' : ''}${_milhares(inteiro)},$fracao';
}

String _milhares(String digitos) {
  final b = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) b.write('.');
    b.write(digitos[i]);
  }
  return b.toString();
}

/// `qCom` (até 4 casas): zeros à direita somem, sem arredondar —
/// `"2.0000"` → `"2"`; `"1.2345"` → `"1,2345"`; `"1500.5"` → `"1.500,5"`.
String _quantidade(String decimal) {
  final partes = decimal.trim().split('.');
  var fracao = partes.length > 1 ? partes[1] : '';
  while (fracao.endsWith('0')) {
    fracao = fracao.substring(0, fracao.length - 1);
  }
  final inteiro = _milhares(partes[0]);
  return fracao.isEmpty ? inteiro : '$inteiro,$fracao';
}

bool _positivo(String? decimal) =>
    decimal != null && (double.tryParse(decimal) ?? 0) > 0;

/// Data/hora como está no XML, sem converter fuso:
/// `2026-11-19T11:03:27-03:00` → `19/11/2026 11:03:27`.
String _dataHora(String iso) {
  if (iso.length < 19) return iso;
  return '${iso.substring(8, 10)}/${iso.substring(5, 7)}/'
      '${iso.substring(0, 4)} ${iso.substring(11, 19)}';
}

/// `"101"` → `"000.000.101"`.
String _numeroNota(String nNF) {
  final n = nNF.padLeft(9, '0');
  if (n.length != 9) return nNF;
  return '${n.substring(0, 3)}.${n.substring(3, 6)}.${n.substring(6)}';
}

String _cnpj(String c) => c.length != 14
    ? c
    : '${c.substring(0, 2)}.${c.substring(2, 5)}.${c.substring(5, 8)}/'
          '${c.substring(8, 12)}-${c.substring(12)}';

String _cpf(String c) => c.length != 11
    ? c
    : '${c.substring(0, 3)}.${c.substring(3, 6)}.${c.substring(6, 9)}-'
          '${c.substring(9)}';

/// `Avenida Goiás, 1000, Setor Central, Goiânia - GO, CEP 74005-010`.
String _endereco(EnderecoCupom e) {
  final partes = [
    e.logradouro,
    e.numero,
    e.complemento,
    e.bairro,
  ].whereType<String>().toList();
  partes.add('${e.municipio} - ${e.uf}');
  final cep = e.cep;
  if (cep != null) {
    partes.add(
      cep.length == 8 ? 'CEP ${cep.substring(0, 5)}-${cep.substring(5)}' : cep,
    );
  }
  return partes.join(', ');
}
