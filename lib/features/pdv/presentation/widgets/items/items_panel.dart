import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/domain/entities/atendimento.dart';
import 'package:rabbit_pdv/domain/entities/item_atendimento.dart';
import 'package:rabbit_pdv/domain/repositories/produtos_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/anulacao_repository.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/caixa_session_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/sessions_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/ui_controllers.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/items/anular_item_dialog.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/items/cart_list.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/items/category_grid.dart';
import 'package:rabbit_pdv/domain/entities/produto.dart';

class ItemsPanel extends StatefulWidget {
  final Atendimento session;
  final SessionsController sessions;
  final ViewController view;
  final ProdutosRepository repo;

  const ItemsPanel({
    super.key,
    required this.session,
    required this.sessions,
    required this.view,
    required this.repo,
  });

  @override
  State<ItemsPanel> createState() => _ItemsPanelState();
}

class _ItemsPanelState extends State<ItemsPanel> {
  List<String> _categorias = const [];
  bool _loadingCats = true;

  List<Produto> _produtos = const [];
  bool _loadingProdutos = false;
  String? _lastLoadedCategoria;

  @override
  void initState() {
    super.initState();
    widget.view.addListener(_onViewChanged);
    _loadCategorias();
  }

  @override
  void dispose() {
    widget.view.removeListener(_onViewChanged);
    super.dispose();
  }

  void _onViewChanged() {
    if (widget.view.value != ItemsView.atalhos) return;
    final categoria = widget.view.categoriaSelecionada;
    if (categoria == null || categoria == _lastLoadedCategoria) return;
    _loadProdutos(categoria);
  }

  Future<void> _loadCategorias() async {
    final r = await widget.repo.categorias();
    if (!mounted) return;
    r.fold(
      onOk: (list) => setState(() {
        _categorias = list;
        _loadingCats = false;
        widget.view.setCategoria(
          widget.view.categoriaSelecionada ?? list.firstOrNull,
        );
      }),
      onErr: (_) => setState(() => _loadingCats = false),
    );
    if (!mounted) return;
    if (widget.view.value == ItemsView.atalhos &&
        widget.view.categoriaSelecionada != null) {
      _loadProdutos(widget.view.categoriaSelecionada);
    }
  }

  Future<void> _loadProdutos(String? categoria) async {
    if (categoria == null) return;
    setState(() {
      _loadingProdutos = true;
    });

    final r = await widget.repo.porCategoria(categoria);
    if (!mounted || widget.view.categoriaSelecionada != categoria) return;

    r.fold(
      onOk: (list) => setState(() {
        _produtos = list;
        _loadingProdutos = false;
        _lastLoadedCategoria = categoria;
      }),
      onErr: (_) => setState(() {
        _produtos = const [];
        _loadingProdutos = false;
        _lastLoadedCategoria = categoria;
      }),
    );
  }

  /// Gate de fraude: remover item exige liberação do supervisor. Abre o
  /// diálogo e só remove do carrinho local quando o servidor responde 2xx.
  Future<void> _confirmarAnulacao(ItemAtendimento item) async {
    final caixa = Modular.get<CaixaSessionController>();
    final cashSessionId = caixa.caixaSessao?.id;
    if (cashSessionId == null) {
      _toast('Caixa não está pronto. ${caixa.erro ?? "Aguarde a abertura."}');
      return;
    }

    final resp = await showAnularItem(
      context,
      repo: Modular.get<AnulacaoRepository>(),
      item: item,
      cashSessionId: cashSessionId,
      cartRef: widget.session.id,
    );
    if (!mounted || resp == null) return;

    widget.sessions.removerItem(item.id);
    _toast(
      resp.idempotent
          ? 'Item já estava anulado (liberação reaplicada).'
          : 'Item anulado e liberado.',
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          _ItemsPanelHeader(
            session: widget.session,
            view: widget.view,
            sessions: widget.sessions,
            itemCount: widget.session.numItens,
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.view,
              builder: (_, __) {
                return widget.view.value == ItemsView.carrinho
                    ? CartList(
                        items: widget.session.itens,
                        onAdjustQty: (item, delta) {
                          // − que zeraria a linha = remoção → passa pelo gate.
                          if (delta < 0 && (item.qtd + delta) <= 0) {
                            _confirmarAnulacao(item);
                            return;
                          }
                          widget.sessions.ajustarQtd(item.id, delta);
                        },
                        onRemove: _confirmarAnulacao,
                      )
                    : _AtalhosView(
                        loadingCats: _loadingCats,
                        loadingProducts: _loadingProdutos,
                        categorias: _categorias,
                        produtos: _produtos,
                        categoriaSelecionada: widget.view.categoriaSelecionada,
                        qtdPorSku: widget.session.qtdPorSku,
                        onCategoryChange: widget.view.setCategoria,
                        onProductTap: (p) {
                          final out = widget.sessions.adicionarProduto(p);
                          if (!out.sucesso) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(out.erro?.message ?? 'Erro'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsPanelHeader extends StatelessWidget {
  final Atendimento session;
  final ViewController view;
  final SessionsController sessions;
  final int itemCount;

  const _ItemsPanelHeader({
    required this.session,
    required this.view,
    required this.sessions,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isCarrinho = view.value == ItemsView.carrinho;
    final ordem = session.ordem.toString().padLeft(2, '0');

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATD #$ordem · ${itemCount == 1 ? '1 item' : '$itemCount itens'}',
                  style: TextStyle(
                    color: c.textMute,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Itens',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _ViewTab(
            label: 'Carrinho',
            active: isCarrinho,
            onTap: () => view.setView(ItemsView.carrinho),
          ),
          const SizedBox(width: 8),
          _ViewTab(
            label: 'Atalhos',
            active: !isCarrinho,
            onTap: () => view.setView(ItemsView.atalhos),
          ),
        ],
      ),
    );
  }
}

class _ViewTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ViewTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? c.accent : c.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? c.accentInk : c.text,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _AtalhosView extends StatelessWidget {
  final bool loadingCats;
  final bool loadingProducts;
  final List<String> categorias;
  final List<Produto> produtos;
  final String? categoriaSelecionada;
  final Map<String, double> qtdPorSku;
  final ValueChanged<String> onCategoryChange;
  final ValueChanged<Produto> onProductTap;

  const _AtalhosView({
    required this.loadingCats,
    required this.loadingProducts,
    required this.categorias,
    required this.produtos,
    required this.categoriaSelecionada,
    required this.qtdPorSku,
    required this.onCategoryChange,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (loadingCats) {
      return Center(child: CircularProgressIndicator(color: c.accent));
    }

    if (categorias.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma categoria disponível.',
          style: TextStyle(color: c.textMute, fontSize: 13),
        ),
      );
    }

    if (categoriaSelecionada == null) {
      return Center(
        child: Text(
          'Selecione uma categoria para ver os atalhos.',
          style: TextStyle(color: c.textMute, fontSize: 13),
        ),
      );
    }

    if (loadingProducts) {
      return Column(
        children: [
          CategoryGrid(
            categorias: categorias,
            categoriaSelecionada: categoriaSelecionada,
            produtos: const [],
            qtdPorSku: qtdPorSku,
            onCategoryChange: onCategoryChange,
            onProductTap: onProductTap,
          ),
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
      );
    }

    if (produtos.isEmpty) {
      return Column(
        children: [
          CategoryGrid(
            categorias: categorias,
            categoriaSelecionada: categoriaSelecionada,
            produtos: const [],
            qtdPorSku: qtdPorSku,
            onCategoryChange: onCategoryChange,
            onProductTap: onProductTap,
          ),
          Expanded(
            child: Center(
              child: Text(
                'Nenhum produto nesta categoria.',
                style: TextStyle(color: c.textMute, fontSize: 13),
              ),
            ),
          ),
        ],
      );
    }

    return CategoryGrid(
      categorias: categorias,
      categoriaSelecionada: categoriaSelecionada,
      produtos: produtos,
      qtdPorSku: qtdPorSku,
      onCategoryChange: onCategoryChange,
      onProductTap: onProductTap,
    );
  }
}
