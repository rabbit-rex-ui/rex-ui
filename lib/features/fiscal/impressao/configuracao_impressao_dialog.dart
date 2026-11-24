import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/configuracao_impressao.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/configuracao_impressao_controller.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/impressao_fiscal.dart';
import 'package:rabbit_pdv/features/fiscal/impressao/impressora_raw.dart';
import 'package:rabbit_pdv/features/pdv/presentation/widgets/dialogs/pdv_dialog_kit.dart';

/// Abre o diálogo "Impressoras" deste terminal: térmica do cupom NFC-e,
/// colunas, módulo do QR e impressão de teste (guia fiscal v2.3 §9.3/§9.6).
Future<void> showConfiguracaoImpressaoDialog(BuildContext context) async {
  final controller = ConfiguracaoImpressaoController(
    store: Modular.get<ConfiguracaoImpressaoStore>(),
    impressoras: Modular.get<ImpressoraRaw>(),
    impressao: Modular.get<ImpressaoFiscal>(),
  );
  try {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Impressoras',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, _, _) =>
          _ConfiguracaoImpressaoDialog(controller: controller),
    );
  } finally {
    controller.dispose();
  }
}

class _ConfiguracaoImpressaoDialog extends StatefulWidget {
  const _ConfiguracaoImpressaoDialog({required this.controller});

  final ConfiguracaoImpressaoController controller;

  @override
  State<_ConfiguracaoImpressaoDialog> createState() =>
      _ConfiguracaoImpressaoDialogState();
}

class _ConfiguracaoImpressaoDialogState
    extends State<_ConfiguracaoImpressaoDialog> {
  ConfiguracaoImpressaoController get _ctrl => widget.controller;

  /// Faixa oferecida para o módulo do QR; 4 ou 5 é o usual em 203 dpi.
  static const _modulos = [3, 4, 5, 6];

  @override
  void initState() {
    super.initState();
    _ctrl.carregar();
  }

  void _fechar() => Navigator.of(context).pop();

  Future<void> _salvar() async {
    final ok = await _ctrl.salvar();
    if (ok && mounted) _fechar();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
              width: 520,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _cabecalho(colors),
                    const SizedBox(height: 18),
                    if (_ctrl.carregando)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      ..._formulario(colors),
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
    return Row(
      children: [
        Icon(LucideIcons.printer, size: 20, color: colors.text),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Impressoras deste terminal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
              Text(
                'Cupom NFC-e na térmica de 80 mm (ESC/POS, sem diálogo).',
                style: TextStyle(fontSize: 12, color: colors.textMute),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Fechar (Esc)',
          onPressed: _ctrl.ocupado ? null : _fechar,
          icon: Icon(LucideIcons.x, size: 18, color: colors.textMute),
        ),
      ],
    );
  }

  List<Widget> _formulario(AppColors colors) {
    final c = _ctrl.configuracao;
    final mensagem = _ctrl.mensagem;
    return [
      const PdvFieldLabel('IMPRESSORA TÉRMICA'),
      const SizedBox(height: 6),
      _seletorImpressora(c, colors),
      const SizedBox(height: 16),
      const PdvFieldLabel('COLUNAS (A RÉGUA DO TESTE DEVE CABER EM UMA LINHA)'),
      const SizedBox(height: 6),
      _chips<int>(
        opcoes: ConfiguracaoImpressao.colunasPermitidas,
        selecionada: c.colunas,
        rotulo: (n) => '$n colunas',
        onSelecionar: _ctrl.escolherColunas,
        colors: colors,
      ),
      const SizedBox(height: 16),
      const PdvFieldLabel('MÓDULO DO QR (MEÇA NO TESTE: MÍNIMO 25 MM)'),
      const SizedBox(height: 6),
      _chips<int>(
        opcoes: _modulos,
        selecionada: c.moduloQr,
        rotulo: (n) => '$n',
        onSelecionar: _ctrl.escolherModuloQr,
        colors: colors,
      ),
      const SizedBox(height: 10),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: c.imprimirNaExpedicao,
        onChanged: _ctrl.ocupado
            ? null
            : (v) => _ctrl.escolherImprimirNaExpedicao(ligado: v),
        title: Text(
          'Estação de expedição',
          style: TextStyle(fontSize: 13.5, color: colors.text),
        ),
        subtitle: Text(
          'Imprime a nota sozinha quando ela é autorizada na fila de '
          'expedição. Ligue só no terminal da expedição.',
          style: TextStyle(fontSize: 12, color: colors.textMute),
        ),
      ),
      const SizedBox(height: 6),
      const PdvInfoBanner(
        'O DANFE da NF-e (A4) ainda abre no visualizador do Windows.',
      ),
      if (mensagem != null) ...[
        const SizedBox(height: 10),
        mensagem.erro
            ? PdvErrorBanner(mensagem.texto)
            : PdvInfoBanner(mensagem.texto, icon: LucideIcons.circleCheck),
      ],
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: PdvGhostButton(
              _ctrl.testando ? 'Imprimindo…' : 'Imprimir teste',
              onTap: _ctrl.ocupado || !c.termicaConfigurada
                  ? null
                  : _ctrl.imprimirTeste,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PdvPrimaryButton(
              label: 'Salvar',
              icon: LucideIcons.check,
              loading: _ctrl.salvando,
              enabled: !_ctrl.ocupado,
              onTap: _salvar,
            ),
          ),
        ],
      ),
    ];
  }

  Widget _seletorImpressora(ConfiguracaoImpressao c, AppColors colors) {
    final opcoes = _ctrl.opcoes;
    if (opcoes.isEmpty) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'Nenhuma impressora instalada no Windows.',
              style: TextStyle(fontSize: 13, color: colors.textMute),
            ),
          ),
          TextButton(
            onPressed: _ctrl.carregar,
            child: const Text('Atualizar lista'),
          ),
        ],
      );
    }
    return InputDecorator(
      decoration: pdvInputDecoration(context, hint: 'Escolha a térmica'),
      isEmpty: c.impressoraTermica == null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: c.impressoraTermica,
          isExpanded: true,
          isDense: true,
          items: [
            for (final nome in opcoes)
              DropdownMenuItem(
                value: nome,
                child: Text(
                  _ctrl.estaInstalada(nome) ? nome : '$nome (não encontrada)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _ctrl.ocupado ? null : _ctrl.escolherImpressora,
        ),
      ),
    );
  }

  Widget _chips<T>({
    required List<T> opcoes,
    required T selecionada,
    required String Function(T) rotulo,
    required ValueChanged<T> onSelecionar,
    required AppColors colors,
  }) {
    return Wrap(
      spacing: 8,
      children: [
        for (final opcao in opcoes)
          ChoiceChip(
            label: Text(rotulo(opcao)),
            selected: opcao == selecionada,
            onSelected: _ctrl.ocupado ? null : (_) => onSelecionar(opcao),
            selectedColor: colors.accentTint,
          ),
      ],
    );
  }
}
