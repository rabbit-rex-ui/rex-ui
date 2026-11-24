import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/format/time_formatter.dart';
import 'package:rabbit_pdv/core/network/relogio_servidor.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/nota_fiscal_response.dart';
import 'package:rabbit_pdv/features/fiscal/data/nota_fiscal_repository.dart';
import 'package:rabbit_pdv/features/fiscal/domain/chave_acesso.dart';
import 'package:rabbit_pdv/features/fiscal/domain/fiscal_permissoes.dart';
import 'package:rabbit_pdv/features/fiscal/domain/justificativa_cancelamento.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_modelo.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/configuracao_impressao_dialog.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/impressao_fiscal.dart';
import 'package:rabbit_pdv/features/fiscal/presentation/ferramentas_mock_fiscal.dart';
import 'package:rabbit_pdv/features/fiscal/presentation/nota_fiscal_ui.dart';
import 'package:rabbit_pdv/features/fiscal/presentation/notas_fiscais_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/dialogs/pdv_dialog_kit.dart';

/// Painel "Nota fiscal" de uma venda: estado da nota, impressão do DANFE,
/// cancelamento, reemissão e histórico (guia fiscal v2.0 §8).
///
/// Independente da feature que o hospeda: recebe o [vendaId] e a checagem de
/// permissão por callback. Quem hospeda decide se o operador pode VER notas
/// ([FiscalPermissoes.ver]) antes de montar o painel.
class NotasFiscaisPainel extends StatefulWidget {
  const NotasFiscaisPainel({
    super.key,
    required this.vendaId,
    required this.temPermissao,
  });

  final String vendaId;
  final bool Function(String permissao) temPermissao;

  @override
  State<NotasFiscaisPainel> createState() => _NotasFiscaisPainelState();
}

class _NotasFiscaisPainelState extends State<NotasFiscaisPainel> {
  late final NotasFiscaisController _ctrl;
  late final RelogioServidor _relogio;
  final _justificativaCtrl = TextEditingController();

  /// Formulário de cancelamento aberto.
  bool _cancelando = false;
  bool _historicoAberto = false;

  @override
  void initState() {
    super.initState();
    _ctrl = NotasFiscaisController(
      repo: Modular.get<NotaFiscalRepository>(),
      impressao: Modular.get<ImpressaoFiscal>(),
      vendaId: widget.vendaId,
    );
    _relogio = Modular.get<RelogioServidor>();
    _ctrl.carregar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _justificativaCtrl.dispose();
    super.dispose();
  }

  bool _pode(String permissao) => widget.temPermissao(permissao);

  // ── Cancelamento ──

  void _abrirCancelamento() {
    _justificativaCtrl.text = _ctrl.ultimaJustificativa ?? '';
    _ctrl.limparAviso();
    setState(() => _cancelando = true);
  }

  void _fecharCancelamento() => setState(() => _cancelando = false);

  Future<void> _confirmarCancelamento() async {
    await _ctrl.cancelar(_justificativaCtrl.text);
    if (mounted) _fecharCancelamento();
  }

  Future<void> _copiarChave(String chave) async {
    await Clipboard.setData(ClipboardData(text: chave));
    _ctrl.informar('Chave de acesso copiada.');
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final nota = _ctrl.notaAtual;
        final aviso = _ctrl.aviso;
        return Container(
          margin: const EdgeInsets.only(bottom: 22),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cabecalho(nota, colors),
              const SizedBox(height: 10),
              _corpo(nota, colors),
              if (aviso != null) ...[
                const SizedBox(height: 12),
                _AvisoBanner(
                  aviso: aviso,
                  onFechar: _ctrl.limparAviso,
                  onConfigurarImpressora: aviso.configurarImpressora
                      ? () => showConfiguracaoImpressaoDialog(context)
                      : null,
                ),
              ],
              if (_cancelando && nota != null) ...[
                const SizedBox(height: 12),
                _formCancelamento(colors),
              ] else ...[
                _acoes(nota),
              ],
              if (_ctrl.historico.isNotEmpty) _historico(colors),
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                FerramentasMockFiscal(controller: _ctrl),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _cabecalho(NotaFiscalResponse? nota, AppColors colors) {
    return Row(
      children: [
        Icon(LucideIcons.ticket, size: 16, color: colors.textMute),
        const SizedBox(width: 8),
        Text(
          nota == null ? 'Nota fiscal' : 'Nota fiscal · ${nota.modelo.label}',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        const Spacer(),
        if (nota != null) _StatusPill(status: nota.status),
      ],
    );
  }

  Widget _corpo(NotaFiscalResponse? nota, AppColors colors) {
    if (_ctrl.carregando) {
      return _Nota(
        'Buscando a nota fiscal…',
        colors: colors,
        icone: LucideIcons.clock,
      );
    }
    final erro = _ctrl.erroCarga;
    if (erro != null) {
      return Row(
        children: [
          Expanded(
            child: _Nota(erro, colors: colors, cor: colors.danger),
          ),
          TextButton(
            onPressed: _ctrl.carregar,
            child: const Text('Tentar de novo'),
          ),
        ],
      );
    }
    if (nota == null) {
      return _Nota('Nenhuma nota emitida para esta venda.', colors: colors);
    }
    return _detalhe(nota, colors);
  }

  Widget _detalhe(NotaFiscalResponse nota, AppColors colors) {
    final chave = nota.chaveAcesso;
    final serie = nota.serie;
    final numero = nota.numero;
    final destinatario = [
      nota.destinatarioNome,
      nota.destinatarioDocumento,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final autorizadaEm = nota.autorizadaEm;
    final cancelavelAte = nota.cancelavelAte;
    final canceladaEm = nota.canceladaEm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (numero != null)
          _Linha(
            'Número',
            'Série ${serie ?? '-'} · Nº $numero',
            colors: colors,
          ),
        if (chave != null)
          _Linha(
            'Chave de acesso',
            chaveAcessoEmBlocos(chave),
            colors: colors,
            monoespacado: true,
            acao: IconButton(
              tooltip: 'Copiar chave',
              visualDensity: VisualDensity.compact,
              iconSize: 14,
              onPressed: () => _copiarChave(chave),
              icon: Icon(LucideIcons.copy, color: colors.textMute),
            ),
          ),
        if (nota.protocolo != null)
          _Linha('Protocolo', nota.protocolo!, colors: colors),
        if (destinatario.isNotEmpty)
          _Linha('Destinatário', destinatario, colors: colors),
        _Linha('Valor', BrlFormatter.format(nota.valorTotal), colors: colors),
        _Linha(
          'Solicitada em',
          TimeFormatter.dataHora(nota.emitidaEm),
          colors: colors,
        ),
        if (autorizadaEm != null)
          _Linha(
            'Autorizada em',
            TimeFormatter.dataHora(autorizadaEm),
            colors: colors,
          ),
        if (canceladaEm != null)
          _Linha(
            'Cancelada em',
            TimeFormatter.dataHora(canceladaEm),
            colors: colors,
          ),
        if (nota.motivoCancelamento != null)
          _Linha('Justificativa', nota.motivoCancelamento!, colors: colors),
        if (nota.status == NotaStatus.rejeitada)
          _Linha(
            'Rejeição',
            [
              nota.codigoRejeicao,
              nota.motivoRejeicao,
            ].whereType<String>().join(' — '),
            colors: colors,
            cor: colors.danger,
          ),
        ..._situacoes(nota, colors),
        if (nota.status == NotaStatus.autorizada &&
            !nota.cancelamentoEmAndamento &&
            cancelavelAte != null) ...[
          const SizedBox(height: 4),
          PrazoCancelamento(
            ate: cancelavelAte,
            agora: _relogio.agora,
            // Só redesenha o painel: o botão "Cancelar" some sozinho.
            onExpirou: () => setState(() {}),
          ),
        ],
      ],
    );
  }

  /// Avisos de situação da nota (não são erros de ação).
  List<Widget> _situacoes(NotaFiscalResponse nota, AppColors colors) {
    return [
      if (nota.status == NotaStatus.rejeitada)
        _Nota(
          'O número não foi consumido. Corrija a causa e emita de novo.',
          colors: colors,
        ),
      if (nota.status.emProcessamento && !_ctrl.aguardandoEmSegundoPlano)
        _Nota(
          'Aguardando a resposta da SEFAZ…',
          colors: colors,
          icone: LucideIcons.clock,
        ),
      if (nota.status.emProcessamento && _ctrl.aguardandoEmSegundoPlano)
        _Nota(
          'Aguardando SEFAZ — você pode sair desta tela. O sistema continua '
          'tentando sozinho.',
          colors: colors,
          icone: LucideIcons.clock,
        ),
      if (nota.cancelamentoEmAndamento)
        _Nota(
          'Cancelamento em andamento: a SEFAZ ainda não confirmou. A nota não '
          'pode ser expedida até a confirmação.',
          colors: colors,
          cor: colors.warn,
          icone: LucideIcons.triangleAlert,
        ),
      if (nota.requerAtencao)
        _Nota(
          'Esta nota precisa de atenção: várias consultas sem desfecho. Use '
          '"Consultar SEFAZ"; se persistir, acione o suporte ou o contador.',
          colors: colors,
          cor: colors.warn,
          icone: LucideIcons.triangleAlert,
        ),
      if (nota.emContingencia)
        _Nota(
          'Emitida em ${nota.modoEmissao.label.toLowerCase()}.',
          colors: colors,
          icone: LucideIcons.info,
        ),
    ];
  }

  // ── Ações (guia §5: ações por estado + permissão) ──

  Widget _acoes(NotaFiscalResponse? nota) {
    final emExecucao = _ctrl.acaoEmExecucao;
    final botoes = <Widget>[
      if (nota != null && _podeImprimir(nota))
        _BotaoAcao(
          rotulo: nota.modelo == NotaModelo.nfce
              ? 'Imprimir cupom'
              : 'Imprimir DANFE',
          icone: LucideIcons.printer,
          primario: true,
          carregando: emExecucao == NotaAcao.imprimir,
          onTap: _ctrl.ocupado ? null : () => _ctrl.imprimir(nota),
        ),
      if (nota != null && _podeConsultar(nota))
        _BotaoAcao(
          rotulo: 'Consultar SEFAZ',
          icone: LucideIcons.refreshCw,
          carregando: emExecucao == NotaAcao.consultar,
          onTap: _ctrl.ocupado ? null : _ctrl.consultarSefaz,
        ),
      if (_ctrl.podeEmitir && _pode(FiscalPermissoes.emitir))
        _BotaoAcao(
          rotulo: nota == null ? 'Emitir nota' : 'Emitir de novo',
          icone: LucideIcons.send,
          primario: true,
          carregando: emExecucao == NotaAcao.emitir,
          onTap: _ctrl.ocupado ? null : _ctrl.emitir,
        ),
      if (nota != null && _podeAbrirCancelamento(nota))
        _BotaoAcao(
          rotulo: nota.cancelamentoEmAndamento
              ? 'Tentar cancelar de novo'
              : 'Cancelar nota',
          icone: LucideIcons.ban,
          destrutivo: true,
          carregando: emExecucao == NotaAcao.cancelar,
          onTap: _ctrl.ocupado ? null : _abrirCancelamento,
        ),
    ];
    if (botoes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: botoes,
      ),
    );
  }

  /// Guia v2.2 §5/§9.4: só nota autorizada e sem cancelamento em andamento
  /// vai para o cliente. Cancelada não tem cupom; DANFE e XML ficam na
  /// retaguarda.
  bool _podeImprimir(NotaFiscalResponse nota) =>
      _pode(FiscalPermissoes.ver) &&
      nota.status == NotaStatus.autorizada &&
      !nota.cancelamentoEmAndamento &&
      // NFC-e: o cupom sai do XML; NF-e: do DANFE em PDF.
      (nota.modelo == NotaModelo.nfce
          ? nota.xmlDisponivel
          : nota.danfeDisponivel);

  /// Guia §5/§8.4/§10: nota presa que pede atenção, polling esgotado ou
  /// cancelamento sem resposta.
  bool _podeConsultar(NotaFiscalResponse nota) =>
      _pode(FiscalPermissoes.emitir) &&
      nota.precisaAcompanhar &&
      (nota.requerAtencao ||
          nota.cancelamentoEmAndamento ||
          _ctrl.aguardandoEmSegundoPlano);

  /// Guia §8.3: dentro do prazo e sem cancelamento em andamento — ou o
  /// "Tentar de novo" de um cancelamento sem resposta (§8.4).
  bool _podeAbrirCancelamento(NotaFiscalResponse nota) {
    if (!_pode(FiscalPermissoes.cancelar)) return false;
    if (nota.status != NotaStatus.autorizada) return false;
    return nota.cancelamentoEmAndamento ||
        nota.cancelavelEm(_relogio.agora());
  }

  Widget _formCancelamento(AppColors colors) {
    final texto = _justificativaCtrl.text;
    final valida = JustificativaCancelamento.validar(texto) == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cancelar nota fiscal',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: colors.danger,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'A justificativa vai para a SEFAZ. Esta ação não pode ser desfeita; '
          'se a venda continuar, emita uma nova nota depois.',
          style: TextStyle(fontSize: 12, color: colors.textMute),
        ),
        const SizedBox(height: 10),
        const PdvFieldLabel(
          'JUSTIFICATIVA (${JustificativaCancelamento.minimo} A '
          '${JustificativaCancelamento.maximo} CARACTERES)',
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _justificativaCtrl,
          autofocus: true,
          enabled: !_ctrl.ocupado,
          minLines: 2,
          maxLines: 4,
          maxLength: JustificativaCancelamento.maximo,
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontSize: 14, color: colors.text),
          decoration: pdvInputDecoration(
            context,
            hint: 'Ex.: Cliente desistiu da compra no caixa',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _BotaoAcao(
              rotulo: 'Voltar',
              onTap: _ctrl.ocupado ? null : _fecharCancelamento,
            ),
            const SizedBox(width: 8),
            _BotaoAcao(
              rotulo: 'Confirmar cancelamento',
              icone: LucideIcons.ban,
              destrutivo: true,
              preenchido: true,
              carregando: _ctrl.acaoEmExecucao == NotaAcao.cancelar,
              onTap: valida && !_ctrl.ocupado ? _confirmarCancelamento : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _historico(AppColors colors) {
    final anteriores = _ctrl.historico;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _historicoAberto = !_historicoAberto),
            child: Row(
              children: [
                Icon(
                  _historicoAberto
                      ? LucideIcons.chevronDown
                      : LucideIcons.chevronRight,
                  size: 14,
                  color: colors.textMute,
                ),
                const SizedBox(width: 4),
                Text(
                  'Notas anteriores (${anteriores.length})',
                  style: TextStyle(fontSize: 12, color: colors.textMute),
                ),
              ],
            ),
          ),
          if (_historicoAberto)
            for (final n in anteriores) _itemHistorico(n, colors),
        ],
      ),
    );
  }

  Widget _itemHistorico(NotaFiscalResponse n, AppColors colors) {
    final detalhe = switch (n.status) {
      NotaStatus.rejeitada => [
        n.codigoRejeicao,
        n.motivoRejeicao,
      ].whereType<String>().join(' — '),
      NotaStatus.cancelada => n.motivoCancelamento ?? '',
      _ => '',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusPill(status: n.status),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [
                '${n.modelo.label} · ${TimeFormatter.dataHora(n.emitidaEm)}',
                if (detalhe.isNotEmpty) detalhe,
              ].join('\n'),
              style: TextStyle(fontSize: 12, color: colors.textMute),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Peças visuais ──

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final NotaStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = NotaStatusUi.of(status, context.colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ui.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ui.fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: ui.fg,
        ),
      ),
    );
  }
}

/// Linha rótulo/valor, no mesmo desenho das seções do detalhe do pedido.
class _Linha extends StatelessWidget {
  const _Linha(
    this.rotulo,
    this.valor, {
    required this.colors,
    this.cor,
    this.monoespacado = false,
    this.acao,
  });

  final String rotulo;
  final String valor;
  final AppColors colors;
  final Color? cor;
  final bool monoespacado;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              rotulo,
              style: TextStyle(fontSize: 12.5, color: colors.textMute),
            ),
          ),
          Expanded(
            child: SelectableText(
              valor,
              style: TextStyle(
                fontSize: 12.5,
                color: cor ?? colors.text,
                fontFamily: monoespacado ? 'JetBrainsMono' : null,
              ),
            ),
          ),
          ?acao,
        ],
      ),
    );
  }
}

/// Texto de situação com ícone opcional.
class _Nota extends StatelessWidget {
  const _Nota(this.texto, {required this.colors, this.cor, this.icone});

  final String texto;
  final AppColors colors;
  final Color? cor;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final c = cor ?? colors.textMute;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icone != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icone, size: 14, color: c),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 12.5, color: c, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoBanner extends StatelessWidget {
  const _AvisoBanner({
    required this.aviso,
    required this.onFechar,
    this.onConfigurarImpressora,
  });

  final AvisoFiscal aviso;
  final VoidCallback onFechar;

  /// Atalho para o diálogo "Impressoras" quando a térmica não está
  /// configurada; `null` = sem atalho.
  final VoidCallback? onConfigurarImpressora;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cor = aviso.erro ? colors.danger : colors.accent;
    final orientacao = aviso.orientacao;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            aviso.erro ? LucideIcons.circleAlert : LucideIcons.info,
            size: 16,
            color: cor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aviso.texto,
                  style: TextStyle(fontSize: 12.5, color: cor),
                ),
                if (orientacao != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'O que fazer: $orientacao',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: cor,
                    ),
                  ),
                ],
                if (onConfigurarImpressora != null)
                  TextButton.icon(
                    onPressed: onConfigurarImpressora,
                    icon: const Icon(LucideIcons.printer, size: 14),
                    label: const Text('Configurar impressora'),
                  ),
              ],
            ),
          ),
          InkWell(
            onTap: onFechar,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(LucideIcons.x, size: 14, color: cor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão compacto do painel. `onTap == null` desabilita.
class _BotaoAcao extends StatelessWidget {
  const _BotaoAcao({
    required this.rotulo,
    required this.onTap,
    this.icone,
    this.primario = false,
    this.destrutivo = false,
    this.preenchido = false,
    this.carregando = false,
  });

  final String rotulo;
  final VoidCallback? onTap;
  final IconData? icone;
  final bool primario;
  final bool destrutivo;

  /// Destrutivo com fundo cheio (confirmação final).
  final bool preenchido;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color fundo;
    final Color texto;
    final Color borda;
    if (destrutivo && preenchido) {
      fundo = colors.danger;
      texto = Colors.white;
      borda = colors.danger;
    } else if (destrutivo) {
      fundo = Colors.transparent;
      texto = colors.danger;
      borda = colors.danger.withValues(alpha: 0.4);
    } else if (primario) {
      fundo = colors.accent;
      texto = colors.accentInk;
      borda = colors.accent;
    } else {
      fundo = Colors.transparent;
      texto = colors.text;
      borda = colors.border;
    }

    final habilitado = onTap != null && !carregando;
    return Opacity(
      opacity: habilitado || carregando ? 1 : 0.5,
      child: Material(
        color: fundo,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: habilitado ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borda),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (carregando)
                  SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(texto),
                    ),
                  )
                else if (icone != null)
                  Icon(icone, size: 15, color: texto),
                if (carregando || icone != null) const SizedBox(width: 8),
                Text(
                  rotulo,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: texto,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
