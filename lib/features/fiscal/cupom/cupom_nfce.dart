/// Conteúdo de um cupom NFC-e (DANFE NFC-e), extraído do XML da nota (guia
/// fiscal v2.2 §9.2).
///
/// Regra de ouro: **copiar, não calcular**. Os valores ficam como TEXTO
/// decimal exatamente como vieram no XML (`"49.80"`, `"1.2350"`); só a
/// formatação para o papel acontece depois, no layout. Nada aqui é
/// recalculado — o que sai no papel é o que foi assinado.
class CupomNfce {
  const CupomNfce({
    required this.emitente,
    required this.itens,
    required this.totais,
    required this.pagamentos,
    required this.troco,
    required this.urlConsulta,
    required this.chaveAcesso,
    required this.qrCode,
    required this.numero,
    required this.serie,
    required this.emitidaEm,
    required this.homologacao,
    required this.contingencia,
    this.consumidor,
    this.protocolo,
    this.informacoesComplementares,
  });

  final EmitenteCupom emitente;
  final List<ItemCupom> itens;
  final TotaisCupom totais;
  final List<PagamentoCupom> pagamentos;

  /// `pag/vTroco`; `"0.00"` quando ausente (o troco sai sempre).
  final String troco;

  /// `infNFeSupl/urlChave`.
  final String urlConsulta;

  /// 44 dígitos (`@Id` de `infNFe` sem o prefixo `NFe`).
  final String chaveAcesso;

  /// `infNFeSupl/qrCode` — TEXTO EXATO. Na contingência leva assinatura: o
  /// app nunca gera nem altera.
  final String qrCode;

  /// `ide/nNF` e `ide/serie`, como no XML.
  final String numero;
  final String serie;

  /// `ide/dhEmi` como no XML, já no fuso da loja
  /// (`2026-11-19T11:03:27-03:00`). Não converter para o fuso do terminal.
  final String emitidaEm;

  /// `ide/tpAmb = 2`.
  final bool homologacao;

  /// `ide/tpEmis = 9` (contingência offline).
  final bool contingencia;

  /// `null` = consumidor não identificado (sem `dest`).
  final ConsumidorCupom? consumidor;

  /// `null` = sem `protNFe` (contingência ainda não transmitida).
  final ProtocoloCupom? protocolo;

  /// `infAdic/infCpl`.
  final String? informacoesComplementares;

  /// Contingência ainda não autorizada: 2 vias e "Pendente de autorização".
  bool get pendenteDeAutorizacao => contingencia && protocolo == null;
}

class EmitenteCupom {
  const EmitenteCupom({
    required this.razaoSocial,
    required this.cnpj,
    required this.endereco,
    this.inscricaoEstadual,
  });

  final String razaoSocial;
  final String cnpj; // 14 dígitos
  final String? inscricaoEstadual;
  final EnderecoCupom endereco;
}

class EnderecoCupom {
  const EnderecoCupom({
    required this.logradouro,
    required this.municipio,
    required this.uf,
    this.numero,
    this.complemento,
    this.bairro,
    this.cep,
  });

  final String logradouro;
  final String? numero;
  final String? complemento;
  final String? bairro;
  final String municipio;
  final String uf;
  final String? cep; // 8 dígitos
}

class ItemCupom {
  const ItemCupom({
    required this.numero,
    required this.codigo,
    required this.descricao,
    required this.quantidade,
    required this.unidade,
    required this.valorUnitario,
    required this.valorTotal,
    this.desconto,
  });

  /// `det/@nItem`.
  final int numero;
  final String codigo; // cProd
  final String descricao; // xProd
  final String quantidade; // qCom
  final String unidade; // uCom
  final String valorUnitario; // vUnCom
  final String valorTotal; // vProd
  final String? desconto; // vDesc
}

class TotaisCupom {
  const TotaisCupom({
    required this.valorProdutos,
    required this.valorNota,
    this.desconto,
    this.tributos,
  });

  final String valorProdutos; // ICMSTot/vProd
  final String? desconto; // ICMSTot/vDesc
  final String valorNota; // ICMSTot/vNF
  final String? tributos; // ICMSTot/vTotTrib (Lei 12.741)
}

class PagamentoCupom {
  const PagamentoCupom({
    required this.codigo,
    required this.valor,
    this.descricaoLivre,
  });

  final String codigo; // tPag
  final String valor; // vPag

  /// `xPag` — usado quando `tPag = 99` (Outros).
  final String? descricaoLivre;
}

class ConsumidorCupom {
  const ConsumidorCupom({this.cpf, this.cnpj, this.nome});

  final String? cpf;
  final String? cnpj;
  final String? nome;
}

class ProtocoloCupom {
  const ProtocoloCupom({required this.numero, required this.recebidoEm});

  final String numero; // nProt
  final String recebidoEm; // dhRecbto, como no XML
}
