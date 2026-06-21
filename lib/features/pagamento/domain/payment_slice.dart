import 'package:flutter/material.dart';
import 'package:rabbit_pdv/domain/enums/metodo_pagamento.dart';

/// Uma forma de pagamento dentro do checkout (Passo B). Cada slice vira um
/// [Pagamento] ao confirmar. O slice "Restante" absorve os itens não
/// atribuídos a nenhum slice específico — existe sempre, único.
@immutable
class PaymentSlice {
  final String id;
  final bool isRestante;
  final MetodoPagamento? metodo;

  /// Índice na paleta [SliceColors]; resolve fundo + acento pelo tema.
  final int colorIndex;

  /// Só relevante quando [metodo] é dinheiro. 0 enquanto não digitado.
  final double valorRecebido;

  const PaymentSlice({
    required this.id,
    required this.isRestante,
    required this.colorIndex,
    this.metodo,
    this.valorRecebido = 0,
  });

  PaymentSlice copyWith({
    MetodoPagamento? metodo,
    double? valorRecebido,
    bool clearMetodo = false,
  }) {
    return PaymentSlice(
      id: id,
      isRestante: isRestante,
      colorIndex: colorIndex,
      metodo: clearMetodo ? null : (metodo ?? this.metodo),
      valorRecebido: valorRecebido ?? this.valorRecebido,
    );
  }
}

/// Paleta dos slices: fundo neutro e suave + acento discreto (stripe/chip).
/// Tons dessaturados, distinguíveis mas calmos. Index 0 = Restante.
class SliceColors {
  static const _bgLight = <Color>[
    Color(0xFFEDEFF2), // cinza azulado (restante)
    Color(0xFFEAEEF4), // azul névoa
    Color(0xFFEFEBF3), // lilás névoa
    Color(0xFFEDF1EC), // verde névoa
    Color(0xFFF3ECEA), // coral/areia névoa
    Color(0xFFE9F0F0), // teal névoa
  ];
  static const _bgDark = <Color>[
    Color(0xFF2A2F36),
    Color(0xFF28303A),
    Color(0xFF2F2C39),
    Color(0xFF2A332E),
    Color(0xFF352E2C),
    Color(0xFF283434),
  ];
  static const _accentLight = <Color>[
    Color(0xFF8A93A1),
    Color(0xFF5E7BA8),
    Color(0xFF8A6FA8),
    Color(0xFF5E9B7A),
    Color(0xFFB07F6A),
    Color(0xFF5E9B9B),
  ];
  static const _accentDark = <Color>[
    Color(0xFF98A2B0),
    Color(0xFF85A3CF),
    Color(0xFFA68FD0),
    Color(0xFF7FBF9C),
    Color(0xFFCF9C85),
    Color(0xFF7FBFBF),
  ];

  static Color bg(int index, {required bool dark}) {
    final p = dark ? _bgDark : _bgLight;
    return p[index % p.length];
  }

  static Color accent(int index, {required bool dark}) {
    final p = dark ? _accentDark : _accentLight;
    return p[index % p.length];
  }

  static int get count => _bgLight.length;
}
