import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Builder para [ErrorWidget.builder]. Substitui a "tela vermelha" padrão
/// por um placeholder discreto.
///
/// Em **debug** mostra a exception (operadores não vão ver em produção,
/// mas devs precisam).
///
/// Em **release** mostra apenas um aviso neutro — operador não fica
/// assustado e a venda em curso continua acessível pelos demais painéis,
/// já que só este sub-widget falhou.
///
/// Importante: este builder pode ser invocado **fora** de um MaterialApp
/// (ex: se o erro acontece no próprio MaterialApp). Por isso usamos
/// widgets primitivos (Container/Text) e provemos Directionality.
Widget buildErrorWidget(FlutterErrorDetails details) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      color: const Color(0xFFFFF4F4),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 32,
            color: Color(0xFFB91C1C),
          ),
          const SizedBox(height: 8),
          const Text(
            'Falha ao renderizar este componente',
            style: TextStyle(
              color: Color(0xFFB91C1C),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                details.exceptionAsString(),
                style: const TextStyle(
                  color: Color(0xFF7F1D1D),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
