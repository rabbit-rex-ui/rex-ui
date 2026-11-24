import 'package:rabbit_pdv/features/fiscal/data/dto/nota_fiscal_response.dart';

/// JSON de nota no formato do guia fiscal §4, com sobrescritas por teste.
Map<String, dynamic> notaJson({
  String id = 'nota-1',
  String status = 'AUTHORIZED',
  String modelo = 'NFCE',
  DateTime? cancelavelAte,
  bool cancelamentoEmAndamento = false,
  bool requerAtencao = false,
}) {
  final limite =
      cancelavelAte ?? DateTime.now().toUtc().add(const Duration(minutes: 30));
  return {
    'id': id,
    'vendaId': 'venda-1',
    'modelo': modelo,
    'status': status,
    'modoEmissao': 'NORMAL',
    'serie': 1,
    'numero': 123,
    'chaveAcesso': '52261183876972000171650010000001231234567890',
    'protocolo': '126000000123456',
    'emitidaEm': '2026-11-19T14:03:27.123456Z',
    'autorizadaEm': '2026-11-19T14:03:29.402311Z',
    if (status == 'AUTHORIZED') 'cancelavelAte': limite.toIso8601String(),
    'valorTotal': 19.80,
    'xmlDisponivel': true,
    'danfeDisponivel': true,
    'cancelamentoEmAndamento': cancelamentoEmAndamento,
    'requerAtencao': requerAtencao,
  };
}

NotaFiscalResponse nota({
  String id = 'nota-1',
  String status = 'AUTHORIZED',
  DateTime? cancelavelAte,
  bool cancelamentoEmAndamento = false,
}) => NotaFiscalResponse.fromJson(
  notaJson(
    id: id,
    status: status,
    cancelavelAte: cancelavelAte,
    cancelamentoEmAndamento: cancelamentoEmAndamento,
  ),
);
