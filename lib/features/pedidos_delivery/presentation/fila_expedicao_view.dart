import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/auth/lock_controller.dart';
import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/nota_fiscal_resumo.dart';
import 'package:rabbit_pdv/features/fiscal/domain/fiscal_permissoes.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_modelo.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/configuracao_impressao.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/configuracao_impressao_dialog.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/impressao_fiscal.dart';
import 'package:rabbit_pdv/features/fiscal/presentation/nota_fiscal_ui.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/caixa_session_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/dialogs/pdv_dialog_kit.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/pedido_resumo_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/pedido_delivery_repository.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_acao.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_canal.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/fila_expedicao_controller.dart';

/// Fila de expedição (guia fiscal v2.3 §7.1), mostrada na aba Pedidos quando
/// o filtro é "Aguardando expedição". Cada pedido traz a situação da nota:
/// imprimir, reimprimir e expedir sem abrir o pedido. Rejeitada, cancelada ou
/// presa: abrir o pedido ([onAbrir]), onde fica o painel completo da nota.
///
/// O [controller] pertence a quem hospeda a fila (a aba Pedidos): continua
/// atualizando — e imprimindo sozinho na estação de expedição — enquanto o
/// operador olha o detalhe de um pedido. Crie com [criarFilaExpedicao].
class FilaExpedicaoView extends StatefulWidget {
  const FilaExpedicaoView({
    super.key,
    required this.controller,
    required this.onAbrir,
  });

  final FilaExpedicaoController controller;
  final ValueChanged<String> onAbrir;

  @override
  State<FilaExpedicaoView> createState() => _FilaExpedicaoViewState();
}

/// Monta o controller da fila com as dependências do módulo e já começa a
/// atualizar. Quem cria descarta (`dispose`).
FilaExpedicaoController criarFilaExpedicao() {
  final lock = Modular.get<LockController>();
  return FilaExpedicaoController(
    pedidos: Modular.get<PedidoDeliveryRepository>(),
    impressao: Modular.get<ImpressaoFiscal>(),
    configuracao: Modular.get<ConfiguracaoImpressaoStore>(),
    pausado: () => lock.locked,
  )..iniciar();
}

class _FilaExpedicaoViewState extends State<FilaExpedicaoView> {
  late final CaixaSessionController _session;

  FilaExpedicaoController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _session = Modular.get<CaixaSessionController>();
  }

  bool get _podeImprimir => _session.temPermissao(FiscalPermissoes.ver);
  bool get _podeExpedir => _session.temPermissao(PedidoAcao.expedir.permissao);

  Future<void> _configurarImpressoras() async {
    await showConfiguracaoImpressaoDialog(context);
    await _ctrl.atualizar(); // o interruptor da estação pode ter mudado
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _faixa(colors),
          if (_ctrl.aviso case final aviso?)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: GestureDetector(
                onTap: _ctrl.limparAviso,
                child: aviso.erro
                    ? PdvErrorBanner(aviso.texto)
                    : PdvInfoBanner(aviso.texto, icon: LucideIcons.circleCheck),
              ),
            ),
          Expanded(child: _lista(colors)),
        ],
      ),
    );
  }

  Widget _faixa(AppColors colors) {
    final auto = _ctrl.impressaoAutomatica;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      color: colors.surface2,
      child: Row(
        children: [
          Icon(
            auto ? LucideIcons.printer : LucideIcons.info,
            size: 15,
            color: auto ? colors.success : colors.textMute,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              auto
                  ? 'Estação de expedição: o cupom sai sozinho quando a nota '
                        'é autorizada.'
                  : 'Impressão manual neste terminal.',
              style: TextStyle(fontSize: 12, color: colors.textMute),
            ),
          ),
          TextButton(
            onPressed: _configurarImpressoras,
            child: const Text('Impressoras'),
          ),
        ],
      ),
    );
  }

  Widget _lista(AppColors colors) {
    if (_ctrl.carregando) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final itens = _ctrl.itens;
    final erro = _ctrl.erro;
    if (itens.isEmpty) {
      return Center(
        child: Text(
          erro ?? 'Nenhum pedido aguardando expedição.',
          style: TextStyle(
            fontSize: 13.5,
            color: erro == null ? colors.textMute : colors.danger,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      itemCount: itens.length + (erro == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) =>
          i < itens.length ? _linha(itens[i], colors) : PdvErrorBanner(erro!),
    );
  }

  Widget _linha(PedidoResumoResponse p, AppColors colors) {
    final nota = p.notaFiscal;
    final ocupado = _ctrl.ocupadoId != null;
    final rodando = _ctrl.ocupadoId == p.pedidoId;
    final podeImprimir =
        _podeImprimir &&
        nota != null &&
        nota.status == NotaStatus.autorizada &&
        !nota.cancelamentoEmAndamento;
    final podeExpedir = _podeExpedir && (nota?.aptaParaExpedir ?? false);

    return Material(
      color: colors.surface2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => widget.onAbrir(p.pedidoId),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
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
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.customerName.isEmpty
                          ? 'Cliente não informado'
                          : p.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, color: colors.text),
                    ),
                    Text(
                      '${p.canal.label} · ${BrlFormatter.format(p.valorEstimado)}',
                      style: TextStyle(fontSize: 11.5, color: colors.textDim),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _situacao(nota, colors),
              const SizedBox(width: 10),
              if (rodando)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                if (podeImprimir)
                  OutlinedButton.icon(
                    onPressed: ocupado ? null : () => _ctrl.imprimir(p),
                    icon: const Icon(LucideIcons.printer, size: 15),
                    label: Text(_rotuloImprimir(nota)),
                  ),
                if (podeExpedir) ...[
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: ocupado ? null : () => _ctrl.expedir(p),
                    icon: const Icon(LucideIcons.truck, size: 15),
                    label: const Text('Expedir'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Situação da nota na fila (tabela do §7.1).
  Widget _situacao(NotaFiscalResumo? nota, AppColors colors) {
    final (texto, cor) = switch (nota) {
      null => ('Emitindo nota…', colors.textMute),
      NotaFiscalResumo(requerAtencao: true) => (
        'Precisa de atenção — abra o pedido',
        colors.warn,
      ),
      NotaFiscalResumo(cancelamentoEmAndamento: true) => (
        'Cancelamento em andamento',
        colors.warn,
      ),
      NotaFiscalResumo(:final status)
          when status == NotaStatus.rejeitada ||
              status == NotaStatus.cancelada =>
        ('${status.label} — abra o pedido para emitir de novo', colors.danger),
      NotaFiscalResumo(:final status, :final modelo) => (
        '${modelo.label} · ${status.label}',
        NotaStatusUi.of(status, colors).fg,
      ),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: Text(
        texto,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cor,
        ),
      ),
    );
  }

  String _rotuloImprimir(NotaFiscalResumo nota) {
    if (_ctrl.foiImpressa(nota)) return 'Reimprimir';
    return nota.modelo == NotaModelo.nfce ? 'Imprimir cupom' : 'Imprimir DANFE';
  }
}
