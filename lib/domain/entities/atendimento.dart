import 'package:equatable/equatable.dart';

import 'package:rabbit_pdv/domain/enums/atendimento_status.dart';
import 'package:rabbit_pdv/domain/entities/cliente.dart';
import 'package:rabbit_pdv/domain/entities/item_atendimento.dart';
import 'package:rabbit_pdv/domain/entities/produto.dart';

/// Unidade de venda em aberto. Equivalente à "comanda" ou "sessão de venda".
///
/// É **imutável**. Toda mutação retorna uma nova instância via [copyWith] ou
/// pelos métodos de transformação ([addProduto], [removeItem] etc.).
/// Isso simplifica raciocínio: o controller só precisa publicar a nova
/// instância na lista; sem necessidade de "patches" no lugar.
class Atendimento extends Equatable {
  final String id;

  /// Número visível na UI (`#01`, `#02`...). Estável durante a vida do
  /// atendimento.
  final int ordem;

  final Cliente cliente;
  final List<ItemAtendimento> itens;

  /// Desconto absoluto em R\$ sobre o subtotal.
  final double desconto;

  final AtendimentoStatus status;
  final DateTime abertaEm;

  /// Identificador do operador logado no momento da abertura.
  final String operadorId;

  const Atendimento({
    required this.id,
    required this.ordem,
    required this.cliente,
    required this.itens,
    required this.desconto,
    required this.status,
    required this.abertaEm,
    required this.operadorId,
  });

  /// Cria um atendimento vazio recém-aberto.
  factory Atendimento.novo({
    required String id,
    required int ordem,
    required String operadorId,
    Cliente cliente = Cliente.anonimo,
    DateTime? abertaEm,
  }) {
    return Atendimento(
      id: id,
      ordem: ordem,
      cliente: cliente,
      itens: const [],
      desconto: 0,
      status: AtendimentoStatus.digitando,
      abertaEm: abertaEm ?? DateTime.now(),
      operadorId: operadorId,
    );
  }

  // ---- Computeds -----------------------------------------------------------

  double get subtotal => itens.fold(0, (s, i) => s + i.total);

  double get total {
    final t = subtotal - desconto;
    return t < 0 ? 0 : t;
  }

  double get qtdTotal => itens.fold(0, (s, i) => s + i.qtd);

  int get numItens => itens.length;

  bool get estaVazio => itens.isEmpty;

  bool get estaFinalizado =>
      status == AtendimentoStatus.pago || status == AtendimentoStatus.cancelado;

  // ---- Mutações imutáveis --------------------------------------------------

  Atendimento copyWith({
    Cliente? cliente,
    List<ItemAtendimento>? itens,
    double? desconto,
    AtendimentoStatus? status,
  }) {
    return Atendimento(
      id: id,
      ordem: ordem,
      cliente: cliente ?? this.cliente,
      itens: itens ?? this.itens,
      desconto: desconto ?? this.desconto,
      status: status ?? this.status,
      abertaEm: abertaEm,
      operadorId: operadorId,
    );
  }

  /// Adiciona um produto. Se já existe linha com mesmo SKU, **incrementa**
  /// a quantidade (comportamento padrão de PDV brasileiro). Caso contrário,
  /// cria nova linha.
  Atendimento addProduto(Produto produto, {double? qtd}) {
    final idx = itens.indexWhere((i) => i.sku == produto.sku);
    if (idx >= 0) {
      final existente = itens[idx];
      final increment = qtd ??
          (produto.un == ItemAtendimento.fromProduto(produto, id: -1).un &&
                  existente.un.toString().contains('kg')
              ? 0.1
              : 1.0);
      final novo = existente.copyWith(qtd: existente.qtd + increment);
      final novos = [...itens];
      novos[idx] = novo;
      return copyWith(itens: novos);
    }

    final novoId = _nextItemId();
    final item = ItemAtendimento.fromProduto(
      produto,
      id: novoId,
      qtdInicial: qtd,
    );
    return copyWith(itens: [...itens, item]);
  }

  /// Ajusta a quantidade de uma linha. Quando a nova qtd chega a zero ou
  /// negativa, remove a linha.
  Atendimento ajustarQtd(int itemId, double delta) {
    final idx = itens.indexWhere((i) => i.id == itemId);
    if (idx < 0) return this;
    final atual = itens[idx];
    final nova = atual.qtd + delta;
    if (nova <= 0) {
      return removeItem(itemId);
    }
    final novos = [...itens];
    novos[idx] = atual.copyWith(qtd: nova);
    return copyWith(itens: novos);
  }

  Atendimento removeItem(int itemId) {
    return copyWith(itens: itens.where((i) => i.id != itemId).toList());
  }

  Atendimento limparItens() => copyWith(itens: const []);

  Atendimento setCliente(Cliente novoCliente) => copyWith(cliente: novoCliente);

  Atendimento setDesconto(double valor) =>
      copyWith(desconto: valor < 0 ? 0 : valor);

  Atendimento marcarComoStatus(AtendimentoStatus s) => copyWith(status: s);

  int _nextItemId() {
    if (itens.isEmpty) return 1;
    return itens.map((i) => i.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Mapa sku → qtd formatada, usado pelo grid de Atalhos para mostrar
  /// o badge "no carrinho" nos cards de produto.
  Map<String, double> get qtdPorSku {
    return {for (final i in itens) i.sku: i.qtd};
  }

  @override
  List<Object?> get props =>
      [id, ordem, cliente, itens, desconto, status, abertaEm, operadorId];
}
