import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/domain/entities/produto.dart';
import 'package:rabbit_pdv/domain/repositories/produtos_repository.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/sessions_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/ui_controllers.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/scanner/search_results_dropdown.dart';

class Scanner extends StatefulWidget {
  final ScannerController controller;
  final SessionsController sessions;
  final ProdutosRepository repo;
  final FocusNode focusNode;
  final VoidCallback onAfterSubmit;

  const Scanner({
    super.key,
    required this.controller,
    required this.sessions,
    required this.repo,
    required this.focusNode,
    required this.onAfterSubmit,
  });

  @override
  State<Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<Scanner> {
  late final TextEditingController _input;
  Timer? _debounce;
  List<Produto> _results = const [];
  bool _showDropdown = false;
  int _highlightedIdx = 0;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.controller.query);
    _input.addListener(_onInputChanged);
    widget.controller.addListener(_syncFromController);
  }

  void _syncFromController() {
    if (_input.text != widget.controller.query) {
      _input.text = widget.controller.query;
    }
    if (mounted) setState(() {});
  }

  void _onInputChanged() {
    final q = _input.text;
    widget.controller.setQuery(q);
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _results = const [];
        _showDropdown = false;
        _highlightedIdx = 0;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 150), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _input.text;
    final r = await widget.repo.buscar(q);
    if (!mounted) return;
    r.fold(
      onOk: (list) {
        setState(() {
          _results = list;
          _showDropdown = list.isNotEmpty;
          _highlightedIdx = 0;
        });
      },
      onErr: (_) {
        setState(() {
          _results = const [];
          _showDropdown = false;
        });
      },
    );
  }

  Future<void> _onSubmit() async {
    final q = _input.text.trim();
    if (q.isEmpty) return;

    // Se há dropdown aberto, Enter seleciona o highlighted.
    if (_showDropdown && _results.isNotEmpty) {
      final p = _results[_highlightedIdx.clamp(0, _results.length - 1)];
      _commitProduto(p);
      return;
    }

    // Senão, tenta pelo barcode.
    final outcome = await widget.sessions.adicionarPorBarcode(q);
    if (!mounted) return;
    if (outcome.sucesso) {
      widget.controller.flashSuccess();
      _input.clear();
      setState(() {
        _results = const [];
        _showDropdown = false;
      });
    } else {
      widget.controller.flashError();
      // Mantém o input para o operador corrigir.
      _showToast(outcome.erro?.message ?? 'Produto não cadastrado');
    }
    widget.onAfterSubmit();
  }

  void _commitProduto(Produto p) {
    final outcome = widget.sessions.adicionarProduto(p);
    if (outcome.sucesso) {
      widget.controller.flashSuccess();
      _input.clear();
      setState(() {
        _results = const [];
        _showDropdown = false;
      });
    } else {
      widget.controller.flashError();
      _showToast(outcome.erro?.message ?? 'Não foi possível adicionar');
    }
    widget.onAfterSubmit();
  }

  void _showToast(String msg) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey.keyLabel;
    if (key == 'Arrow Down' && _showDropdown) {
      setState(() {
        _highlightedIdx = (_highlightedIdx + 1).clamp(0, _results.length - 1);
      });
      return KeyEventResult.handled;
    }
    if (key == 'Arrow Up' && _showDropdown) {
      setState(() {
        _highlightedIdx = (_highlightedIdx - 1).clamp(0, _results.length - 1);
      });
      return KeyEventResult.handled;
    }
    if (key == 'Escape') {
      setState(() {
        _showDropdown = false;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _input.removeListener(_onInputChanged);
    _input.dispose();
    widget.controller.removeListener(_syncFromController);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final flash = widget.controller.flash;

    final borderColor = switch (flash) {
      ScannerFlash.success => c.success,
      ScannerFlash.error => c.danger,
      ScannerFlash.none => c.border,
    };

    final iconBg = switch (flash) {
      ScannerFlash.success => c.success,
      ScannerFlash.error => c.danger,
      ScannerFlash.none => c.surface2,
    };

    final iconColor = switch (flash) {
      ScannerFlash.none => c.text,
      _ => Colors.white,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 58,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.barcode,
                  size: 22,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Focus(
                  onKeyEvent: _handleKey,
                  child: TextField(
                    controller: _input,
                    focusNode: widget.focusNode,
                    autofocus: true,
                    onSubmitted: (_) => _onSubmit(),
                    style: AppText.monoMd.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: c.text,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Leitor, código, SKU ou nome do produto…',
                      hintStyle: AppText.body.copyWith(
                        color: c.textDim,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _ScannerIconButton(
                icon: LucideIcons.qrCode,
                tooltip: 'Ler QR (F4)',
                onTap: () {
                  // TODO: abrir modal QR ou aguardar leitor 2D.
                },
              ),
              const SizedBox(width: 4),
              _ScannerIconButton(
                icon: LucideIcons.scale,
                tooltip: 'Balança',
                onTap: () {
                  // TODO: BalancaService.lerPeso() — futuro.
                },
              ),
            ],
          ),
        ),
        if (_showDropdown)
          SearchResultsDropdown(
            results: _results,
            query: _input.text,
            highlightedIdx: _highlightedIdx,
            onSelect: _commitProduto,
            onHover: (i) => setState(() => _highlightedIdx = i),
          ),
      ],
    );
  }
}

class _ScannerIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ScannerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ScannerIconButton> createState() => _ScannerIconButtonState();
}

class _ScannerIconButtonState extends State<_ScannerIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _hover ? c.surface3 : c.surface2,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: c.border),
            ),
            child: Icon(widget.icon, size: 18, color: c.text),
          ),
        ),
      ),
    );
  }
}
