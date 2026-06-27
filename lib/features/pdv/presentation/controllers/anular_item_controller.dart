import 'package:flutter/foundation.dart';
import 'package:rabbit_pdv/features/pdv/data/anulacao_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/anular_item_dtos.dart';
import 'package:uuid/uuid.dart';

/// Motivos da anulação. `wire` é o valor de contrato enviado ao backend.
enum ReasonCategory {
  wrongScan('WRONG_SCAN', 'Bipagem errada'),
  duplicateScan('DUPLICATE_SCAN', 'Item duplicado'),
  customerGaveUp('CUSTOMER_GAVE_UP', 'Cliente desistiu'),
  priceDisagreement('PRICE_DISAGREEMENT', 'Discordância de preço'),
  other('OTHER', 'Outro');

  const ReasonCategory(this.wire, this.label);
  final String wire;
  final String label;
}

/// Orquestra UMA anulação de item (liberação do fiscal/gerente).
///
/// O [eventId] é gerado UMA vez no construtor e reusado em retries — é o que
/// garante a idempotência (201 grava agora / 200 devolve o mesmo registro).
/// Descartável: um controller por anulação. O chamador só remove o item do
/// carrinho local quando [autorizar] devolve resposta não-nula.
class AnularItemController extends ChangeNotifier {
  AnularItemController(
    this._repo, {
    required this.cashSessionId,
    required this.cartRef,
    required String produtoId,
    required this.sku,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineDiscountAmount,
  }) : _produtoId = produtoId,
       _eventId = const Uuid().v4();

  final AnulacaoRepository _repo;

  final String cashSessionId;
  final String? cartRef;
  final String _produtoId;
  final String sku;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double lineDiscountAmount;

  final String _eventId;

  bool _loading = false;
  bool get loading => _loading;

  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  ReasonCategory? _reason;
  ReasonCategory? get reason => _reason;

  String _reasonNote = '';
  String get reasonNote => _reasonNote;

  bool get _reasonOk =>
      _reason != null &&
      (_reason != ReasonCategory.other || _reasonNote.trim().isNotEmpty);

  /// Habilita a CTA "Autorizar". Credenciais vazias são validadas no submit.
  bool get podeAutorizar => _reasonOk && !_loading;

  void toggleObscure() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void setReason(ReasonCategory r) {
    _reason = r;
    _errorMessage = null;
    notifyListeners();
  }

  void setReasonNote(String v) {
    _reasonNote = v;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Devolve a resposta (201/200) em sucesso; null em falha (com [errorMessage]
  /// preenchido). Reusa o MESMO [_eventId] em cada tentativa.
  Future<AnularItemResponse?> autorizar({
    required String loginCode,
    required String password,
  }) async {
    final code = loginCode.trim();
    if (code.isEmpty || password.isEmpty) {
      _errorMessage = 'Informe o código e a senha do supervisor.';
      notifyListeners();
      return null;
    }
    if (_reason == null) {
      _errorMessage = 'Selecione o motivo da anulação.';
      notifyListeners();
      return null;
    }
    if (_reason == ReasonCategory.other && _reasonNote.trim().isEmpty) {
      _errorMessage = 'Descreva o motivo (obrigatório para "Outro").';
      notifyListeners();
      return null;
    }

    _loading = true;
    _errorMessage = null;
    notifyListeners();

    final req = AnularItemRequest(
      eventId: _eventId,
      cartRef: cartRef,
      cashSessionId: cashSessionId,
      supervisorLoginCode: code,
      supervisorPassword: password,
      productId: _uuidOrNull(_produtoId),
      sku: sku,
      productName: productName,
      quantity: quantity,
      unitPrice: unitPrice,
      lineDiscountAmount: lineDiscountAmount,
      reasonCategory: _reason!.wire,
      reasonNote: _reason == ReasonCategory.other ? _reasonNote.trim() : null,
      clientReportedAt: DateTime.now().toUtc().toIso8601String(),
    );

    final result = await _repo.anularItem(req);
    return result.fold<AnularItemResponse?>(
      onOk: (resp) {
        _loading = false;
        notifyListeners();
        return resp;
      },
      onErr: (f) {
        _loading = false;
        _errorMessage = f.message;
        notifyListeners();
        return null;
      },
    );
  }
}

/// Produto de catálogo real traz UUID; produto de mock traz "mock-...".
/// O contrato pede `productId: uuid|null` — então mandamos null quando não for
/// um UUID, evitando 400 por id malformado.
String? _uuidOrNull(String s) {
  final re = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  return re.hasMatch(s) ? s : null;
}
