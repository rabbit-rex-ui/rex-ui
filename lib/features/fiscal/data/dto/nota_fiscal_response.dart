import 'package:rabbit_pdv/core/json/json_read.dart';
import 'package:rabbit_pdv/features/fiscal/domain/modo_emissao.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_modelo.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';

/// Nota fiscal (NF-e ou NFC-e) como o backend a devolve (guia fiscal §4).
///
/// Campos nulos são omitidos do JSON pelo backend; aqui viram `null`. Vários
/// só existem em certos estados — ver o comentário de cada um.
class NotaFiscalResponse {
  const NotaFiscalResponse({
    required this.id,
    required this.vendaId,
    required this.modelo,
    required this.status,
    required this.modoEmissao,
    required this.emitidaEm,
    required this.valorTotal,
    required this.xmlDisponivel,
    required this.danfeDisponivel,
    required this.cancelamentoEmAndamento,
    required this.requerAtencao,
    this.serie,
    this.numero,
    this.chaveAcesso,
    this.protocolo,
    this.destinatarioDocumento,
    this.destinatarioNome,
    this.autorizadaEm,
    this.cancelavelAte,
    this.codigoRejeicao,
    this.motivoRejeicao,
    this.canceladaEm,
    this.motivoCancelamento,
  });

  final String id;
  final String vendaId;
  final NotaModelo modelo;
  final NotaStatus status;

  final ModoEmissao modoEmissao;

  /// Quando a emissão foi solicitada (fuso local).
  final DateTime emitidaEm;
  final double valorTotal;
  final bool xmlDisponivel;
  final bool danfeDisponivel;

  /// O cancelamento foi pedido mas a SEFAZ não respondeu (503). A nota segue
  /// autorizada, porém não pode ser expedida (guia §8.4).
  final bool cancelamentoEmAndamento;

  /// Nota presa que a reconciliação não resolveu sozinha (guia §8.5).
  final bool requerAtencao;

  // ── Só em AUTHORIZED / CANCELLED ──
  final int? serie;
  final int? numero;

  /// 44 dígitos.
  final String? chaveAcesso;

  /// 15 dígitos.
  final String? protocolo;

  // ── Se informado na venda ──
  final String? destinatarioDocumento;
  final String? destinatarioNome;

  // ── Só em AUTHORIZED ──
  final DateTime? autorizadaEm;

  /// Limite para cancelar. O backend só envia em AUTHORIZED; o prazo é
  /// configurável (NF-e 24 h, NFC-e 30 min) — use sempre este campo.
  final DateTime? cancelavelAte;

  // ── Só em DENIED ──
  final String? codigoRejeicao; // cStat
  final String? motivoRejeicao;

  // ── Só em CANCELLED ──
  final DateTime? canceladaEm;
  final String? motivoCancelamento;

  bool get emContingencia => modoEmissao.emContingencia;

  /// Ainda falta um desfecho da SEFAZ: emissão sem resposta ou cancelamento
  /// em andamento. Enquanto for `true`, vale acompanhar por polling.
  bool get precisaAcompanhar =>
      status.emProcessamento || cancelamentoEmAndamento;

  /// Pode receber um pedido de cancelamento agora (guia §8.3). Passe o
  /// [agora] do relógio do SERVIDOR (`RelogioServidor.agora()`), não o do
  /// terminal. Não considera permissão — isso é do operador, não da nota.
  bool cancelavelEm(DateTime agora) {
    final limite = cancelavelAte;
    return status == NotaStatus.autorizada &&
        !cancelamentoEmAndamento &&
        limite != null &&
        agora.isBefore(limite);
  }

  factory NotaFiscalResponse.fromJson(Map<String, dynamic> json) =>
      NotaFiscalResponse(
        id: json['id'] as String,
        vendaId: json['vendaId'] as String,
        modelo: NotaModelo.fromWire(json['modelo'] as String),
        status: NotaStatus.fromWire(json['status'] as String),
        modoEmissao: ModoEmissao.fromWire(json['modoEmissao'] as String?),
        emitidaEm: JsonRead.instant(json['emitidaEm']),
        valorTotal: JsonRead.decimal(json['valorTotal']),
        xmlDisponivel: json['xmlDisponivel'] as bool? ?? false,
        danfeDisponivel: json['danfeDisponivel'] as bool? ?? false,
        cancelamentoEmAndamento:
            json['cancelamentoEmAndamento'] as bool? ?? false,
        requerAtencao: json['requerAtencao'] as bool? ?? false,
        serie: (json['serie'] as num?)?.toInt(),
        numero: (json['numero'] as num?)?.toInt(),
        chaveAcesso: json['chaveAcesso'] as String?,
        protocolo: json['protocolo'] as String?,
        destinatarioDocumento: json['destinatarioDocumento'] as String?,
        destinatarioNome: json['destinatarioNome'] as String?,
        autorizadaEm: JsonRead.instantOrNull(json['autorizadaEm']),
        cancelavelAte: JsonRead.instantOrNull(json['cancelavelAte']),
        // cStat: tolerante a número ou texto (o contrato só diz "string").
        codigoRejeicao: json['codigoRejeicao']?.toString(),
        motivoRejeicao: json['motivoRejeicao'] as String?,
        canceladaEm: JsonRead.instantOrNull(json['canceladaEm']),
        motivoCancelamento: json['motivoCancelamento'] as String?,
      );
}
