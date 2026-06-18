import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/core/widgets/app_button.dart';
import 'package:rabbit_pdv/core/widgets/app_kbd.dart';
import 'package:rabbit_pdv/domain/entities/atendimento.dart';
import 'package:rabbit_pdv/domain/entities/cliente.dart';
import 'package:rabbit_pdv/domain/enums/cliente_tipo.dart';

class SidePanel extends StatelessWidget {
  final Atendimento session;
  final VoidCallback onTapCliente;
  final VoidCallback onFinalizar;

  const SidePanel({
    super.key,
    required this.session,
    required this.onTapCliente,
    required this.onFinalizar,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(left: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClientCard(cliente: session.cliente, onTap: onTapCliente),
          TotalsBlock(
            subtotal: session.subtotal,
            desconto: session.desconto,
            total: session.total,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppButton(
              label: 'Finalizar atendimento',
              variant: BtnVariant.primary,
              size: BtnSize.xl,
              icon: LucideIcons.check,
              kbd: 'F5',
              full: true,
              onPressed: session.estaVazio ? null : onFinalizar,
            ),
          ),
        ],
      ),
    );
  }
}

class ClientCard extends StatelessWidget {
  final Cliente cliente;
  final VoidCallback onTap;

  const ClientCard({super.key, required this.cliente, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cadastrado = cliente.tipo == ClienteTipo.cadastrado;
    final temDoc = cliente.doc != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'CLIENTE',
                style: AppText.overline.copyWith(color: c.textMute),
              ),
              const Spacer(),
              const AppKbd('F2'),
            ],
          ),
          const SizedBox(height: 10),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: c.surface2,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cadastrado ? c.accent : c.surface3,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.user,
                        size: 16,
                        color: cadastrado ? c.accentInk : c.textMute,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cliente.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body.copyWith(
                              color: c.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (temDoc) ...[
                            const SizedBox(height: 2),
                            Text(
                              cliente.doc!,
                              style: AppText.monoSm.copyWith(
                                color: c.textMute,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TotalsBlock extends StatelessWidget {
  final double subtotal;
  final double desconto;
  final double total;

  const TotalsBlock({
    super.key,
    required this.subtotal,
    required this.desconto,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _line(context, 'SUBTOTAL', BrlFormatter.format(subtotal), c.text),
          if (desconto > 0) ...[
            const SizedBox(height: 8),
            _line(
              context,
              'DESCONTO',
              '− ${BrlFormatter.format(desconto)}',
              c.success,
            ),
          ],
          const SizedBox(height: 12),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'TOTAL',
                style: AppText.overline.copyWith(color: c.textMute),
              ),
              const Spacer(),
              Text(
                BrlFormatter.format(total),
                style: AppText.display.copyWith(color: c.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value, Color valueColor) {
    final c = context.colors;
    return Row(
      children: [
        Text(label, style: AppText.overline.copyWith(color: c.textMute)),
        const Spacer(),
        Text(
          value,
          style: AppText.monoMd.copyWith(
            color: valueColor,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
