import 'package:flutter/material.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/fiscal/data/cenario_mock_fiscal.dart';
import 'package:rabbit_pdv/features/fiscal/domain/nota_status.dart';
import 'package:rabbit_pdv/features/fiscal/presentation/notas_fiscais_controller.dart';

/// Ferramentas do Focus simulado (guia fiscal §11) para rodar o roteiro de
/// teste de tela. O painel só a mostra em build de debug (`kDebugMode`); com o
/// backend fora do modo mock, o header é ignorado e a alavanca responde 403.
class FerramentasMockFiscal extends StatelessWidget {
  const FerramentasMockFiscal({super.key, required this.controller});

  final NotasFiscaisController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final nota = controller.notaAtual;
    final podeConcluir = nota?.status == NotaStatus.enviada;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.warn.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MOCK FISCAL (DEBUG)',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: colors.warn,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Cenario(
                rotulo: 'Emissão',
                opcoes: CenarioMockFiscal.emissao,
                valor: controller.cenarioEmissao,
                onChanged: (v) => controller.cenarioEmissao = v,
              ),
              _Cenario(
                rotulo: 'Cancelamento',
                opcoes: CenarioMockFiscal.cancelamento,
                valor: controller.cenarioCancelamento,
                onChanged: (v) => controller.cenarioCancelamento = v,
              ),
              if (podeConcluir)
                for (final cenario in CenarioMockFiscal.desfecho)
                  TextButton(
                    onPressed: controller.ocupado
                        ? null
                        : () => controller.mockDesfecho(cenario),
                    child: Text('SEFAZ: $cenario'),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cenario extends StatelessWidget {
  const _Cenario({
    required this.rotulo,
    required this.opcoes,
    required this.valor,
    required this.onChanged,
  });

  final String rotulo;
  final List<String> opcoes;
  final String? valor;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$rotulo: ',
          style: TextStyle(fontSize: 12, color: colors.textMute),
        ),
        DropdownButton<String?>(
          value: valor,
          isDense: true,
          style: TextStyle(fontSize: 12, color: colors.text),
          items: [
            const DropdownMenuItem<String?>(child: Text('padrão')),
            for (final o in opcoes)
              DropdownMenuItem<String?>(value: o, child: Text(o)),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
