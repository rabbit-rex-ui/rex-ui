import 'package:flutter/foundation.dart';

import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/pedido_resumo_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/pedido_delivery_repository.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';

/// Filtros de fila. Um chip por estado (1 query = 1 status, guia §4.12), mais
/// "Todos". Cobrem TODOS os estados — nenhum pedido fica sem filtro. A ordem
/// segue o fluxo: caminho feliz primeiro, exceções ao fim.
enum FilaPedido {
  todos('Todos', null),
  recebido('Recebidos', PedidoStatus.recebido),
  confirmando('Confirmando', PedidoStatus.confirmando),
  separando('Separação', PedidoStatus.separando),
  conferido('Conferidos', PedidoStatus.conferido),
  aguardandoExpedicao('Aguard. expedição', PedidoStatus.aguardandoExpedicao),
  emRota('Em rota', PedidoStatus.emRota),
  entregue('Entregues', PedidoStatus.entregue),
  concluido('Concluídos', PedidoStatus.concluido),
  naoEntregue('Não entregues', PedidoStatus.naoEntregue),
  pagamentoRecusado('Pag. recusado', PedidoStatus.pagamentoRecusado),
  devolvido('Devolvidos', PedidoStatus.devolvido),
  cancelado('Cancelados', PedidoStatus.cancelado);

  const FilaPedido(this.label, this.status);

  final String label;
  final PedidoStatus? status;
}

/// Lista paginada de pedidos para a aba "Pedidos" (guia §4.12).
///
/// Uma carga por vez, com guard de geração: se o operador troca de fila no meio
/// de uma requisição, a resposta antiga é descartada (não pisca resultado
/// errado). Paginação incremental via "carregar mais".
class PedidosListaController extends ChangeNotifier {
  PedidosListaController(this._repo);

  final PedidoDeliveryRepository _repo;

  static const int _tamanhoPagina = 20;

  FilaPedido _fila = FilaPedido.todos;
  FilaPedido get fila => _fila;

  final List<PedidoResumoResponse> _itens = [];
  List<PedidoResumoResponse> get itens => List.unmodifiable(_itens);

  bool _loading = false;
  bool get loading => _loading;

  bool _carregandoMais = false;
  bool get carregandoMais => _carregandoMais;

  String? _erro;
  String? get erro => _erro;

  int _pagina = 0;
  int _total = 0;

  /// Geração da carga corrente; incrementa a cada nova busca. Respostas de
  /// gerações anteriores são ignoradas.
  int _gen = 0;

  bool get vazio => !_loading && _erro == null && _itens.isEmpty;

  /// Há mais páginas a carregar?
  bool get temMais => _itens.length < _total;

  /// Troca a fila e recarrega do zero. Ignora se for a mesma.
  void selecionarFila(FilaPedido fila) {
    if (fila == _fila) return;
    _fila = fila;
    recarregar();
  }

  /// Carrega a primeira página da fila atual (usado no open e no refresh após
  /// criar um pedido).
  Future<void> recarregar() async {
    final gen = ++_gen;
    _loading = true;
    _erro = null;
    _pagina = 0;
    notifyListeners();

    final result = await _repo.listar(
      status: _fila.status,
      page: 0,
      size: _tamanhoPagina,
    );
    if (gen != _gen) return; // carga obsoleta — descarta

    result.fold(
      onOk: (pagina) {
        _itens
          ..clear()
          ..addAll(pagina.conteudo);
        _total = pagina.total;
        _loading = false;
        notifyListeners();
      },
      onErr: (f) {
        _itens.clear();
        _erro = f.message;
        _loading = false;
        notifyListeners();
      },
    );
  }

  /// Carrega a próxima página e acumula. Silencioso em erro de página seguinte
  /// (não apaga o que já está na tela; só encerra o spinner de "mais").
  Future<void> carregarMais() async {
    if (_loading || _carregandoMais || !temMais) return;
    final gen = _gen;
    _carregandoMais = true;
    notifyListeners();

    final proxima = _pagina + 1;
    final result = await _repo.listar(
      status: _fila.status,
      page: proxima,
      size: _tamanhoPagina,
    );
    if (gen != _gen) return; // fila trocou no meio — descarta

    result.fold(
      onOk: (pagina) {
        _pagina = proxima;
        _itens.addAll(pagina.conteudo);
        _total = pagina.total;
        _carregandoMais = false;
        notifyListeners();
      },
      onErr: (_) {
        _carregandoMais = false;
        notifyListeners();
      },
    );
  }
}
