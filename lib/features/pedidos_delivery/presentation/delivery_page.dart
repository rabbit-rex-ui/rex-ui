import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/novo_pedido_form.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/pedidos_tab.dart';

/// Abas do workspace de delivery. A visibilidade de cada uma é decidida pela
/// permissão real do token (átomos independentes — nunca inferir uma da outra).
enum _DeliveryTab { criar, pedidos }

/// Abre o workspace de delivery como diálogo full-screen sobre o PDV (mesma
/// casca da criação anterior: Esc fecha, volta pro caixa).
///
/// [podeCriar] = `sls.order.create`; [podeVer] = `sls.order.view_own ||
/// view_all`. O chamador (botão do topbar) resolve ambos do token e só abre se
/// houver ao menos um. [defaultWarehouseId] alimenta a aba de criação.
Future<void> showDeliveryDialog(
  BuildContext context, {
  required bool podeCriar,
  required bool podeVer,
  required String defaultWarehouseId,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Delivery',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (_, _, _) => _DeliveryDialog(
      podeCriar: podeCriar,
      podeVer: podeVer,
      defaultWarehouseId: defaultWarehouseId,
    ),
    transitionBuilder: (_, anim, _, child) {
      final t = CurvedAnimation(parent: anim, curve: Curves.easeOut).value;
      return Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.98 + 0.02 * t, child: child),
      );
    },
  );
}

class _DeliveryDialog extends StatefulWidget {
  const _DeliveryDialog({
    required this.podeCriar,
    required this.podeVer,
    required this.defaultWarehouseId,
  });

  final bool podeCriar;
  final bool podeVer;
  final String defaultWarehouseId;

  @override
  State<_DeliveryDialog> createState() => _DeliveryDialogState();
}

class _DeliveryDialogState extends State<_DeliveryDialog> {
  late final List<_DeliveryTab> _abas = [
    if (widget.podeCriar) _DeliveryTab.criar,
    if (widget.podeVer) _DeliveryTab.pedidos,
  ];

  /// Key para acionar a recarga da fila quando a aba Pedidos fica ativa.
  final _pedidosKey = GlobalKey<PedidosTabState>();

  int _ativa = 0;

  @override
  void initState() {
    super.initState();
    if (_abas.isNotEmpty && _abas[_ativa] == _DeliveryTab.pedidos) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recarregarFila());
    }
  }

  void _fechar() => Navigator.of(context).pop();

  void _selecionar(int i) {
    if (i == _ativa) return;
    setState(() => _ativa = i);
    if (_abas[i] == _DeliveryTab.pedidos) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recarregarFila());
    }
  }

  void _recarregarFila() => _pedidosKey.currentState?.recarregar();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context).size;
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 1040,
            maxHeight: media.height * 0.9,
          ),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): _fechar,
            },
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  _header(colors),
                  Expanded(child: _corpo(colors)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppColors colors) {
    final multiAbas = _abas.length > 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 18, 16, multiAbas ? 0 : 18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Icon(LucideIcons.truck, size: 19, color: colors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pedidos de entrega: criação e acompanhamento.',
                      style: TextStyle(fontSize: 12, color: colors.textMute),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fechar (Esc)',
                onPressed: _fechar,
                icon: Icon(LucideIcons.x, size: 20, color: colors.textMute),
              ),
            ],
          ),
          if (multiAbas) ...[const SizedBox(height: 10), _tabBar(colors)],
        ],
      ),
    );
  }

  /// Barra de abas estilo fichário. Sem `Stack`: um `Container` com borda
  /// inferior (linha de base da faixa) e um `Row` de abas ancoradas embaixo.
  ///
  /// A aba ATIVA é a destacada — mais alta, preenchida com `surface2`, borda e
  /// ícone em accent; a INATIVA fica achatada, transparente e muda. (O esquema
  /// anterior pintava a ativa com `surface`, igual ao fundo do cabeçalho, e por
  /// isso ela ficava invisível: via-se só a inativa, com o rótulo oposto ao
  /// conteúdo.)
  Widget _tabBar(AppColors colors) {
    return Container(
      height: 37,
      width: double.infinity,
      alignment: Alignment.bottomLeft,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _abas.length; i++) ...[
            _tab(_abas[i], i == _ativa, () => _selecionar(i), colors),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _tab(
    _DeliveryTab aba,
    bool ativa,
    VoidCallback onTap,
    AppColors colors,
  ) {
    final fg = ativa ? colors.text : colors.textMute;
    return GestureDetector(
      onTap: ativa ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: ativa ? 36 : 30,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ativa ? colors.surface2 : Colors.transparent,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(9),
            topRight: Radius.circular(9),
          ),
          // Borda uniforme (borda não-uniforme + borderRadius estoura no paint).
          border: Border.all(color: ativa ? colors.border : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_tabIcon(aba), size: 15, color: ativa ? colors.accent : fg),
            const SizedBox(width: 7),
            Text(
              _tabLabel(aba),
              style: TextStyle(
                fontSize: 13,
                fontWeight: ativa ? FontWeight.w600 : FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corpo(AppColors colors) {
    if (_abas.isEmpty) return _semAcesso(colors);
    return IndexedStack(
      index: _ativa.clamp(0, _abas.length - 1),
      children: [for (final a in _abas) _painel(a)],
    );
  }

  Widget _painel(_DeliveryTab aba) => switch (aba) {
    _DeliveryTab.criar => NovoPedidoForm(
      defaultWarehouseId: widget.defaultWarehouseId,
    ),
    _DeliveryTab.pedidos => PedidosTab(key: _pedidosKey),
  };

  Widget _semAcesso(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.lock, size: 34, color: colors.textDim),
            const SizedBox(height: 12),
            Text(
              'Sem acesso ao delivery',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textMute,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Seu perfil não tem permissão para criar ou ver pedidos.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.textDim),
            ),
          ],
        ),
      ),
    );
  }

  IconData _tabIcon(_DeliveryTab a) => switch (a) {
    _DeliveryTab.criar => LucideIcons.packagePlus,
    _DeliveryTab.pedidos => LucideIcons.clipboardList,
  };

  String _tabLabel(_DeliveryTab a) => switch (a) {
    _DeliveryTab.criar => 'Novo pedido',
    _DeliveryTab.pedidos => 'Pedidos',
  };
}
