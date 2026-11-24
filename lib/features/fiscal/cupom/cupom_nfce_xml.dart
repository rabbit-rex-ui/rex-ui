import 'package:xml/xml.dart';

import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/fiscal/cupom/cupom_nfce.dart';

/// Lê o XML de uma NFC-e e devolve o conteúdo do cupom (guia fiscal v2.2
/// §9.2).
///
/// Aceita as duas raízes:
/// - `nfeProc` — nota autorizada (`NFe` + `protNFe`), como vem de
///   `GET /fis/notas/{id}/cupom`;
/// - `NFe` — contingência ainda não transmitida (balcão, Comunicador).
///
/// Ignora o que não usa (assinatura, impostos, grupos novos da Reforma
/// Tributária). Elemento obrigatório ausente → `Err`: **nunca** imprimir um
/// cupom incompleto.
abstract final class CupomNfceXml {
  static Result<CupomNfce, Failure> ler(String xml) {
    try {
      return Ok(_ler(XmlDocument.parse(xml).rootElement));
    } on XmlException catch (e) {
      return Err(ValidationFailure('XML da nota ilegível.', cause: e));
    } on _ElementoAusente catch (e) {
      return Err(
        ValidationFailure(
          'XML da nota incompleto (falta ${e.caminho}). O cupom não foi '
          'impresso.',
          cause: e,
        ),
      );
    }
  }
}

CupomNfce _ler(XmlElement raiz) {
  final autorizada = raiz.name.local == 'nfeProc';
  final nfe = autorizada ? _filho(raiz, 'NFe') : raiz;
  if (nfe.name.local != 'NFe') throw const _ElementoAusente('NFe');

  final inf = _filho(nfe, 'infNFe');
  final ide = _filho(inf, 'ide');
  final emit = _filho(inf, 'emit');
  final total = _filho(_filho(inf, 'total'), 'ICMSTot');
  final pag = _filho(inf, 'pag');
  final supl = _filho(nfe, 'infNFeSupl');
  final dest = _filhoOpcional(inf, 'dest');
  final infAdic = _filhoOpcional(inf, 'infAdic');
  final protNFe = autorizada ? _filhoOpcional(raiz, 'protNFe') : null;
  final infProt = protNFe == null ? null : _filho(protNFe, 'infProt');

  final itens = [for (final det in _filhos(inf, 'det')) _item(det)];
  if (itens.isEmpty) throw const _ElementoAusente('infNFe/det');

  final pagamentos = [for (final d in _filhos(pag, 'detPag')) _pagamento(d)];
  if (pagamentos.isEmpty) throw const _ElementoAusente('pag/detPag');

  return CupomNfce(
    emitente: _emitente(emit),
    itens: itens,
    totais: TotaisCupom(
      valorProdutos: _texto(total, 'vProd'),
      desconto: _textoOpcional(total, 'vDesc'),
      valorNota: _texto(total, 'vNF'),
      tributos: _textoOpcional(total, 'vTotTrib'),
    ),
    pagamentos: pagamentos,
    troco: _textoOpcional(pag, 'vTroco') ?? '0.00',
    urlConsulta: _texto(supl, 'urlChave'),
    chaveAcesso: _chave(inf),
    qrCode: _texto(supl, 'qrCode'),
    numero: _texto(ide, 'nNF'),
    serie: _texto(ide, 'serie'),
    emitidaEm: _texto(ide, 'dhEmi'),
    homologacao: _texto(ide, 'tpAmb') == '2',
    contingencia: _texto(ide, 'tpEmis') == '9',
    consumidor: dest == null ? null : _consumidor(dest),
    protocolo: infProt == null
        ? null
        : ProtocoloCupom(
            numero: _texto(infProt, 'nProt'),
            recebidoEm: _texto(infProt, 'dhRecbto'),
          ),
    informacoesComplementares: infAdic == null
        ? null
        : _textoOpcional(infAdic, 'infCpl'),
  );
}

EmitenteCupom _emitente(XmlElement emit) {
  final end = _filho(emit, 'enderEmit');
  return EmitenteCupom(
    razaoSocial: _texto(emit, 'xNome'),
    cnpj: _texto(emit, 'CNPJ'),
    inscricaoEstadual: _textoOpcional(emit, 'IE'),
    endereco: EnderecoCupom(
      logradouro: _texto(end, 'xLgr'),
      numero: _textoOpcional(end, 'nro'),
      complemento: _textoOpcional(end, 'xCpl'),
      bairro: _textoOpcional(end, 'xBairro'),
      municipio: _texto(end, 'xMun'),
      uf: _texto(end, 'UF'),
      cep: _textoOpcional(end, 'CEP'),
    ),
  );
}

ItemCupom _item(XmlElement det) {
  final numero = int.tryParse(det.getAttribute('nItem') ?? '');
  if (numero == null) throw const _ElementoAusente('det/@nItem');
  final prod = _filho(det, 'prod');
  return ItemCupom(
    numero: numero,
    codigo: _texto(prod, 'cProd'),
    descricao: _texto(prod, 'xProd'),
    quantidade: _texto(prod, 'qCom'),
    unidade: _texto(prod, 'uCom'),
    valorUnitario: _texto(prod, 'vUnCom'),
    valorTotal: _texto(prod, 'vProd'),
    desconto: _textoOpcional(prod, 'vDesc'),
  );
}

PagamentoCupom _pagamento(XmlElement detPag) => PagamentoCupom(
  codigo: _texto(detPag, 'tPag'),
  valor: _texto(detPag, 'vPag'),
  descricaoLivre: _textoOpcional(detPag, 'xPag'),
);

ConsumidorCupom _consumidor(XmlElement dest) => ConsumidorCupom(
  cpf: _textoOpcional(dest, 'CPF'),
  cnpj: _textoOpcional(dest, 'CNPJ'),
  nome: _textoOpcional(dest, 'xNome'),
);

/// Chave de acesso = `@Id` de `infNFe` sem o prefixo `NFe` (44 dígitos).
String _chave(XmlElement inf) {
  final id = inf.getAttribute('Id') ?? '';
  final chave = id.startsWith('NFe') ? id.substring(3) : '';
  if (chave.length != 44) throw const _ElementoAusente('infNFe/@Id');
  return chave;
}

// ── Navegação por nome local (o namespace portalfiscal não muda nada) ──

XmlElement? _filhoOpcional(XmlElement pai, String nome) {
  for (final e in pai.childElements) {
    if (e.name.local == nome) return e;
  }
  return null;
}

XmlElement _filho(XmlElement pai, String nome) =>
    _filhoOpcional(pai, nome) ??
    (throw _ElementoAusente('${pai.name.local}/$nome'));

Iterable<XmlElement> _filhos(XmlElement pai, String nome) =>
    pai.childElements.where((e) => e.name.local == nome);

String? _textoOpcional(XmlElement pai, String nome) {
  final texto = _filhoOpcional(pai, nome)?.innerText.trim();
  return texto == null || texto.isEmpty ? null : texto;
}

String _texto(XmlElement pai, String nome) =>
    _textoOpcional(pai, nome) ??
    (throw _ElementoAusente('${pai.name.local}/$nome'));

class _ElementoAusente implements Exception {
  const _ElementoAusente(this.caminho);
  final String caminho;

  @override
  String toString() => 'Elemento obrigatório ausente no XML: $caminho';
}
