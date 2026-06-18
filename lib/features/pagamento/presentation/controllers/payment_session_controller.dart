import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:rabbit_pdv/domain/entities/atendimento.dart';
import 'package:rabbit_pdv/domain/entities/pagamento.dart';
import 'package:rabbit_pdv/domain/enums/metodo_pagamento.dart';

/// Estado do modal de pagamento (Passo A — pagamento único).
///
/// Vida útil = vida útil do modal. Instanciado quando o modal abre,
/// descartado (dispose) quando fecha. Sem persistência: cancelar e
/// reabrir começa do zero, conforme regra de UX.
///
/// **Por que ChangeNotifier ao invés de criar um sub-domínio com Slice?**
/// O Passo A trata apenas o caminho de pagamento único (1 método cobrindo
/// 100% da venda). O conceito de *slice* da doc só faz sentido quando há
/// múltiplos métodos. Quando o Passo B for implementado, este controller
/// passa a manter `List<PaymentSlice>` e `Map<itemId, sliceId>` — a
/// interface pública pra UI muda pouco (mesmos `setMetodo`, `confirmar`).
class PaymentSessionController extends ChangeNotifier {
  PaymentSessionController({required this.atendimento});

  final Atendimento atendimento;
  final _uuid = const Uuid();

  // ---- Estado --------------------------------------------------------------

  MetodoPagamento? _metodo;
  MetodoPagamento? get metodo => _metodo;

  /// Apenas relevante quando [metodo] é [MetodoPagamento.dinheiro].
  /// `0` enquanto operador não digita. Não é nullable porque é mais
  /// ergonômico tratar "vazio" como zero na soma e validação.
  double _valorRecebido = 0;
  double get valorRecebido => _valorRecebido;

  // ---- Computeds -----------------------------------------------------------

  double get total => atendimento.total;

  /// Troco devolvido ao cliente. Só faz sentido em dinheiro; em outros
  /// métodos retorna 0.
  double get troco {
    if (_metodo != MetodoPagamento.dinheiro) return 0;
    final diff = _valorRecebido - total;
    return diff > 0 ? diff : 0;
  }

  /// Valor que ainda falta receber. Negativo seria "troco"; positivo é
  /// insuficiência.
  double get faltam {
    if (_metodo != MetodoPagamento.dinheiro) return 0;
    final diff = total - _valorRecebido;
    return diff > 0 ? diff : 0;
  }

  /// CTA "Confirmar pagamento" liberada?
  ///
  /// - Precisa de método escolhido.
  /// - Se dinheiro, precisa `valorRecebido >= total`.
  /// - Atendimento precisa ter itens (sanity check).
  bool get podeConfirmar {
    if (atendimento.estaVazio) return false;
    if (_metodo == null) return false;
    if (_metodo == MetodoPagamento.dinheiro && _valorRecebido < total) {
      return false;
    }
    return true;
  }

  /// Texto curto explicando por que a CTA está bloqueada (footer warn).
  /// Retorna `null` quando está OK.
  String? get motivoBloqueio {
    if (atendimento.estaVazio) return 'Atendimento sem itens';
    if (_metodo == null) return 'Selecione a forma de pagamento';
    if (_metodo == MetodoPagamento.dinheiro && _valorRecebido < total) {
      return 'Valor recebido insuficiente';
    }
    return null;
  }

  // ---- Ações ---------------------------------------------------------------

  void setMetodo(MetodoPagamento m) {
    if (_metodo == m) return;
    _metodo = m;
    // Quando muda PRA dinheiro, prefill valorRecebido com o total (atalho
    // comum: "cliente deu valor justo" — operador só confirma).
    // Quando muda DE dinheiro pra outro, zera para evitar inconsistência.
    if (m == MetodoPagamento.dinheiro) {
      if (_valorRecebido == 0) _valorRecebido = total;
    } else {
      _valorRecebido = 0;
    }
    notifyListeners();
  }

  void setValorRecebido(double v) {
    final clamped = v < 0 ? 0.0 : v;
    if (_valorRecebido == clamped) return;
    _valorRecebido = clamped;
    notifyListeners();
  }

  /// Constrói a lista de [Pagamento]s a serem persistidos. No Passo A
  /// sempre retorna 1 item; no Passo B retornará N (um por slice).
  List<Pagamento> buildPagamentos() {
    if (!podeConfirmar) {
      throw StateError('buildPagamentos chamado em estado inválido');
    }
    return [
      Pagamento(
        id: _uuid.v4(),
        metodo: _metodo!,
        valor: total,
        valorRecebido:
            _metodo == MetodoPagamento.dinheiro ? _valorRecebido : null,
        troco: _metodo == MetodoPagamento.dinheiro ? troco : null,
        processadoEm: DateTime.now(),
      ),
    ];
  }
}
