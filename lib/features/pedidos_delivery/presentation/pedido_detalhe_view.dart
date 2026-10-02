import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/caixa_session_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/dialogs/pdv_dialog_kit.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/pedido_detalhe_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/pedido_delivery_repository.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/momento_pagamento.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_acao.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_canal.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/pedido_detalhe_controller.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/pedido_status_ui.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/separar_view.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/presentation/unidade_ui.dart';

/// Sub-view de detalhe de um pedido (guia §4.13), empurrada dentro da aba
/// Pedidos. [onVoltar] retorna à fila preservada pelo container.
class PedidoDetalheView extends StatefulWidget {
  const PedidoDetalheView({
    super.key,
    required this.pedidoId,
    required this.onVoltar,
  });

  final String pedidoId;
  final VoidCallback onVoltar;

  @override
  State<PedidoDetalheView> createState() => _PedidoDetalheViewState();
}

class _PedidoDetalheViewState extends State<PedidoDetalheView> {
  late final PedidoDetalheController _ctrl;
  late final CaixaSessionController _session;

  final _recebidoPorCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();

  /// Ação com mini-form aberto; null = mostrando botões.
  PedidoAcao? _prompt;
  String? _formaSelecionada;

  /// Sub-tela de separação aberta (§4.3).
  bool _separando = false;

  /// Formas de pagamento para o concluir NA_ENTREGA (guia §6, texto livre;
  /// enviamos os tokens sugeridos). (rótulo, valor de fio).
  static const List<(String, String)> _formasPagamento = [
    ('PIX', 'PIX'),
    ('Dinheiro', 'DINHEIRO'),
    ('Cartão crédito', 'CARTAO_CREDITO'),
    ('Cartão débito', 'CARTAO_DEBITO'),
  ];

  /// Ações de exceção que usam o mini-form de motivo.
  static const Set<PedidoAcao> _comMotivo = {
    PedidoAcao.cancelar,
    PedidoAcao.naoEntregue,
    PedidoAcao.pagamentoRecusado,
    PedidoAcao.devolver,
  };

  /// Todas implementadas — a Fase 2 está completa.
  static const Set<PedidoAcao> _wired = {
    PedidoAcao.confirmar,
    PedidoAcao.separar,
    PedidoAcao.conferir,
    PedidoAcao.faturar,
    PedidoAcao.expedir,
    PedidoAcao.entregar,
    PedidoAcao.concluir,
    PedidoAcao.cancelar,
    PedidoAcao.naoEntregue,
    PedidoAcao.pagamentoRecusado,
    PedidoAcao.devolver,
  };

  @override
  void initState() {
    super.initState();
    _ctrl = PedidoDetalheController(
      Modular.get<PedidoDeliveryRepository>(),
      widget.pedidoId,
    );
    _session = Modular.get<CaixaSessionController>();
    _ctrl.carregar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _recebidoPorCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  // ── Ações ──
  void _onAcao(PedidoAcao a) {
    if (a == PedidoAcao.separar) {
      setState(() => _separando = true);
      return;
    }
    if (a == PedidoAcao.entregar) {
      _recebidoPorCtrl.clear();
      setState(() => _prompt = PedidoAcao.entregar);
      return;
    }
    if (a == PedidoAcao.concluir) {
      _formaSelecionada = null;
      setState(() => _prompt = PedidoAcao.concluir);
      return;
    }
    if (_comMotivo.contains(a)) {
      _motivoCtrl.clear();
      setState(() => _prompt = a);
      return;
    }
    _ctrl.executar(a);
  }

  Future<void> _confirmarPrompt() async {
    switch (_prompt) {
      case PedidoAcao.entregar:
        await _ctrl.entregar(_recebidoPorCtrl.text);
      case PedidoAcao.concluir:
        await _ctrl.concluir(_formaSelecionada);
      case PedidoAcao.cancelar:
        await _ctrl.cancelar(_motivoCtrl.text);
      case PedidoAcao.naoEntregue:
        await _ctrl.naoEntregue(_motivoCtrl.text);
      case PedidoAcao.pagamentoRecusado:
        await _ctrl.pagamentoRecusado(_motivoCtrl.text);
      case PedidoAcao.devolver:
        await _ctrl.devolver(_motivoCtrl.text);
      default:
        return;
    }
    if (!mounted) return;
    if (_ctrl.acaoErro == null) setState(() => _prompt = null);
  }

  void _cancelarPrompt() {
    _ctrl.limparAcaoErro();
    setState(() => _prompt = null);
  }

  void _onSeparacaoConcluida() {
    setState(() => _separando = false);
    _ctrl.carregar();
  }

  bool get _podeConfirmar {
    if (_ctrl.executandoAcao) return false;
    switch (_prompt) {
      case PedidoAcao.entregar:
        return _recebidoPorCtrl.text.trim().isNotEmpty;
      case PedidoAcao.concluir:
        final exige =
            _ctrl.detalhe?.momentoPagamento.exigeFormaNaConclusao ?? false;
        return !exige || _formaSelecionada != null;
      case PedidoAcao.cancelar:
      case PedidoAcao.naoEntregue:
      case PedidoAcao.devolver:
        return _motivoCtrl.text.trim().isNotEmpty; // motivo obrigatório
      case PedidoAcao.pagamentoRecusado:
        return true; // motivo opcional
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final d = _ctrl.detalhe;

        if (_separando && d != null) {
          return SepararView(
            pedidoId: widget.pedidoId,
            orderNumber: d.orderNumber,
            itens: d.itens,
            onConcluido: _onSeparacaoConcluida,
            onCancelar: () => setState(() => _separando = false),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _barraTopo(colors),
            Divider(height: 1, color: colors.border),
            Expanded(child: _conteudo(colors)),
            if (d != null && !_ctrl.loading) _rodape(d, colors),
          ],
        );
      },
    );
  }

  Widget _barraTopo(AppColors colors) {
    final d = _ctrl.detalhe;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Voltar à fila',
            onPressed: widget.onVoltar,
            icon: Icon(LucideIcons.arrowLeft, size: 20, color: colors.textMute),
          ),
          const SizedBox(width: 4),
          Text(
            d != null ? 'Pedido #${d.orderNumber}' : 'Pedido',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const Spacer(),
          if (d != null) _statusPill(d.status, colors),
        ],
      ),
    );
  }

  Widget _conteudo(AppColors colors) {
    if (_ctrl.loading) {
      return Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(colors.accent),
          ),
        ),
      );
    }
    if (_ctrl.erro != null) return _erroState(_ctrl.erro!, colors);
    final d = _ctrl.detalhe;
    if (d == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _secaoCliente(d, colors),
          const SizedBox(height: 22),
          _secaoEndereco(d, colors),
          const SizedBox(height: 22),
          _secaoPagamento(d, colors),
          const SizedBox(height: 22),
          _secaoItens(d, colors),
        ],
      ),
    );
  }

  // ── Rodapé: banner de erro + (botões OU mini-form) ──
  Widget _rodape(PedidoDetalheResponse d, AppColors colors) {
    final acoes = d.status.acoesDisponiveis
        .where((a) => _session.temPermissao(a.permissao))
        .toList();
    final temBotoes = acoes.isNotEmpty;
    if (!temBotoes && _ctrl.acaoErro == null && _prompt == null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: colors.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_ctrl.acaoErro != null) ...[
                _acaoErroBanner(_ctrl.acaoErro!, colors),
                const SizedBox(height: 12),
              ],
              if (_prompt != null)
                _miniForm(d, colors)
              else if (temBotoes)
                _botoes(acoes, colors),
            ],
          ),
        ),
      ],
    );
  }

  Widget _botoes(List<PedidoAcao> acoes, AppColors colors) {
    final idxPrimaria = acoes.indexWhere((a) => !a.isDestrutiva);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        for (var i = 0; i < acoes.length; i++)
          _acaoBtn(acoes[i], i == idxPrimaria, colors),
      ],
    );
  }

  Widget _acaoBtn(PedidoAcao a, bool primaria, AppColors colors) {
    final wired = _wired.contains(a);
    final rodando = _ctrl.acaoEmExecucao == a;
    final habilitado = wired && !_ctrl.executandoAcao;
    final atenuado = !habilitado && !rodando;

    final Color bg;
    final Color fg;
    final Color borda;
    if (primaria && !a.isDestrutiva) {
      bg = colors.accent;
      fg = colors.accentInk;
      borda = colors.accent;
    } else if (a.isDestrutiva) {
      bg = Colors.transparent;
      fg = colors.danger;
      borda = colors.danger.withValues(alpha: 0.4);
    } else {
      bg = Colors.transparent;
      fg = colors.text;
      borda = colors.border;
    }

    final botao = Opacity(
      opacity: atenuado ? 0.5 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: habilitado ? () => _onAcao(a) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borda),
            ),
            child: rodando
                ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(fg),
                    ),
                  )
                : Text(
                    a.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
          ),
        ),
      ),
    );

    return wired ? botao : Tooltip(message: 'Em breve', child: botao);
  }

  // ── Mini-forms ──
  Widget _miniForm(PedidoDetalheResponse d, AppColors colors) {
    return switch (_prompt!) {
      PedidoAcao.entregar => _formEntregar(colors),
      PedidoAcao.concluir => _formConcluir(d, colors),
      PedidoAcao.cancelar ||
      PedidoAcao.naoEntregue ||
      PedidoAcao.pagamentoRecusado ||
      PedidoAcao.devolver => _formMotivo(_prompt!, colors),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _formEntregar(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Confirmar entrega',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 10),
        const PdvFieldLabel('QUEM RECEBEU'),
        const SizedBox(height: 6),
        TextField(
          controller: _recebidoPorCtrl,
          autofocus: true,
          enabled: !_ctrl.executandoAcao,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _podeConfirmar ? _confirmarPrompt() : null,
          style: TextStyle(fontSize: 14.5, color: colors.text),
          decoration: pdvInputDecoration(context, hint: 'Nome de quem recebeu'),
        ),
        const SizedBox(height: 14),
        _promptBotoes('Confirmar entrega', colors, destrutivo: false),
      ],
    );
  }

  Widget _formConcluir(PedidoDetalheResponse d, AppColors colors) {
    final exige = d.momentoPagamento.exigeFormaNaConclusao;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Concluir pedido',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          exige
              ? 'Pagamento na entrega — selecione a forma recebida.'
              : 'Pagamento antecipado — já liquidado.',
          style: TextStyle(fontSize: 12, color: colors.textMute),
        ),
        if (exige) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, valor) in _formasPagamento)
                _formaChip(label, valor, colors),
            ],
          ),
        ],
        const SizedBox(height: 14),
        _promptBotoes('Concluir pedido', colors, destrutivo: false),
      ],
    );
  }

  Widget _formMotivo(PedidoAcao a, AppColors colors) {
    final opcional = a == PedidoAcao.pagamentoRecusado;
    final destrutivo = a.isDestrutiva;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _tituloMotivo(a),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: destrutivo ? colors.danger : colors.text,
          ),
        ),
        if (destrutivo) ...[
          const SizedBox(height: 4),
          Text(
            'Esta ação não pode ser desfeita.',
            style: TextStyle(fontSize: 12, color: colors.textMute),
          ),
        ],
        const SizedBox(height: 10),
        PdvFieldLabel(opcional ? 'MOTIVO (OPCIONAL)' : 'MOTIVO'),
        const SizedBox(height: 6),
        TextField(
          controller: _motivoCtrl,
          autofocus: true,
          enabled: !_ctrl.executandoAcao,
          minLines: 1,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontSize: 14.5, color: colors.text),
          decoration: pdvInputDecoration(context, hint: 'Descreva o motivo'),
        ),
        const SizedBox(height: 14),
        _promptBotoes(a.label, colors, destrutivo: destrutivo),
      ],
    );
  }

  String _tituloMotivo(PedidoAcao a) => switch (a) {
    PedidoAcao.cancelar => 'Cancelar pedido',
    PedidoAcao.naoEntregue => 'Registrar não entrega',
    PedidoAcao.pagamentoRecusado => 'Registrar pagamento recusado',
    PedidoAcao.devolver => 'Devolver pedido',
    _ => a.label,
  };

  Widget _formaChip(String label, String valor, AppColors colors) {
    final sel = _formaSelecionada == valor;
    return GestureDetector(
      onTap: _ctrl.executandoAcao
          ? null
          : () => setState(() => _formaSelecionada = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? colors.accent : colors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? colors.accent : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
            color: sel ? colors.accentInk : colors.text,
          ),
        ),
      ),
    );
  }

  Widget _promptBotoes(
    String confirmar,
    AppColors colors, {
    required bool destrutivo,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 120,
          child: PdvGhostButton(
            'Voltar',
            onTap: _ctrl.executandoAcao ? null : _cancelarPrompt,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 210,
          child: destrutivo
              ? _btnDestrutivo(confirmar, colors)
              : PdvPrimaryButton(
                  label: confirmar,
                  icon: LucideIcons.check,
                  loading: _ctrl.executandoAcao,
                  enabled: _podeConfirmar,
                  onTap: _confirmarPrompt,
                ),
        ),
      ],
    );
  }

  Widget _btnDestrutivo(String label, AppColors colors) {
    final habilitado = _podeConfirmar;
    return Opacity(
      opacity: habilitado ? 1 : 0.5,
      child: Material(
        color: colors.danger,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: habilitado ? _confirmarPrompt : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            child: _ctrl.executandoAcao
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _acaoErroBanner(String msg, AppColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.dangerTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.circleAlert, size: 16, color: colors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(fontSize: 12.5, color: colors.danger),
            ),
          ),
          GestureDetector(
            onTap: _ctrl.limparAcaoErro,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(LucideIcons.x, size: 14, color: colors.danger),
            ),
          ),
        ],
      ),
    );
  }

  // ── Seções ──
  Widget _secaoCliente(PedidoDetalheResponse d, AppColors colors) {
    final c = d.cliente;
    return _bloco('Cliente', colors, [
      _linha('Nome', c.nome?.isNotEmpty == true ? c.nome! : '—', colors),
      if (c.telefone?.isNotEmpty == true)
        _linha('Telefone', c.telefone!, colors),
      if (c.doc?.isNotEmpty == true) _linha('Documento', c.doc!, colors),
      _linha('Canal', d.canal.label, colors),
    ]);
  }

  Widget _secaoEndereco(PedidoDetalheResponse d, AppColors colors) {
    final e = d.endereco;
    final linha2 = [
      e.district,
      e.zip,
      e.cityIbge,
    ].where((s) => s != null && s.isNotEmpty).join(' · ');
    final numero = e.number?.isNotEmpty == true ? ', ${e.number}' : '';
    final compl = e.complement?.isNotEmpty == true ? ' — ${e.complement}' : '';
    return _bloco('Endereço de entrega', colors, [
      _linha('Logradouro', '${e.line}$numero$compl', colors),
      if (linha2.isNotEmpty) _linha('Bairro / CEP', linha2, colors),
    ]);
  }

  Widget _secaoPagamento(PedidoDetalheResponse d, AppColors colors) {
    return _bloco('Pagamento', colors, [
      _linha('Momento', d.momentoPagamento.label, colors),
      if (d.metodoPrevisto?.isNotEmpty == true)
        _linha('Método previsto', d.metodoPrevisto!, colors),
      _linha('Frete', BrlFormatter.format(d.frete), colors),
      _linha('Total estimado', BrlFormatter.format(d.valorEstimado), colors),
      if (d.notes?.isNotEmpty == true) _linha('Observações', d.notes!, colors),
    ]);
  }

  Widget _secaoItens(PedidoDetalheResponse d, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tituloSecao('Itens (${d.itens.length})', colors),
        const SizedBox(height: 12),
        for (final it in d.itens) _itemCard(it, colors),
      ],
    );
  }

  Widget _itemCard(ItemPedidoDetalhe it, AppColors colors) {
    final unidade = UnidadeUi.rotulo(it.unitOfMeasure);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${it.lineNumber}',
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
                  it.produtoId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: colors.textMute),
                ),
              ),
              if (it.itemStatus.isNotEmpty)
                _itemStatusChip(it.itemStatus, colors),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _qtyBloco(
                'Solicitado',
                _qtd(it.qtySolicitada, it.isWeighed, unidade),
                colors,
              ),
              if (it.qtySeparada != null)
                _qtyBloco(
                  'Separado',
                  _qtd(it.qtySeparada!, it.isWeighed, unidade),
                  colors,
                ),
              if (it.qtyFaturada != null)
                _qtyBloco(
                  'Faturado',
                  _qtd(it.qtyFaturada!, it.isWeighed, unidade),
                  colors,
                ),
              _qtyBloco(
                'Estimado',
                BrlFormatter.format(it.valorEstimado),
                colors,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers visuais ──
  Widget _bloco(String titulo, AppColors colors, List<Widget> linhas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tituloSecao(titulo, colors),
        const SizedBox(height: 10),
        ...linhas,
      ],
    );
  }

  Widget _tituloSecao(String t, AppColors colors) => Text(
    t,
    style: TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: colors.text,
    ),
  );

  Widget _linha(String rotulo, String valor, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              rotulo,
              style: TextStyle(fontSize: 12.5, color: colors.textMute),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(fontSize: 12.5, color: colors.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBloco(String rotulo, String valor, AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: colors.textDim,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _itemStatusChip(String status, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surface3,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: colors.textMute,
        ),
      ),
    );
  }

  Widget _statusPill(PedidoStatus s, AppColors colors) {
    final ui = PedidoStatusUi.of(s, colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ui.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ui.fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        s.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: ui.fg,
        ),
      ),
    );
  }

  Widget _erroState(String msg, AppColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.circleAlert, size: 34, color: colors.danger),
          const SizedBox(height: 10),
          Text(
            'Não foi possível carregar o pedido',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.textMute),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _ctrl.carregar,
            child: Text(
              'Tentar de novo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _qtd(double v, bool isWeighed, String unidade) {
    final s = (isWeighed ? v.toStringAsFixed(3) : v.toStringAsFixed(0))
        .replaceAll('.', ',');
    return unidade.isEmpty ? s : '$s $unidade';
  }
}
