import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:rabbit_pdv/domain/entities/atendimento.dart';
import 'package:rabbit_pdv/domain/entities/item_atendimento.dart';
import 'package:rabbit_pdv/domain/entities/pagamento.dart';
import 'package:rabbit_pdv/domain/enums/metodo_pagamento.dart';
import 'package:rabbit_pdv/features/pagamento/domain/payment_slice.dart';
import 'package:rabbit_pdv/features/pagamento/domain/payment_state.dart';

/// Estado do modal de pagamento (Passo B — pagamento misto por item).
///
/// Modelo de slices com atribuição exclusiva por item ([assignment]).
/// Pode ser criado do zero ou hidratado de um [PaymentState] salvo,
/// reconciliando com os itens atuais do atendimento.
class PaymentSessionController extends ChangeNotifier {
  PaymentSessionController({required Atendimento atendimento})
    : _atendimento = atendimento {
    final restante = PaymentSlice(
      id: _uuid.v4(),
      isRestante: true,
      colorIndex: 0,
    );
    _slices = [restante];
    _activeSliceId = restante.id;
  }

  PaymentSessionController.fromState({
    required Atendimento atendimento,
    required PaymentState state,
  }) : _atendimento = atendimento {
    final temRestante = state.slices.any((s) => s.isRestante);
    _slices = temRestante
        ? List.of(state.slices)
        : [
            PaymentSlice(id: _uuid.v4(), isRestante: true, colorIndex: 0),
            ...state.slices,
          ];

    final idsValidos = _itens.map((i) => i.id).toSet();
    final sliceIdsValidos = _slices.map((s) => s.id).toSet();
    _assignment
      ..clear()
      ..addEntries(
        state.assignment.entries.where(
          (e) =>
              idsValidos.contains(e.key) && sliceIdsValidos.contains(e.value),
        ),
      );

    _activeSliceId = sliceIdsValidos.contains(state.activeSliceId)
        ? state.activeSliceId
        : _slices.firstWhere((s) => s.isRestante).id;
  }

  final Atendimento _atendimento;
  Atendimento get atendimento => _atendimento;

  final _uuid = const Uuid();

  late List<PaymentSlice> _slices;
  List<PaymentSlice> get slices => List.unmodifiable(_slices);

  final Map<int, String> _assignment = {};
  Map<int, String> get assignment => Map.unmodifiable(_assignment);

  late String _activeSliceId;
  String get activeSliceId => _activeSliceId;

  PaymentSlice get activeSlice =>
      _slices.firstWhere((s) => s.id == _activeSliceId);

  PaymentSlice get _restante => _slices.firstWhere((s) => s.isRestante);

  List<ItemAtendimento> get _itens => _atendimento.itens;

  PaymentState exportState() => PaymentState(
    slices: List.of(_slices),
    assignment: Map.of(_assignment),
    activeSliceId: _activeSliceId,
  );

  // ---- Itens / valores por slice -------------------------------------------

  List<ItemAtendimento> itemsOfSlice(String sliceId) {
    final s = _slices.firstWhere((x) => x.id == sliceId);
    if (s.isRestante) {
      return _itens.where((i) => !_assignment.containsKey(i.id)).toList();
    }
    return _itens.where((i) => _assignment[i.id] == sliceId).toList();
  }

  int itemCountOfSlice(String sliceId) => itemsOfSlice(sliceId).length;

  double _valorBruto(String sliceId) =>
      itemsOfSlice(sliceId).fold(0.0, (sum, i) => sum + i.total);

  static double _arredonda(double v) => (v * 100).roundToDouble() / 100;

  /// Valor do slice em CENTAVOS REDONDOS, com o desconto de cabeçalho rateado
  /// proporcionalmente. O resíduo de arredondamento é alocado na âncora
  /// (Restante, ou o último slice com itens) para que a soma feche com o total.
  double valorSlice(String sliceId) {
    final desconto = _atendimento.desconto;
    final subtotal = _atendimento.subtotal;

    // Sem desconto de cabeçalho: valores já são exatos.
    if (desconto <= 0 || subtotal <= 0) {
      return _arredonda(_valorBruto(sliceId));
    }

    final fator = _atendimento.total / subtotal;
    final base = _arredonda(_valorBruto(sliceId) * fator);

    // Âncora recebe o resíduo (total - soma dos demais arredondados).
    if (sliceId != _ancoraId) return base;

    final somaOutros = _slices
        .where((s) => s.id != sliceId)
        .fold(0.0, (sum, s) => sum + _arredonda(_valorBruto(s.id) * fator));
    return _arredonda(_atendimento.total - somaOutros);
  }

  /// Slice que absorve o resíduo de centavo: o Restante se tiver itens; senão
  /// o último slice com itens.
  String get _ancoraId {
    if (itemCountOfSlice(_restante.id) > 0) return _restante.id;
    final comItens = _slices.where((s) => itemCountOfSlice(s.id) > 0);
    return comItens.isEmpty ? _restante.id : comItens.last.id;
  }

  double get total => _atendimento.total;

  double get alocado => _slices.fold(0.0, (sum, s) => sum + valorSlice(s.id));

  // ---- Troco (dinheiro) ----------------------------------------------------

  double trocoDoSlice(String sliceId) {
    final s = _slices.firstWhere((x) => x.id == sliceId);
    if (s.metodo != MetodoPagamento.dinheiro) return 0;
    final diff = _arredonda(s.valorRecebido - valorSlice(sliceId));
    return diff > 0 ? diff : 0;
  }

  double faltamNoSlice(String sliceId) {
    final s = _slices.firstWhere((x) => x.id == sliceId);
    if (s.metodo != MetodoPagamento.dinheiro) return 0;
    final diff = _arredonda(valorSlice(sliceId) - s.valorRecebido);
    return diff > 0 ? diff : 0;
  }

  // ---- Regra do dinheiro (exclusividade só entre si) -----------------------

  /// Dinheiro pode ser escolhido neste slice? Não, se já há dinheiro em OUTRO.
  /// (Dinheiro aparece no máximo uma vez; demais métodos podem repetir.)
  bool dinheiroDisponivelPara(String sliceId) {
    return !_slices.any(
      (s) => s.id != sliceId && s.metodo == MetodoPagamento.dinheiro,
    );
  }

  /// Adicionar forma NUNCA é bloqueado por dinheiro — dinheiro só restringe
  /// o picker das outras formas.
  bool get podeAdicionarForma => true;

  // ---- Validação -----------------------------------------------------------

  bool _slicePendente(PaymentSlice s) {
    final vazio = itemCountOfSlice(s.id) == 0;
    if (s.isRestante && vazio) return false;
    if (vazio) return true;
    if (s.metodo == null) return true;
    if (s.metodo == MetodoPagamento.dinheiro &&
        s.valorRecebido < valorSlice(s.id)) {
      return true;
    }
    return false;
  }

  bool get podeConfirmar {
    if (_atendimento.estaVazio) return false;
    return !_slices.any(_slicePendente);
  }

  String? get motivoBloqueio {
    if (_atendimento.estaVazio) return 'Atendimento sem itens';

    final semItens = _slices
        .where((s) => !s.isRestante && itemCountOfSlice(s.id) == 0)
        .length;
    if (semItens > 0) {
      return semItens == 1
          ? '1 forma sem itens atribuídos'
          : '$semItens formas sem itens atribuídos';
    }

    final semMetodo = _slices
        .where((s) => !(s.isRestante && itemCountOfSlice(s.id) == 0))
        .where((s) => s.metodo == null)
        .length;
    if (semMetodo > 0) return 'Selecione o método de cada forma';

    final dinheiroInsuf = _slices.any(
      (s) =>
          s.metodo == MetodoPagamento.dinheiro &&
          s.valorRecebido < valorSlice(s.id),
    );
    if (dinheiroInsuf) return 'Valor recebido insuficiente em dinheiro';

    return null;
  }

  // ---- Ações ---------------------------------------------------------------

  void setActiveSlice(String sliceId) {
    if (_activeSliceId == sliceId) return;
    _activeSliceId = sliceId;
    notifyListeners();
  }

  void addSlice() {
    final usados = _slices.map((s) => s.colorIndex).toSet();
    var idx = 1;
    while (usados.contains(idx) && idx < SliceColors.count) {
      idx++;
    }
    if (idx >= SliceColors.count) idx = _slices.length % SliceColors.count;
    final novo = PaymentSlice(
      id: _uuid.v4(),
      isRestante: false,
      colorIndex: idx,
    );
    _slices = [..._slices, novo];
    _activeSliceId = novo.id;
    notifyListeners();
  }

  void removeSlice(String sliceId) {
    final s = _slices.firstWhere((x) => x.id == sliceId);
    if (s.isRestante) return;
    _assignment.removeWhere((_, sid) => sid == sliceId);
    _slices = _slices.where((x) => x.id != sliceId).toList();
    if (_activeSliceId == sliceId) _activeSliceId = _restante.id;
    notifyListeners();
  }

  void toggleItem(int itemId) {
    final ativo = activeSlice;
    if (ativo.isRestante) return; // Restante não recebe atribuição manual
    if (_assignment[itemId] == ativo.id) {
      _assignment.remove(itemId);
    } else {
      _assignment[itemId] = ativo.id;
    }
    _resyncDinheiroPrefill();
    notifyListeners();
  }

  String? sliceDoItem(int itemId) => _assignment[itemId];

  void setMetodo(String sliceId, MetodoPagamento m) {
    if (m == MetodoPagamento.dinheiro && !dinheiroDisponivelPara(sliceId)) {
      return;
    }
    final idx = _slices.indexWhere((x) => x.id == sliceId);
    if (idx < 0) return;
    final s = _slices[idx];
    if (s.metodo == m) return;
    // Prefill dinheiro com o valor (arredondado) do slice; zera ao sair.
    final novoRecebido = m == MetodoPagamento.dinheiro
        ? valorSlice(sliceId)
        : 0.0;
    _slices = [..._slices]
      ..[idx] = s.copyWith(metodo: m, valorRecebido: novoRecebido);
    notifyListeners();
  }

  void setValorRecebido(String sliceId, double v) {
    final idx = _slices.indexWhere((x) => x.id == sliceId);
    if (idx < 0) return;
    final clamped = v < 0 ? 0.0 : v;
    if (_slices[idx].valorRecebido == clamped) return;
    _slices = [..._slices]
      ..[idx] = _slices[idx].copyWith(valorRecebido: clamped);
    notifyListeners();
  }

  /// Quando itens migram entre slices, o valor de um slice em dinheiro muda.
  /// Reprefilla o valorRecebido SE o operador ainda não digitou um valor
  /// manual (heurística: recebido == 0 ou igual ao valor anterior do slice).
  void _resyncDinheiroPrefill() {
    var mudou = false;
    final novos = [..._slices];
    for (var i = 0; i < novos.length; i++) {
      final s = novos[i];
      if (s.metodo != MetodoPagamento.dinheiro) continue;
      final v = valorSlice(s.id);
      // Só reajusta se o recebido está "intocado" (0). Se o operador digitou,
      // respeita o valor dele.
      if (s.valorRecebido == 0) {
        novos[i] = s.copyWith(valorRecebido: v);
        mudou = true;
      }
    }
    if (mudou) _slices = novos;
  }

  // ---- Saída ---------------------------------------------------------------

  List<Pagamento> buildPagamentos() {
    if (!podeConfirmar) {
      throw StateError('buildPagamentos chamado em estado inválido');
    }
    final out = <Pagamento>[];
    for (final s in _slices) {
      if (itemCountOfSlice(s.id) == 0) continue;
      final isCash = s.metodo == MetodoPagamento.dinheiro;
      out.add(
        Pagamento(
          id: _uuid.v4(),
          metodo: s.metodo!,
          valor: valorSlice(s.id),
          valorRecebido: isCash ? s.valorRecebido : null,
          troco: isCash ? trocoDoSlice(s.id) : null,
          processadoEm: DateTime.now(),
        ),
      );
    }
    return out;
  }
}
