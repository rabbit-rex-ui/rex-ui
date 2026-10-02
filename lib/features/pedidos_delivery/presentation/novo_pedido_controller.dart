import 'package:flutter/foundation.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/domain/entities/produto.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/criar_pedido_request.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/criar_pedido_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/pedido_delivery_repository.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/item_pedido_cart.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/momento_pagamento.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_canal.dart';
import 'package:uuid/uuid.dart';

/// Orquestra a criação de UM pedido de delivery (`POST /pdv/pedidos`, §4.1).
///
/// O [_idempotencyKey] é um UUIDv7 gerado UMA vez no construtor e reusado em
/// todo retry — nunca regenerado. É o que garante a idempotência da criação
/// (201 grava agora / 200 devolve o mesmo pedido). Descartável: um controller
/// por pedido em digitação.
///
/// [defaultWarehouseId] vem pronto do chamador (contexto do terminal/loja),
/// como o `sessionId` da sangria. Identidade do operador e tenant vêm do JWT —
/// nunca do corpo (§2).
class NovoPedidoController extends ChangeNotifier {
  NovoPedidoController(this._repo, {required this.defaultWarehouseId})
    : _idempotencyKey = const Uuid().v7();

  final PedidoDeliveryRepository _repo;
  final String defaultWarehouseId;

  final String _idempotencyKey;

  /// Formato UUID canônico (36 chars, 8-4-4-4-12). O backend exige isso em
  /// `produtoId`; validar aqui evita um `400 json-invalido` opaco quando o
  /// catálogo devolve id fora do padrão (mock/legado).
  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  // ── Cliente ──
  PedidoCanal _canal = PedidoCanal.telefone;
  PedidoCanal get canal => _canal;

  String _customerName = '';
  String get customerName => _customerName;

  String _customerDoc = '';
  String get customerDoc => _customerDoc;

  String _customerPhone = '';
  String get customerPhone => _customerPhone;

  // ── Endereço ──
  String _line = '';
  String get line => _line;

  String _number = '';
  String get number => _number;

  String _complement = '';
  String get complement => _complement;

  String _district = '';
  String get district => _district;

  String _cityIbge = '';
  String get cityIbge => _cityIbge;

  String _zip = '';
  String get zip => _zip;

  // ── Pagamento / extras ──
  MomentoPagamento _momentoPagamento = MomentoPagamento.padrao;
  MomentoPagamento get momentoPagamento => _momentoPagamento;

  double _frete = 0;
  double get frete => _frete;

  String _notes = '';
  String get notes => _notes;

  // ── Itens ──
  final List<ItemPedidoCart> _itens = [];
  List<ItemPedidoCart> get itens => List<ItemPedidoCart>.unmodifiable(_itens);

  int _proximoItemId = 1;

  // ── Estado operacional ──
  bool _loading = false;
  bool get loading => _loading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Subtotal estimado (itens + frete). Estimativa de UI; o backend recalcula
  /// o `valorEstimado` oficial na criação (§4.1).
  double get valorEstimadoLocal =>
      _itens.fold<double>(0, (soma, i) => soma + i.subtotal) + _frete;

  /// Habilita a CTA de criar: cliente e endereço mínimos preenchidos e ao
  /// menos um item. O backend é a autoridade final da validação.
  bool get podeCriar =>
      !_loading &&
      _customerName.trim().isNotEmpty &&
      _line.trim().isNotEmpty &&
      _itens.isNotEmpty;

  // ── Setters do formulário ──
  void setCanal(PedidoCanal v) {
    _canal = v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  void setCustomerName(String v) {
    _customerName = v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  void setCustomerDoc(String v) {
    _customerDoc = v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  void setCustomerPhone(String v) {
    _customerPhone = v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  void setLine(String v) {
    _line = v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  void setNumber(String v) {
    _number = v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  void setComplement(String v) {
    _complement = v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  void setDistrict(String v) {
    _district = v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  void setCityIbge(String v) {
    _cityIbge = v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  void setZip(String v) {
    _zip = v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  void setMomentoPagamento(MomentoPagamento v) {
    _momentoPagamento = v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  void setFrete(double v) {
    _frete = v < 0 ? 0 : v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  void setNotes(String v) {
    _notes = v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  // ── Gerência de itens ──
  /// Adiciona um produto ao carrinho. Se já estiver presente, incrementa a
  /// quantidade em vez de duplicar a linha.
  void adicionarProduto(Produto produto, {double? qtdInicial}) {
    final idx = _itens.indexWhere((i) => i.produtoId == produto.id);
    if (idx >= 0) {
      final atual = _itens[idx];
      _itens[idx] = atual.copyWith(qtd: atual.qtd + (qtdInicial ?? 1));
    } else {
      _itens.add(
        ItemPedidoCart.fromProduto(
          produto,
          id: _proximoItemId++,
          qtdInicial: qtdInicial,
        ),
      );
    }
    _clearErrorSilencioso();
    notifyListeners();
  }

  void removerItem(int id) {
    _itens.removeWhere((i) => i.id == id);
    _clearErrorSilencioso();
    notifyListeners();
  }

  /// Altera a quantidade de uma linha. Quantidade `<= 0` remove a linha.
  void alterarQuantidade(int id, double qtd) {
    final idx = _itens.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    if (qtd <= 0) {
      _itens.removeAt(idx);
    } else {
      _itens[idx] = _itens[idx].copyWith(qtd: qtd);
    }
    _clearErrorSilencioso();
    notifyListeners();
  }

  void alterarObservacaoItem(int id, String observacao) {
    final idx = _itens.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    _itens[idx] = _itens[idx].copyWith(observacao: observacao);
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _clearErrorSilencioso() => _errorMessage = null;

  /// Cria o pedido. Devolve a resposta (201/200) em sucesso; `null` em falha
  /// (com [errorMessage] preenchido). Reusa o MESMO [_idempotencyKey] em cada
  /// tentativa — retry após timeout não duplica o pedido (§4.1).
  Future<CriarPedidoResponse?> criar() async {
    // Validação client-side (o backend é a autoridade; evitamos idas óbvias).
    if (_customerName.trim().isEmpty) {
      _errorMessage = 'Informe o nome do cliente.';
      notifyListeners();
      return null;
    }
    if (_line.trim().isEmpty) {
      _errorMessage = 'Informe o endereço de entrega.';
      notifyListeners();
      return null;
    }
    if (_itens.isEmpty) {
      _errorMessage = 'Adicione ao menos um item ao pedido.';
      notifyListeners();
      return null;
    }
    // Salvaguarda: `produtoId` precisa ser UUID (§4.1). Barra catálogo
    // desatualizado/mock antes de um `400 json-invalido` opaco do backend.
    final invalido = _itens
        .where((i) => !_uuidRe.hasMatch(i.produtoId))
        .toList();
    if (invalido.isNotEmpty) {
      final nomes = invalido.map((i) => i.nome).join(', ');
      _errorMessage =
          'Produto sem identificador válido: $nomes. Atualize o catálogo.';
      notifyListeners();
      return null;
    }

    _loading = true;
    _errorMessage = null;
    notifyListeners();

    final req = _montarRequest();
    final result = await _repo.criar(req, idempotencyKey: _idempotencyKey);

    return result.fold<CriarPedidoResponse?>(
      onOk: (resp) {
        _loading = false;
        notifyListeners();
        return resp;
      },
      onErr: (f) {
        _loading = false;
        _rotearErro(f);
        notifyListeners();
        return null;
      },
    );
  }

  CriarPedidoRequest _montarRequest() {
    String? limpar(String v) => v.trim().isEmpty ? null : v.trim();

    return CriarPedidoRequest(
      canal: _canal,
      defaultWarehouseId: defaultWarehouseId,
      customerName: _customerName.trim(),
      endereco: EnderecoDto(
        line: _line.trim(),
        number: limpar(_number),
        complement: limpar(_complement),
        district: limpar(_district),
        cityIbge: limpar(_cityIbge),
        zip: limpar(_zip),
      ),
      itens: _itens
          .map(
            (i) => ItemPedidoDto(
              produtoId: i.produtoId,
              quantidade: i.qtd,
              observacao: i.observacao,
            ),
          )
          .toList(),
      customerDoc: limpar(_customerDoc),
      customerPhone: limpar(_customerPhone),
      momentoPagamento: _momentoPagamento,
      frete: _frete > 0 ? _frete : null,
      notes: limpar(_notes),
    );
  }

  /// Traduz a falha em UX. A criação produz basicamente `ValidationFailure`
  /// (400) e falhas de rede/acesso — todas já trazem `message` adequada do
  /// `ApiClient`, então usamos `f.message` direto. O roteamento por `code`
  /// específico (dois 409, `pedido-invalido`) pertence às transições da Fase 2,
  /// não à criação.
  void _rotearErro(Failure f) {
    _errorMessage = f.message;
  }
}
