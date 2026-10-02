import 'package:flutter/widgets.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';

/// Cores de apresentação para a pílula de status. Mora em `presentation/`
/// porque cor é UI — o enum [PedidoStatus] é domínio puro (sem Flutter).
///
/// `fg` é a cor do texto/realce; `bg` é o fundo do chip (tint suave do tema).
/// Agrupado por natureza da etapa para leitura rápida na fila.
class PedidoStatusUi {
  const PedidoStatusUi(this.fg, this.bg);

  final Color fg;
  final Color bg;

  static PedidoStatusUi of(PedidoStatus status, AppColors colors) {
    return switch (status) {
      // Entrada / informativo
      PedidoStatus.recebido || PedidoStatus.confirmando => PedidoStatusUi(
        colors.accent,
        colors.accentTint,
      ),
      // Processamento interno (separação/conferência)
      PedidoStatus.separando ||
      PedidoStatus.conferido => PedidoStatusUi(colors.warn, colors.warnTint),
      // Em movimento (faturado→expedição→rota)
      PedidoStatus.aguardandoExpedicao ||
      PedidoStatus.emRota => PedidoStatusUi(colors.accent, colors.accentTint),
      // Desfecho positivo
      PedidoStatus.entregue || PedidoStatus.concluido => PedidoStatusUi(
        colors.success,
        colors.successTint,
      ),
      // Exceção / negativo
      PedidoStatus.cancelado ||
      PedidoStatus.naoEntregue ||
      PedidoStatus.pagamentoRecusado ||
      PedidoStatus.devolvido => PedidoStatusUi(
        colors.danger,
        colors.dangerTint,
      ),
    };
  }
}
