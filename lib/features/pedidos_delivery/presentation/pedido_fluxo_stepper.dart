import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/pedido_status_ui.dart';

/// Trilha de etapas de UM pedido, exibida no topo do detalhe (padrão "rastreio
/// de pedido"). Mostra os 8 nós do caminho feliz, com a etapa atual destacada,
/// as anteriores como concluídas e as posteriores apagadas.
///
/// É **somente leitura**: tocar num nó só seleciona a etapa para inspeção
/// ([onSelecionarEtapa]) — nunca dispara transição (isso é dos botões de ação).
///
/// Exceção: quando [origemExcecao] é conhecida (via `fromStatus` do histórico),
/// os nós até ela aparecem concluídos, o nó de exceção entra logo em seguida e
/// o resto do caminho feliz fica como não alcançado. Sem essa origem (histórico
/// ausente — v1), o caminho feliz fica neutro e a exceção é anexada ao fim.
class PedidoFluxoStepper extends StatefulWidget {
  const PedidoFluxoStepper({
    super.key,
    required this.statusAtual,
    required this.etapaSelecionada,
    required this.onSelecionarEtapa,
    this.origemExcecao,
  });

  /// Situação atual do pedido ("você está aqui").
  final PedidoStatus statusAtual;

  /// Nó destacado para inspeção (cujas informações o detalhe exibe abaixo).
  final PedidoStatus etapaSelecionada;

  /// Chamado ao tocar num nó inspecionável (concluído, atual ou exceção).
  final ValueChanged<PedidoStatus> onSelecionarEtapa;

  /// Em pedidos de exceção: a etapa do caminho feliz de onde o pedido saiu
  /// (`fromStatus` do evento de exceção). `null` = desconhecida (fallback v1).
  final PedidoStatus? origemExcecao;

  @override
  State<PedidoFluxoStepper> createState() => _PedidoFluxoStepperState();
}

class _PedidoFluxoStepperState extends State<PedidoFluxoStepper> {
  final _scroll = ScrollController();
  bool _podeEsquerda = false;
  bool _podeDireita = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_sincronizarSetas);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sincronizarSetas();
      _rolarAteAtual();
    });
  }

  @override
  void didUpdateWidget(covariant PedidoFluxoStepper old) {
    super.didUpdateWidget(old);
    if (old.statusAtual != widget.statusAtual ||
        old.origemExcecao != widget.origemExcecao) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rolarAteAtual());
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_sincronizarSetas);
    _scroll.dispose();
    super.dispose();
  }

  void _sincronizarSetas() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final esq = pos.pixels > 0.5;
    final dir = pos.pixels < pos.maxScrollExtent - 0.5;
    if (esq != _podeEsquerda || dir != _podeDireita) {
      setState(() {
        _podeEsquerda = esq;
        _podeDireita = dir;
      });
    }
  }

  /// Leva o nó atual (ou o de exceção) para a vista.
  void _rolarAteAtual() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    final slots = _slots();
    var alvo = slots.indexWhere(
      (s) => s.$2 == _EstadoNo.atual || s.$2 == _EstadoNo.excecao,
    );
    if (alvo < 0) alvo = slots.length - 1;
    final frac = slots.length <= 1 ? 0.0 : alvo / (slots.length - 1);
    _scroll.animateTo(
      (max * frac).clamp(0.0, max),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _rolar(double delta) {
    if (!_scroll.hasClients) return;
    final alvo = (_scroll.offset + delta).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      alvo,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _onScroll(PointerSignalEvent e) {
    if (e is PointerScrollEvent && _scroll.hasClients) {
      final delta = e.scrollDelta.dy != 0 ? e.scrollDelta.dy : e.scrollDelta.dx;
      final alvo = (_scroll.offset + delta).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      _scroll.jumpTo(alvo);
    }
  }

  /// Sequência de nós a renderizar, cada um com seu estado visual. Encapsula a
  /// lógica de caminho feliz × exceção (com ou sem origem conhecida).
  List<(PedidoStatus, _EstadoNo)> _slots() {
    const fluxo = PedidoStatus.fluxoFeliz;
    final atualIdx = widget.statusAtual.indiceFluxo;
    final excecao = widget.statusAtual.isExcecao;
    final origemIdx = widget.origemExcecao?.indiceFluxo ?? -1;

    final slots = <(PedidoStatus, _EstadoNo)>[];
    if (!excecao) {
      for (var i = 0; i < fluxo.length; i++) {
        slots.add((
          fluxo[i],
          i < atualIdx
              ? _EstadoNo.concluido
              : (i == atualIdx ? _EstadoNo.atual : _EstadoNo.futuro),
        ));
      }
    } else if (origemIdx >= 0) {
      for (var i = 0; i <= origemIdx; i++) {
        slots.add((fluxo[i], _EstadoNo.concluido));
      }
      slots.add((widget.statusAtual, _EstadoNo.excecao));
      for (var i = origemIdx + 1; i < fluxo.length; i++) {
        slots.add((fluxo[i], _EstadoNo.indeterminado));
      }
    } else {
      for (final s in fluxo) {
        slots.add((s, _EstadoNo.indeterminado));
      }
      slots.add((widget.statusAtual, _EstadoNo.excecao));
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final slots = _slots();

    return Row(
      children: [
        _seta(
          LucideIcons.chevronLeft,
          _podeEsquerda ? () => _rolar(-180) : null,
          colors,
        ),
        Expanded(
          child: Listener(
            onPointerSignal: _onScroll,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
                scrollbars: false,
              ),
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < slots.length; i++) ...[
                      _no(slots[i].$1, slots[i].$2, colors),
                      if (i < slots.length - 1)
                        _conector(slots[i].$2 == _EstadoNo.concluido, colors),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        _seta(
          LucideIcons.chevronRight,
          _podeDireita ? () => _rolar(180) : null,
          colors,
        ),
      ],
    );
  }

  Widget _seta(IconData icon, VoidCallback? onTap, AppColors colors) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 26,
        height: 44,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: onTap != null ? colors.textMute : colors.border,
        ),
      ),
    );
  }

  Widget _conector(bool percorrido, AppColors colors) {
    return Container(
      width: 18,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: percorrido ? colors.accent : colors.border,
    );
  }

  Widget _no(PedidoStatus s, _EstadoNo estado, AppColors colors) {
    final selecionado = s == widget.etapaSelecionada;
    final inspecionavel =
        estado == _EstadoNo.concluido ||
        estado == _EstadoNo.atual ||
        estado == _EstadoNo.excecao;

    // Cores por estado do nó.
    final Color bg;
    final Color fg;
    final Color borda;
    switch (estado) {
      case _EstadoNo.atual:
        final ui = PedidoStatusUi.of(s, colors);
        bg = ui.bg;
        fg = ui.fg;
        borda = selecionado ? colors.accent : ui.fg.withValues(alpha: 0.5);
      case _EstadoNo.concluido:
        bg = colors.surface2;
        fg = colors.success;
        borda = selecionado ? colors.accent : colors.border;
      case _EstadoNo.excecao:
        final ui = PedidoStatusUi.of(s, colors);
        bg = ui.bg;
        fg = ui.fg;
        borda = selecionado ? colors.accent : ui.fg.withValues(alpha: 0.5);
      case _EstadoNo.futuro:
      case _EstadoNo.indeterminado:
        bg = colors.surface2;
        fg = colors.textDim;
        borda = colors.border;
    }

    final conteudo = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borda, width: selecionado ? 2 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _marcador(estado, fg, colors),
          const SizedBox(width: 7),
          Text(
            s.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight:
                  estado == _EstadoNo.atual || estado == _EstadoNo.excecao
                  ? FontWeight.w600
                  : FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );

    if (!inspecionavel) return conteudo;
    return GestureDetector(
      onTap: () => widget.onSelecionarEtapa(s),
      behavior: HitTestBehavior.opaque,
      child: conteudo,
    );
  }

  Widget _marcador(_EstadoNo estado, Color fg, AppColors colors) {
    switch (estado) {
      case _EstadoNo.concluido:
        return Icon(LucideIcons.check, size: 13, color: fg);
      case _EstadoNo.excecao:
        return Icon(LucideIcons.triangleAlert, size: 12, color: fg);
      case _EstadoNo.atual:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
        );
      case _EstadoNo.futuro:
      case _EstadoNo.indeterminado:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.textDim),
          ),
        );
    }
  }
}

/// Estado visual de um nó na trilha.
enum _EstadoNo {
  /// Etapa já percorrida (índice menor que o atual, ou anterior à exceção).
  concluido,

  /// Etapa atual do pedido.
  atual,

  /// Etapa ainda não alcançada (índice maior que o atual).
  futuro,

  /// Caminho feliz posterior à exceção (ou, sem origem conhecida, o caminho
  /// inteiro) — não alcançado; neutro e não inspecionável.
  indeterminado,

  /// Nó de exceção (cancelado/não entregue/devolvido/pagamento recusado).
  excecao,
}
