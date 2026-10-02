import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/pedido_resumo_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/pedido_delivery_repository.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_canal.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/pedido_detalhe_view.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/pedido_status_ui.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/pedidos_lista_controller.dart';

/// Aba "Pedidos": fila paginada por status (guia §4.12) com sub-view de detalhe
/// empurrada por cima (sem descartar a fila). Carrega no open; recarrega pelo
/// botão "Recarregar".
class PedidosTab extends StatefulWidget {
  const PedidosTab({super.key});

  @override
  State<PedidosTab> createState() => _PedidosTabState();
}

class _PedidosTabState extends State<PedidosTab>
    with AutomaticKeepAliveClientMixin {
  late final PedidosListaController _ctrl;

  /// Id do pedido aberto no detalhe; null = mostrando a fila.
  String? _abertoId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ctrl = PedidosListaController(Modular.get<PedidoDeliveryRepository>());
    _ctrl.recarregar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _abrir(PedidoResumoResponse p) => setState(() => _abertoId = p.pedidoId);

  void _voltar() => setState(() => _abertoId = null);

  @override
  Widget build(BuildContext context) {
    super.build(context); // keep-alive
    final colors = context.colors;

    final abertoId = _abertoId;
    if (abertoId != null) {
      return PedidoDetalheView(pedidoId: abertoId, onVoltar: _voltar);
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filtros(colors),
          Divider(height: 1, color: colors.border),
          Expanded(child: _conteudo(colors)),
        ],
      ),
    );
  }

  Widget _filtros(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in FilaPedido.values)
                  _chipFila(f, _ctrl.fila == f, colors),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Recarregar',
            onPressed: _ctrl.loading ? null : _ctrl.recarregar,
            icon: Icon(LucideIcons.refreshCw, size: 18, color: colors.textMute),
          ),
        ],
      ),
    );
  }

  Widget _chipFila(FilaPedido f, bool selected, AppColors colors) {
    return GestureDetector(
      onTap: _ctrl.loading ? null : () => _ctrl.selecionarFila(f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? colors.accent : colors.border),
        ),
        child: Text(
          f.label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colors.accentInk : colors.text,
          ),
        ),
      ),
    );
  }

  Widget _conteudo(AppColors colors) {
    if (_ctrl.loading) {
      return Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(colors.accent),
          ),
        ),
      );
    }
    if (_ctrl.erro != null) return _erroState(_ctrl.erro!, colors);
    if (_ctrl.vazio) return _vazioState(colors);

    final itens = _ctrl.itens;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      itemCount: itens.length + (_ctrl.temMais ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, idx) {
        if (idx >= itens.length) return _carregarMais(colors);
        return _card(itens[idx], colors);
      },
    );
  }

  Widget _card(PedidoResumoResponse p, AppColors colors) {
    return Material(
      color: colors.surface2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _abrir(p),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Text(
                '#${p.orderNumber}',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textMute,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.customerName.isEmpty
                          ? 'Cliente não informado'
                          : p.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.canal.label,
                      style: TextStyle(fontSize: 11.5, color: colors.textDim),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _statusPill(p.status, colors),
              const SizedBox(width: 12),
              Text(
                BrlFormatter.format(p.valorEstimado),
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight, size: 18, color: colors.textDim),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(PedidoStatus s, AppColors colors) {
    final ui = PedidoStatusUi.of(s, colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ui.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ui.fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        s.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: ui.fg,
        ),
      ),
    );
  }

  Widget _carregarMais(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _ctrl.carregandoMais
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(colors.accent),
                ),
              )
            : GestureDetector(
                onTap: _ctrl.carregarMais,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Carregar mais',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _vazioState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.inbox, size: 34, color: colors.textDim),
          const SizedBox(height: 10),
          Text(
            'Nenhum pedido nesta fila',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: colors.textMute,
            ),
          ),
        ],
      ),
    );
  }

  Widget _erroState(String msg, AppColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.circleAlert, size: 34, color: colors.danger),
          const SizedBox(height: 10),
          Text(
            'Não foi possível carregar',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.textMute),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _ctrl.recarregar,
            child: Text(
              'Tentar de novo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
