import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';

/// Ação de transição de um pedido de delivery (guia §4). Cada ação carrega seu
/// rótulo e o átomo de permissão exigido (`sls.order.*`), centralizando o
/// gating — a UI nunca repete essas strings.
///
/// Puro domínio: sem dependência de Flutter. Ícone e estilo são decididos na
/// camada de apresentação.
enum PedidoAcao {
  confirmar('Confirmar', 'sls.order.confirm'),
  separar('Separar', 'sls.order.separate'),
  conferir('Conferir', 'sls.order.confer'),
  faturar('Faturar', 'sls.order.invoice'),
  expedir('Expedir', 'sls.order.dispatch'),
  entregar('Entregar', 'sls.order.deliver'),
  concluir('Concluir', 'sls.order.conclude'),
  naoEntregue('Não entregue', 'sls.order.deliver'),
  pagamentoRecusado('Pagamento recusado', 'sls.order.deliver'),
  devolver('Devolver', 'sls.order.return'),
  cancelar('Cancelar', 'sls.order.cancel');

  const PedidoAcao(this.label, this.permissao);

  /// Rótulo legível em PT-BR para o botão de ação.
  final String label;

  /// Átomo de permissão exigido para a ação (verificado no token; o backend
  /// revalida). Guia §4.
  final String permissao;

  /// Ação destrutiva/de exceção — a UI a trata com menor destaque (ou estilo
  /// de alerta), nunca como CTA primária.
  bool get isDestrutiva =>
      this == PedidoAcao.cancelar ||
      this == PedidoAcao.naoEntregue ||
      this == PedidoAcao.pagamentoRecusado ||
      this == PedidoAcao.devolver;
}

/// Ações válidas a partir de cada estado, espelhando a máquina de estados
/// (guia §3). A primeira da lista é a progressão "feliz" (CTA primária); ações
/// de exceção/destrutivas vêm depois. Estados terminais devolvem lista vazia.
///
/// É o filtro por ESTADO; a UI combina com o filtro por PERMISSÃO
/// (`PedidoAcao.permissao` no token) para decidir o que realmente exibir.
extension PedidoStatusAcoes on PedidoStatus {
  List<PedidoAcao> get acoesDisponiveis => switch (this) {
    // `confirmar` é omitido de propósito: o passo RECEBIDO → CONFIRMANDO é
    // opcional (guia §3, "RECEBIDO → SEPARANDO é permitido direto") e, oferecido
    // junto com `separar`, criava um caminho onde o operador chegava ao
    // `conferir` sem ter separado. Mantemos o fluxo linear: separar antecede
    // conferir. O valor `PedidoAcao.confirmar` segue no enum para o caso de um
    // pedido chegar em CONFIRMANDO por outra via (web/retaguarda).
    PedidoStatus.recebido => const [PedidoAcao.separar, PedidoAcao.cancelar],
    PedidoStatus.confirmando => const [PedidoAcao.separar, PedidoAcao.cancelar],
    PedidoStatus.separando => const [PedidoAcao.conferir, PedidoAcao.cancelar],
    PedidoStatus.conferido => const [PedidoAcao.faturar, PedidoAcao.cancelar],
    PedidoStatus.aguardandoExpedicao => const [PedidoAcao.expedir],
    PedidoStatus.emRota => const [PedidoAcao.entregar, PedidoAcao.naoEntregue],
    PedidoStatus.entregue => const [
      PedidoAcao.concluir,
      PedidoAcao.pagamentoRecusado,
    ],
    PedidoStatus.naoEntregue => const [PedidoAcao.devolver],
    PedidoStatus.pagamentoRecusado => const [PedidoAcao.devolver],
    PedidoStatus.concluido => const [],
    PedidoStatus.cancelado => const [],
    PedidoStatus.devolvido => const [],
  };
}
