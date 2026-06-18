import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/domain/entities/atendimento.dart';
import 'package:rabbit_pdv/domain/entities/produto.dart';
import 'package:rabbit_pdv/domain/repositories/produtos_repository.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/sessions_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/ui_controllers.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/items/cart_list.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/items/category_grid.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/items/segmented_toggle.dart';

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

  @override
  void initState() {
    super.initState();
    _loadCategorias();
  }

  Future<void> _loadCategorias() async {
    final r = await widget.repo.categorias();
    if (!mounted) return;
    r.fold(
      onOk: (list) => setState(() {
        _categorias = list;
        _loadingCats = false;
        widget.view.setCategoria(widget.view.categoriaSelecionada ?? list.firstOrNull);
      }),
      onErr: (_) => setState(() => _loadingCats = false),
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
                        onAdjustQty: (item, delta) =>
                            widget.sessions.ajustarQtd(item.id, delta),
                        onRemove: (item) => widget.sessions.removerItem(item.id),
                      )
                    : _AtalhosView(
                        loading: _loadingCats,
                        categorias: _categorias,
                        categoriaSelecionada: widget.view.categoriaSelecionada,
                        repo: widget.repo,
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
    final ordem = session.ordem.toString().padLeft(2, '0');

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'ATENDIMENTO #$ordem · ${session.cliente.nome}'.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.overline.copyWith(color: c.textMute),
            ),
          ),
          ListenableBuilder(
            listenable: view,
            builder: (_, __) {
              return SegmentedToggle(
                value: view.value,
                onChange: view.setView,
                options: [
                  ToggleOption(
                    value: ItemsView.carrinho,
                    label: 'Carrinho',
                    icon: LucideIcons.shoppingCart,
                    count: itemCount > 0 ? itemCount : null,
                  ),
                  const ToggleOption(
                    value: ItemsView.atalhos,
                    label: 'Atalhos',
                    icon: LucideIcons.shoppingBag,
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 10),
          ListenableBuilder(
            listenable: view,
            builder: (_, __) {
              final showClear = view.value == ItemsView.carrinho && itemCount > 0;
              if (!showClear) return const SizedBox(width: 0);
              return TextButton(
                onPressed: () => sessions.limparItens(),
                style: TextButton.styleFrom(
                  foregroundColor: c.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(
                  'Limpar',
                  style: AppText.bodySm.copyWith(
                    color: c.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AtalhosView extends StatefulWidget {
  final bool loading;
  final List<String> categorias;
  final String? categoriaSelecionada;
  final ProdutosRepository repo;
  final Map<String, double> qtdPorSku;
  final ValueChanged<String> onCategoryChange;
  final void Function(Produto) onProductTap;

  const _AtalhosView({
    required this.loading,
    required this.categorias,
    required this.categoriaSelecionada,
    required this.repo,
    required this.qtdPorSku,
    required this.onCategoryChange,
    required this.onProductTap,
  });

  @override
  State<_AtalhosView> createState() => _AtalhosViewState();
}

class _AtalhosViewState extends State<_AtalhosView> {
  List<Produto> _produtos = const [];
  bool _loading = false;
  String? _ultimaCat;

  @override
  void didUpdateWidget(covariant _AtalhosView old) {
    super.didUpdateWidget(old);
    if (widget.categoriaSelecionada != _ultimaCat) {
      _loadProdutos();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProdutos();
  }

  Future<void> _loadProdutos() async {
    final cat = widget.categoriaSelecionada;
    if (cat == null) return;
    _ultimaCat = cat;
    setState(() => _loading = true);
    final r = await widget.repo.porCategoria(cat);
    if (!mounted) return;
    r.fold(
      onOk: (list) => setState(() {
        _produtos = list;
        _loading = false;
      }),
      onErr: (_) => setState(() => _loading = false),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading || _loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return CategoryGrid(
      categorias: widget.categorias,
      categoriaSelecionada: widget.categoriaSelecionada,
      produtos: _produtos,
      qtdPorSku: widget.qtdPorSku,
      onCategoryChange: widget.onCategoryChange,
      onProductTap: widget.onProductTap,
    );
  }
}
