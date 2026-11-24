import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/dialogs/pdv_dialog_kit.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/pedido_detalhe_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/pedido_delivery_repository.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/separar_controller.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/unidade_ui.dart';

/// Sub-view de separação (guia §4.3), empurrada dentro do detalhe. Recebe os
/// itens do detalhe já carregado; [onConcluido] volta ao detalhe (recarregado)
/// após separar; [onCancelar] volta sem enviar.
class SepararView extends StatefulWidget {
  const SepararView({
    super.key,
    required this.pedidoId,
    required this.orderNumber,
    required this.itens,
    required this.onConcluido,
    required this.onCancelar,
  });

  final String pedidoId;
  final int orderNumber;
  final List<ItemPedidoDetalhe> itens;
  final VoidCallback onConcluido;
  final VoidCallback onCancelar;

  @override
  State<SepararView> createState() => _SepararViewState();
}

class _SepararViewState extends State<SepararView> {
  late final SepararController _ctrl;
  final Map<int, TextEditingController> _qtdCtrls = {};

  @override
  void initState() {
    super.initState();
    _ctrl = SepararController(
      Modular.get<PedidoDeliveryRepository>(),
      widget.pedidoId,
      widget.itens,
    );
    for (final i in _ctrl.itens) {
      _qtdCtrls[i.lineNumber] = TextEditingController(text: _fmtInicial(i));
    }
  }

  @override
  void dispose() {
    for (final c in _qtdCtrls.values) {
      c.dispose();
    }
    _ctrl.dispose();
    super.dispose();
  }

  String _fmtInicial(SepararItemVm i) {
    final s = i.isWeighed
        ? i.qtdSeparada.toStringAsFixed(3)
        : i.qtdSeparada.toStringAsFixed(0);
    return s.replaceAll('.', ',');
  }

  double _parse(String t) =>
      double.tryParse(t.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _confirmar() async {
    final ok = await _ctrl.separar();
    if (!mounted) return;
    if (ok) widget.onConcluido();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _barraTopo(colors),
          Divider(height: 1, color: colors.border),
          Expanded(child: _lista(colors)),
          _rodape(colors),
        ],
      ),
    );
  }

  Widget _barraTopo(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancelar separação',
            onPressed: _ctrl.loading ? null : widget.onCancelar,
            icon: Icon(LucideIcons.arrowLeft, size: 20, color: colors.textMute),
          ),
          const SizedBox(width: 4),
          Text(
            'Separar pedido #${widget.orderNumber}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista(AppColors colors) {
    final itens = _ctrl.itens;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      itemCount: itens.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, idx) => _itemRow(itens[idx], colors),
    );
  }

  Widget _itemRow(SepararItemVm i, AppColors colors) {
    final unidade = UnidadeUi.rotulo(i.unitOfMeasure);
    final solicitada =
        (i.isWeighed
                ? i.qtySolicitada.toStringAsFixed(3)
                : i.qtySolicitada.toStringAsFixed(0))
            .replaceAll('.', ',');
    final solicitadaLabel = unidade.isEmpty
        ? 'Solicitado: $solicitada'
        : 'Solicitado: $solicitada $unidade';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#${i.lineNumber}',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.textDim,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        i.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  solicitadaLabel,
                  style: TextStyle(fontSize: 11.5, color: colors.textDim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 110, child: _campoQtd(i, unidade, colors)),
          const SizedBox(width: 10),
          _toggleIndisponivel(i, colors),
        ],
      ),
    );
  }

  Widget _campoQtd(SepararItemVm i, String unidade, AppColors colors) {
    final label = unidade.isEmpty ? 'QTD' : 'QTD ($unidade)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PdvFieldLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: _qtdCtrls[i.lineNumber],
          enabled: !i.indisponivel && !_ctrl.loading,
          keyboardType: TextInputType.numberWithOptions(decimal: i.isWeighed),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              i.isWeighed ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
            ),
          ],
          onChanged: (t) => _ctrl.setQtd(i.lineNumber, _parse(t)),
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: pdvInputDecoration(context, hint: '0'),
        ),
      ],
    );
  }

  Widget _toggleIndisponivel(SepararItemVm i, AppColors colors) {
    final on = i.indisponivel;
    return GestureDetector(
      onTap: _ctrl.loading
          ? null
          : () => _ctrl.setIndisponivel(i.lineNumber, !on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: on ? colors.dangerTint : colors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: on ? colors.danger.withValues(alpha: 0.4) : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? LucideIcons.packageX : LucideIcons.package,
              size: 15,
              color: on ? colors.danger : colors.textMute,
            ),
            const SizedBox(width: 6),
            Text(
              'Indisponível',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: on ? colors.danger : colors.textMute,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rodape(AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: colors.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_ctrl.erro != null) ...[
                PdvErrorBanner(_ctrl.erro!),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 120,
                    child: PdvGhostButton(
                      'Cancelar',
                      onTap: _ctrl.loading ? null : widget.onCancelar,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 220,
                    child: PdvPrimaryButton(
                      label: 'Confirmar separação',
                      icon: LucideIcons.check,
                      loading: _ctrl.loading,
                      enabled: _ctrl.podeConfirmar,
                      onTap: _confirmar,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
