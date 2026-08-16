import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/registrar_venda_response.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/caixa_session_controller.dart';

/// Semáforo de teto de caixa. Lê o `cashCeilingStatus` corrente da sessão
/// (atualizado por vendas e sangrias via `aplicarTeto`) e mostra um indicador
/// compacto colorido pelo nível. Oculto quando não há teto/estado conhecido.
///
/// É só leitura: reage às notificações do [CaixaSessionController], não guarda
/// estado próprio.
class SemaforoTeto extends StatelessWidget {
  const SemaforoTeto({super.key, required this.session});

  final CaixaSessionController session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final st = session.cashCeilingStatus;
        if (st == null || st.nivel == NivelTeto.desconhecido) {
          return const SizedBox.shrink();
        }
        return _pill(context, st);
      },
    );
  }

  Widget _pill(BuildContext context, CashCeilingStatus st) {
    final colors = context.colors;
    final cor = _cor(st.nivel, colors);
    final bloqueia =
        st.nivel == NivelTeto.vermelho &&
        (st.mode ?? '').toUpperCase() == 'IMMEDIATE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cor.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            bloqueia ? LucideIcons.lock : LucideIcons.banknote,
            size: 13,
            color: cor,
          ),
          const SizedBox(width: 6),
          Text(
            _label(st.nivel),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
          if (st.currentCash != null) ...[
            Text(
              '  ·  ',
              style: TextStyle(fontSize: 12, color: colors.textMute),
            ),
            Text(
              BrlFormatter.format(st.currentCash),
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _cor(NivelTeto n, AppColors colors) => switch (n) {
    NivelTeto.verde => colors.success,
    NivelTeto.amarelo => const Color(0xFFF59E0B), // âmbar (sem token de tema)
    NivelTeto.vermelho => colors.danger,
    NivelTeto.desconhecido => colors.textMute,
  };

  String _label(NivelTeto n) => switch (n) {
    NivelTeto.verde => 'Caixa ok',
    NivelTeto.amarelo => 'Atenção',
    NivelTeto.vermelho => 'No teto',
    NivelTeto.desconhecido => '',
  };
}
