import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/format/time_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/nota_fiscal_response.dart';
import 'package:rabbit_pdv/features/fiscal/domain/fiscal_permissoes.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/configuracao_impressao_dialog.dart';
import 'package:rabbit_pdv/features/fiscal/presentation/nota_fiscal_ui.dart';
import 'package:rabbit_pdv/features/fiscal/presentation/notas_atencao_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/dialogs/pdv_dialog_kit.dart';

/// Botão "Notas fiscais" do topbar, com o número de notas que precisam de
/// atenção. Só aparece para quem pode ver notas ([FiscalPermissoes.ver]).
/// Abre o menu fiscal do terminal: painel de atenção e impressoras.
class NotasFiscaisBotao extends StatefulWidget {
  const NotasFiscaisBotao({super.key, required this.temPermissao});

  final bool Function(String permissao) temPermissao;

  @override
  State<NotasFiscaisBotao> createState() => _NotasFiscaisBotaoState();
}

class _NotasFiscaisBotaoState extends State<NotasFiscaisBotao> {
  late final NotasAtencaoController _atencao;

  @override
  void initState() {
    super.initState();
    _atencao = Modular.get<NotasAtencaoController>()..iniciar();
  }

  @override
  void dispose() {
    _atencao.parar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: _atencao,
      builder: (context, _) {
        final pendentes = _atencao.total;
        return Tooltip(
          message: pendentes == 0
              ? 'Notas fiscais'
              : 'Notas fiscais — $pendentes precisam de atenção',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => showNotasFiscaisDialog(
              context,
              temPermissao: widget.temPermissao,
            ),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: pendentes == 0 ? c.border : c.warn,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.ticket, size: 16, color: c.text),
                  const SizedBox(width: 8),
                  Text(
                    'Notas fiscais',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  if (pendentes > 0) ...[
                    const SizedBox(width: 8),
                    _Contador(pendentes),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador(this.valor);
  final int valor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: c.warn,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        valor > 99 ? '99+' : '$valor',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Menu fiscal do terminal: notas que precisam de atenção (§6.6) e atalho
/// para a configuração das impressoras.
Future<void> showNotasFiscaisDialog(
  BuildContext context, {
  required bool Function(String permissao) temPermissao,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Notas fiscais',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (_, _, _) => _NotasFiscaisDialog(temPermissao: temPermissao),
  );
}

class _NotasFiscaisDialog extends StatefulWidget {
  const _NotasFiscaisDialog({required this.temPermissao});

  final bool Function(String permissao) temPermissao;

  @override
  State<_NotasFiscaisDialog> createState() => _NotasFiscaisDialogState();
}

class _NotasFiscaisDialogState extends State<_NotasFiscaisDialog> {
  late final NotasAtencaoController _atencao;

  @override
  void initState() {
    super.initState();
    _atencao = Modular.get<NotasAtencaoController>()..limparAviso();
    _atencao.atualizar(); // ao abrir, sempre fresco
  }

  void _fechar() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context).size;
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): _fechar,
          },
          child: Focus(
            autofocus: true,
            child: Container(
              width: 760,
              constraints: BoxConstraints(maxHeight: media.height * 0.85),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: ListenableBuilder(
                listenable: _atencao,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _cabecalho(colors),
                    Divider(height: 1, color: colors.border),
                    Flexible(child: _corpo(colors)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cabecalho(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 12, 14),
      child: Row(
        children: [
          Icon(LucideIcons.ticket, size: 20, color: colors.text),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notas fiscais',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                Text(
                  'Notas que precisam de atenção — de qualquer origem.',
                  style: TextStyle(fontSize: 12, color: colors.textMute),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => showConfiguracaoImpressaoDialog(context),
            icon: const Icon(LucideIcons.printer, size: 16),
            label: const Text('Impressoras'),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _atencao.carregando ? null : _atencao.atualizar,
            icon: Icon(LucideIcons.refreshCw, size: 18, color: colors.textMute),
          ),
          IconButton(
            tooltip: 'Fechar (Esc)',
            onPressed: _fechar,
            icon: Icon(LucideIcons.x, size: 18, color: colors.textMute),
          ),
        ],
      ),
    );
  }

  Widget _corpo(AppColors colors) {
    final notas = _atencao.notas;
    final erro = _atencao.erro;
    final aviso = _atencao.aviso;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
      children: [
        if (erro != null) ...[PdvErrorBanner(erro), const SizedBox(height: 10)],
        if (aviso != null) ...[PdvInfoBanner(aviso), const SizedBox(height: 10)],
        if (notas.isEmpty && !_atencao.carregando)
          _vazio(colors)
        else ...[
          const PdvInfoBanner(
            'Notas presas que o sistema não resolveu sozinho. Use "Consultar '
            'SEFAZ"; se persistir, acione o suporte ou o contador.',
            icon: LucideIcons.triangleAlert,
          ),
          const SizedBox(height: 12),
          for (final n in notas) _linha(n, colors),
          if (_atencao.total > notas.length)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Mostrando ${notas.length} de ${_atencao.total}.',
                style: TextStyle(fontSize: 12, color: colors.textMute),
              ),
            ),
        ],
      ],
    );
  }

  Widget _vazio(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(LucideIcons.circleCheck, size: 32, color: colors.success),
          const SizedBox(height: 8),
          Text(
            'Nenhuma nota precisa de atenção.',
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

  Widget _linha(NotaFiscalResponse n, AppColors colors) {
    final ui = NotaStatusUi.of(n.status, colors);
    final podeConsultar = widget.temPermissao(FiscalPermissoes.emitir);
    final consultando = _atencao.consultandoId == n.id;
    final numero = n.numero;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ui.bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              n.status.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ui.fg,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    n.modelo.label,
                    if (numero != null) 'Nº $numero',
                    BrlFormatter.format(n.valorTotal),
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                Text(
                  [
                    'Solicitada em ${TimeFormatter.dataHora(n.emitidaEm)}',
                    if (n.cancelamentoEmAndamento) 'cancelamento em andamento',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: colors.textMute),
                ),
              ],
            ),
          ),
          if (podeConsultar)
            SizedBox(
              width: 170,
              child: PdvGhostButton(
                consultando ? 'Consultando…' : 'Consultar SEFAZ',
                onTap: _atencao.consultandoId == null
                    ? () => _atencao.consultar(n)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
