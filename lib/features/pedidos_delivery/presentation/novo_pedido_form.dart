import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/format/moeda_input_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/domain/entities/produto.dart';
import 'package:rabbit_pdv/domain/repositories/produtos_repository.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/dialogs/pdv_dialog_kit.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/pedido_delivery_repository.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/item_pedido_cart.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/momento_pagamento.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_canal.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/novo_pedido_controller.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/unidade_ui.dart';

/// Corpo do formulário de criação de pedido de delivery, para hospedar dentro
/// da aba "Novo pedido" do workspace de delivery.
///
/// Gerencia o ciclo do [NovoPedidoController]: um por pedido em digitação,
/// **recriado a cada criação bem-sucedida** (nova Idempotency-Key + form limpo).
/// Ao criar, permanece na aba e exibe um aviso de sucesso — pensado para lançar
/// vários pedidos em sequência. Mantém estado vivo entre trocas de aba
/// (keep-alive).
class NovoPedidoForm extends StatefulWidget {
  const NovoPedidoForm({super.key, required this.defaultWarehouseId});

  final String defaultWarehouseId;

  @override
  State<NovoPedidoForm> createState() => _NovoPedidoFormState();
}

class _NovoPedidoFormState extends State<NovoPedidoForm>
    with AutomaticKeepAliveClientMixin {
  // Cliente
  final _nomeCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  // Endereço
  final _lineCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _complementCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _cityIbgeCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  // Pagamento / extras
  final _freteCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  // Busca de produto
  final _buscaCtrl = TextEditingController();
  final _buscaFocus = FocusNode();
  final _nomeFocus = FocusNode();

  late final ProdutosRepository _produtos;
  late NovoPedidoController _ctrl;

  Timer? _debounce;
  List<Produto> _resultados = const [];
  bool _buscando = false;
  String? _sucesso;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _produtos = Modular.get<ProdutosRepository>();
    _ctrl = _novoController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nomeFocus.requestFocus();
    });
  }

  NovoPedidoController _novoController() => NovoPedidoController(
    Modular.get<PedidoDeliveryRepository>(),
    defaultWarehouseId: widget.defaultWarehouseId,
  );

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _nomeCtrl.dispose();
    _docCtrl.dispose();
    _telCtrl.dispose();
    _lineCtrl.dispose();
    _numberCtrl.dispose();
    _complementCtrl.dispose();
    _districtCtrl.dispose();
    _cityIbgeCtrl.dispose();
    _zipCtrl.dispose();
    _freteCtrl.dispose();
    _notesCtrl.dispose();
    _buscaCtrl.dispose();
    _buscaFocus.dispose();
    _nomeFocus.dispose();
    super.dispose();
  }

  /// Troca o controller por um novo (nova Idempotency-Key) e zera os campos.
  /// Mecânica pura, sem `setState` — o chamador envolve. O controller antigo é
  /// descartado no pós-frame para o `AnimatedBuilder` migrar os listeners antes
  /// do dispose (evita uso de ChangeNotifier após dispose).
  void _reiniciar() {
    final antigo = _ctrl;
    _ctrl = _novoController();
    for (final c in [
      _nomeCtrl,
      _docCtrl,
      _telCtrl,
      _lineCtrl,
      _numberCtrl,
      _complementCtrl,
      _districtCtrl,
      _cityIbgeCtrl,
      _zipCtrl,
      _freteCtrl,
      _notesCtrl,
      _buscaCtrl,
    ]) {
      c.clear();
    }
    _resultados = const [];
    _buscando = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => antigo.dispose());
  }

  void _limpar() => setState(() {
    _reiniciar();
    _sucesso = null;
  });

  // ── Busca ──
  void _onBuscaChanged(String q) {
    _debounce?.cancel();
    final query = q.trim();
    if (query.isEmpty) {
      setState(() {
        _resultados = const [];
        _buscando = false;
      });
      return;
    }
    setState(() => _buscando = true);
    _debounce = Timer(const Duration(milliseconds: 300), () => _buscar(query));
  }

  Future<void> _buscar(String query) async {
    final r = await _produtos.buscar(query);
    if (!mounted) return;
    r.fold(
      onOk: (lista) => setState(() {
        _resultados = lista;
        _buscando = false;
      }),
      onErr: (_) => setState(() {
        _resultados = const [];
        _buscando = false;
      }),
    );
  }

  Future<void> _onBuscaSubmitted(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    final r = await _produtos.porBarcode(query);
    if (!mounted) return;
    r.fold(onOk: _adicionar, onErr: (_) {});
  }

  void _adicionar(Produto p) {
    _ctrl.adicionarProduto(p);
    _buscaCtrl.clear();
    setState(() => _resultados = const []);
    _buscaFocus.requestFocus();
  }

  void _incr(ItemPedidoCart i) =>
      _ctrl.alterarQuantidade(i.id, i.qtd + UnidadeUi.step(i.productType));
  void _decr(ItemPedidoCart i) =>
      _ctrl.alterarQuantidade(i.id, i.qtd - UnidadeUi.step(i.productType));

  Future<void> _criar() async {
    final resp = await _ctrl.criar();
    if (!mounted || resp == null) return;
    final numero = resp.orderNumber;
    setState(() {
      _reiniciar();
      _sucesso = 'Pedido #$numero criado. Veja em "Pedidos" para acompanhar.';
    });
    _nomeFocus.requestFocus();
  }

  /// Preço por unidade real (ex.: "R$ 72,00 /cx"); sem sufixo quando a unidade
  /// é desconhecida/ausente.
  String _precoUnidade(double preco, String unitOfMeasureRaw) {
    final r = UnidadeUi.rotulo(unitOfMeasureRaw);
    final p = BrlFormatter.format(preco);
    return r.isEmpty ? p : '$p /$r';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // keep-alive
    final colors = context.colors;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: _colunaDados(colors)),
                VerticalDivider(width: 1, color: colors.border),
                Expanded(flex: 5, child: _colunaItens(colors)),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: _footer(colors),
          ),
        ],
      ),
    );
  }

  // ── Coluna esquerda: dados ──
  Widget _colunaDados(AppColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _secao('Cliente', colors),
          _chipsCanal(colors),
          const SizedBox(height: 14),
          _campo(
            colors,
            label: 'NOME',
            controller: _nomeCtrl,
            focusNode: _nomeFocus,
            hint: 'Nome de quem recebe',
            onChanged: _ctrl.setCustomerName,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _campo(
                  colors,
                  label: 'CPF/CNPJ',
                  controller: _docCtrl,
                  hint: 'Opcional',
                  onChanged: _ctrl.setCustomerDoc,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _campo(
                  colors,
                  label: 'TELEFONE',
                  controller: _telCtrl,
                  hint: '(62) 90000-0000',
                  keyboardType: TextInputType.phone,
                  onChanged: _ctrl.setCustomerPhone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _secao('Endereço de entrega', colors),
          _campo(
            colors,
            label: 'LOGRADOURO',
            controller: _lineCtrl,
            hint: 'Rua, avenida…',
            onChanged: _ctrl.setLine,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _campo(
                  colors,
                  label: 'NÚMERO',
                  controller: _numberCtrl,
                  hint: 'Nº',
                  onChanged: _ctrl.setNumber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _campo(
                  colors,
                  label: 'COMPLEMENTO',
                  controller: _complementCtrl,
                  hint: 'Apto, bloco…',
                  onChanged: _ctrl.setComplement,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _campo(
                  colors,
                  label: 'BAIRRO',
                  controller: _districtCtrl,
                  hint: 'Bairro',
                  onChanged: _ctrl.setDistrict,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _campo(
                  colors,
                  label: 'CEP',
                  controller: _zipCtrl,
                  hint: '75000-000',
                  keyboardType: TextInputType.number,
                  onChanged: _ctrl.setZip,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _campo(
            colors,
            label: 'CÓD. IBGE DO MUNICÍPIO',
            controller: _cityIbgeCtrl,
            hint: 'Opcional (ex.: 5201108)',
            keyboardType: TextInputType.number,
            onChanged: _ctrl.setCityIbge,
          ),
          const SizedBox(height: 22),
          _secao('Pagamento', colors),
          _chipsMomento(colors),
          const SizedBox(height: 14),
          _campoFrete(colors),
          const SizedBox(height: 22),
          _secao('Observações', colors),
          _campo(
            colors,
            label: 'NOTAS',
            controller: _notesCtrl,
            hint: 'Ex.: entregar após as 18h',
            textInputAction: TextInputAction.newline,
            onChanged: _ctrl.setNotes,
          ),
        ],
      ),
    );
  }

  Widget _chipsCanal(AppColors colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in PedidoCanal.values)
          _chip(c.label, _ctrl.canal == c, () => _ctrl.setCanal(c), colors),
      ],
    );
  }

  Widget _chipsMomento(AppColors colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in MomentoPagamento.values)
          _chip(
            m.label,
            _ctrl.momentoPagamento == m,
            () => _ctrl.setMomentoPagamento(m),
            colors,
          ),
      ],
    );
  }

  Widget _campoFrete(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PdvFieldLabel('FRETE'),
        const SizedBox(height: 6),
        TextField(
          controller: _freteCtrl,
          enabled: !_ctrl.loading,
          keyboardType: TextInputType.number,
          inputFormatters: const [MoedaInputFormatter()],
          onChanged: (t) => _ctrl.setFrete(MoedaInputFormatter.parse(t)),
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: pdvInputDecoration(context, hint: r'R$ 0,00'),
        ),
      ],
    );
  }

  // ── Coluna direita: itens ──
  Widget _colunaItens(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _secao('Itens', colors),
          TextField(
            controller: _buscaCtrl,
            focusNode: _buscaFocus,
            enabled: !_ctrl.loading,
            textInputAction: TextInputAction.search,
            onChanged: _onBuscaChanged,
            onSubmitted: _onBuscaSubmitted,
            style: TextStyle(fontSize: 14.5, color: colors.text),
            decoration: pdvInputDecoration(
              context,
              hint: 'Buscar por nome ou código',
              suffix: Icon(
                LucideIcons.search,
                size: 18,
                color: colors.textMute,
              ),
            ),
          ),
          _resultadosBusca(colors),
          const SizedBox(height: 14),
          Expanded(child: _carrinho(colors)),
        ],
      ),
    );
  }

  Widget _resultadosBusca(AppColors colors) {
    if (_buscando) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Buscando…',
          style: TextStyle(fontSize: 12, color: colors.textDim),
        ),
      );
    }
    if (_resultados.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _resultados.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: colors.border),
        itemBuilder: (_, idx) => _resultadoRow(_resultados[idx], colors),
      ),
    );
  }

  Widget _resultadoRow(Produto p, AppColors colors) {
    return InkWell(
      onTap: () => _adicionar(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nome,
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
                    'SKU ${p.sku}',
                    style: TextStyle(fontSize: 11.5, color: colors.textMute),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _precoUnidade(p.preco, p.unitOfMeasureRaw),
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.plus, size: 16, color: colors.textMute),
          ],
        ),
      ),
    );
  }

  Widget _carrinho(AppColors colors) {
    final itens = _ctrl.itens;
    if (itens.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.shoppingCart, size: 34, color: colors.textDim),
            const SizedBox(height: 10),
            Text(
              'Nenhum item ainda',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: colors.textMute,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Busque um produto acima para começar.',
              style: TextStyle(fontSize: 12, color: colors.textDim),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: itens.length,
      itemBuilder: (_, idx) => _cartRow(itens[idx], colors),
    );
  }

  Widget _cartRow(ItemPedidoCart i, AppColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i.nome,
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
                  _precoUnidade(i.preco, i.unitOfMeasureRaw),
                  style: TextStyle(fontSize: 11.5, color: colors.textMute),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _qtyStepper(i, colors),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(
              BrlFormatter.format(i.subtotal),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remover',
            onPressed: _ctrl.loading ? null : () => _ctrl.removerItem(i.id),
            icon: Icon(LucideIcons.trash2, size: 16, color: colors.textMute),
          ),
        ],
      ),
    );
  }

  Widget _qtyStepper(ItemPedidoCart i, AppColors colors) {
    final enabled = !_ctrl.loading;
    return Container(
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(LucideIcons.minus, enabled ? () => _decr(i) : null, colors),
          SizedBox(
            width: 58,
            child: Center(
              child: Text(
                UnidadeUi.formatNumero(i.qtd, i.productType),
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: colors.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          _stepBtn(LucideIcons.plus, enabled ? () => _incr(i) : null, colors),
        ],
      ),
    );
  }

  // ── Rodapé ──
  Widget _footer(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_ctrl.errorMessage != null) ...[
          PdvErrorBanner(_ctrl.errorMessage!),
          const SizedBox(height: 14),
        ],
        if (_sucesso != null) ...[
          _sucessoBanner(_sucesso!, colors),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PdvFieldLabel('TOTAL ESTIMADO'),
                const SizedBox(height: 4),
                Text(
                  BrlFormatter.format(_ctrl.valorEstimadoLocal),
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Valor final calculado no servidor.',
                  style: TextStyle(fontSize: 11, color: colors.textDim),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: 130,
              child: PdvGhostButton(
                'Limpar',
                onTap: _ctrl.loading ? null : _limpar,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 200,
              child: PdvPrimaryButton(
                label: 'Criar pedido',
                icon: LucideIcons.check,
                loading: _ctrl.loading,
                enabled: _ctrl.podeCriar,
                onTap: _criar,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sucessoBanner(String msg, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.successTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.check, size: 16, color: colors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(fontSize: 12.5, color: colors.success),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers de UI ──
  Widget _secao(String titulo, AppColors colors) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      titulo,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: colors.text,
      ),
    ),
  );

  Widget _campo(
    AppColors colors, {
    required String label,
    required TextEditingController controller,
    String hint = '',
    FocusNode? focusNode,
    TextInputType? keyboardType,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PdvFieldLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: !_ctrl.loading,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          style: TextStyle(fontSize: 14.5, color: colors.text),
          decoration: pdvInputDecoration(context, hint: hint),
        ),
      ],
    );
  }

  Widget _chip(
    String label,
    bool selected,
    VoidCallback onTap,
    AppColors colors,
  ) {
    return GestureDetector(
      onTap: _ctrl.loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? colors.accent : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colors.accentInk : colors.text,
          ),
        ),
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap, AppColors colors) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 26,
        height: 26,
        child: Icon(
          icon,
          size: 13,
          color: onTap == null ? colors.textDim : colors.textMute,
        ),
      ),
    );
  }
}
