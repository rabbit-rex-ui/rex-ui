import 'package:rabbit_pdv/features/fiscal/domain/nota_modelo.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';

/// Situação da nota que vale para a venda, embutida no pedido (`notaFiscal`
/// na listagem e no detalhe de `/pdv/pedidos`, guia fiscal v2.2 §7.1).
///
/// É a autorizada, se houver; senão a mais recente. Ausente por ~1 s logo
/// depois do faturar. Serve para a fila de expedição decidir imprimir/expedir
/// numa leitura só, sem consultar nota por nota.
class NotaFiscalResumo {
  const NotaFiscalResumo({
    required this.id,
    required this.modelo,
    required this.status,
    required this.aptaParaExpedir,
    required this.cancelamentoEmAndamento,
    required this.requerAtencao,
  });

  final String id;
  final NotaModelo modelo;
  final NotaStatus status;

  /// Mesma regra do `expedir`: autorizada e sem cancelamento em andamento.
  /// Use para habilitar o botão; o backend valida de novo (409).
  final bool aptaParaExpedir;
  final bool cancelamentoEmAndamento;
  final bool requerAtencao;

  factory NotaFiscalResumo.fromJson(Map<String, dynamic> json) =>
      NotaFiscalResumo(
        id: json['id'] as String,
        modelo: NotaModelo.fromWire(json['modelo'] as String),
        status: NotaStatus.fromWire(json['status'] as String),
        aptaParaExpedir: json['aptaParaExpedir'] as bool? ?? false,
        cancelamentoEmAndamento:
            json['cancelamentoEmAndamento'] as bool? ?? false,
        requerAtencao: json['requerAtencao'] as bool? ?? false,
      );

  /// Lê o campo opcional `notaFiscal` de um pedido.
  static NotaFiscalResumo? fromPedido(Map<String, dynamic> pedido) {
    final nota = pedido['notaFiscal'];
    return nota is Map<String, dynamic> ? NotaFiscalResumo.fromJson(nota) : null;
  }
}
