import 'dart:async';

import 'package:flutter/material.dart';

import 'package:rabbit_pdv/core/format/time_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';

/// Cores do badge de status da nota. Mora em `presentation/` porque cor é UI —
/// o enum [NotaStatus] é domínio puro.
class NotaStatusUi {
  const NotaStatusUi(this.fg, this.bg);

  final Color fg;
  final Color bg;

  static NotaStatusUi of(NotaStatus status, AppColors colors) {
    return switch (status) {
      NotaStatus.pendente ||
      NotaStatus.enviada => NotaStatusUi(colors.warn, colors.warnTint),
      NotaStatus.autorizada => NotaStatusUi(colors.success, colors.successTint),
      NotaStatus.rejeitada => NotaStatusUi(colors.danger, colors.dangerTint),
      NotaStatus.cancelada ||
      NotaStatus.inutilizada => NotaStatusUi(colors.textMute, colors.surface3),
    };
  }
}

/// Formatação de dados fiscais para a tela. A chave de acesso em blocos está
/// em `domain/chave_acesso.dart` (a tela e o cupom usam a mesma).
abstract final class NotaFiscalFormat {
  /// Tempo restante legível: `23h 05min` ou `04:59`.
  static String tempoRestante(Duration d) {
    String dois(int n) => n.toString().padLeft(2, '0');
    if (d.inHours >= 1) {
      return '${d.inHours}h ${dois(d.inMinutes.remainder(60))}min';
    }
    return '${dois(d.inMinutes)}:${dois(d.inSeconds.remainder(60))}';
  }
}

/// Contagem regressiva do prazo de cancelamento (guia §8.3). Redesenha só a
/// si mesma a cada segundo e avisa o pai em [onExpirou] para esconder o botão
/// "Cancelar".
class PrazoCancelamento extends StatefulWidget {
  const PrazoCancelamento({
    super.key,
    required this.ate,
    required this.agora,
    required this.onExpirou,
  });

  final DateTime ate;

  /// Relógio do servidor (`RelogioServidor.agora`), não o do terminal.
  final DateTime Function() agora;
  final VoidCallback onExpirou;

  @override
  State<PrazoCancelamento> createState() => _PrazoCancelamentoState();
}

class _PrazoCancelamentoState extends State<PrazoCancelamento> {
  Timer? _timer;

  Duration get _restante => widget.ate.difference(widget.agora());
  bool get _expirado => _restante <= Duration.zero;

  @override
  void initState() {
    super.initState();
    _agendar();
  }

  @override
  void didUpdateWidget(PrazoCancelamento oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ate != widget.ate) _agendar();
  }

  void _agendar() {
    _timer?.cancel();
    if (_expirado) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    if (_expirado) {
      _timer?.cancel();
      widget.onExpirou();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texto = _expirado
        ? 'Prazo de cancelamento encerrado em '
              '${TimeFormatter.dataHora(widget.ate)}.'
        : 'Cancelável por mais ${NotaFiscalFormat.tempoRestante(_restante)} '
              '(até ${TimeFormatter.dataHora(widget.ate)}).';
    return Text(
      texto,
      style: TextStyle(
        fontSize: 12,
        color: _expirado ? colors.textMute : colors.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
