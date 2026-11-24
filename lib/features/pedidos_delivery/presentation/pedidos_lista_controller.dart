import 'package:flutter/foundation.dart';

import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/pedido_resumo_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/pedido_delivery_repository.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';

/// Lista paginada de pedidos para a aba "Pedidos" (guia §4.12).
///
/// O filtro é um único [PedidoStatus] opcional: `null` = todas as situações; um
/// valor = só aquela. A UI oferece essa seleção por um dropdown (a trilha do
/// fluxo migrou para o detalhe do pedido, onde "fluxo" é propriedade de um
/// pedido, não da lista).
///
/// Uma carga por vez, com guard de geração: se o filtro muda no meio de uma
/// requisição, a resposta antiga é descartada. Paginação incremental.
class PedidosListaController extends ChangeNotifier {
  PedidosListaController(this._repo);

  final PedidoDeliveryRepository _repo;

  static const int _tamanhoPagina = 20;

  /// Status filtrado; `null` = todas as situações.
  PedidoStatus? _status;
  PedidoStatus? get status => _status;

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

  /// Filtra por uma situação (dropdown) e recarrega. `null` = todas. Ignora se
  /// não mudou.
  void selecionarStatus(PedidoStatus? status) {
    if (status == _status) return;
    _status = status;
    recarregar();
  }

  /// Carrega a primeira página do filtro atual (usado no open e quando a aba
  /// Pedidos vira visível).
  Future<void> recarregar() async {
    final gen = ++_gen;
    _loading = true;
    _erro = null;
    _pagina = 0;
    notifyListeners();

    final result = await _repo.listar(
      status: _status,
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
      status: _status,
      page: proxima,
      size: _tamanhoPagina,
    );
    if (gen != _gen) return; // filtro trocou no meio — descarta

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
