import 'package:flutter/foundation.dart';

import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/failures/failure_codes.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/pedido_detalhe_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/separar_pedido_request.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/pedido_delivery_repository.dart';

/// Linha editável da separação (guia §4.3). `qtdSeparada` começa igual à
/// solicitada; `indisponivel` marca item sem estoque. [unitOfMeasure] é a string
/// crua do backend (base do rótulo real); [isWeighed] decide o modo decimal.
class SepararItemVm {
  const SepararItemVm({
    required this.lineNumber,
    required this.produtoId,
    required this.qtySolicitada,
    required this.isWeighed,
    required this.unitOfMeasure,
    required this.qtdSeparada,
    required this.indisponivel,
  });

  final int lineNumber;
  final String produtoId;
  final double qtySolicitada;
  final bool isWeighed;
  final String unitOfMeasure;
  final double qtdSeparada;
  final bool indisponivel;

  /// Resolvido conforme a regra: indisponível, ou com quantidade separada > 0.
  bool get valido => indisponivel || qtdSeparada > 0;

  SepararItemVm copyWith({double? qtdSeparada, bool? indisponivel}) =>
      SepararItemVm(
        lineNumber: lineNumber,
        produtoId: produtoId,
        qtySolicitada: qtySolicitada,
        isWeighed: isWeighed,
        unitOfMeasure: unitOfMeasure,
        qtdSeparada: qtdSeparada ?? this.qtdSeparada,
        indisponivel: indisponivel ?? this.indisponivel,
      );
}

/// Sub-fluxo de separação de um pedido (guia §4.3). Recebe os itens do detalhe
/// já carregado (sem recarregar do servidor) e mantém o estado de edição:
/// quantidade separada e disponibilidade por linha. Descartável, um por
/// separação.
class SepararController extends ChangeNotifier {
  SepararController(this._repo, this.pedidoId, List<ItemPedidoDetalhe> itens)
    : _itens = itens
          .map(
            (i) => SepararItemVm(
              lineNumber: i.lineNumber,
              produtoId: i.produtoId,
              qtySolicitada: i.qtySolicitada,
              isWeighed: i.isWeighed,
              unitOfMeasure: i.unitOfMeasure,
              qtdSeparada: i.qtySolicitada, // pré-preenche com o solicitado
              indisponivel: false,
            ),
          )
          .toList();

  final PedidoDeliveryRepository _repo;
  final String pedidoId;

  final List<SepararItemVm> _itens;
  List<SepararItemVm> get itens => List<SepararItemVm>.unmodifiable(_itens);

  bool _loading = false;
  bool get loading => _loading;

  String? _erro;
  String? get erro => _erro;

  /// Habilita confirmar: há itens e todos estão resolvidos (separado > 0 ou
  /// indisponível).
  bool get podeConfirmar =>
      !_loading && _itens.isNotEmpty && _itens.every((i) => i.valido);

  void setQtd(int lineNumber, double qtd) {
    final idx = _itens.indexWhere((i) => i.lineNumber == lineNumber);
    if (idx < 0) return;
    _itens[idx] = _itens[idx].copyWith(qtdSeparada: qtd < 0 ? 0 : qtd);
    _erro = null;
    notifyListeners();
  }

  void setIndisponivel(int lineNumber, bool v) {
    final idx = _itens.indexWhere((i) => i.lineNumber == lineNumber);
    if (idx < 0) return;
    _itens[idx] = _itens[idx].copyWith(indisponivel: v);
    _erro = null;
    notifyListeners();
  }

  /// Envia a separação (§4.3). Devolve `true` em sucesso.
  Future<bool> separar() async {
    if (_itens.isEmpty) {
      _erro = 'Pedido sem itens para separar.';
      notifyListeners();
      return false;
    }
    if (_itens.any((i) => !i.valido)) {
      _erro =
          'Informe a quantidade separada (maior que zero) ou marque como '
          'indisponível em todos os itens.';
      notifyListeners();
      return false;
    }

    _loading = true;
    _erro = null;
    notifyListeners();

    final req = SepararPedidoRequest(
      itens: _itens
          .map(
            (i) => SepararItemRequest(
              lineNumber: i.lineNumber,
              indisponivel: i.indisponivel,
              qtySeparada: i.indisponivel ? null : i.qtdSeparada,
            ),
          )
          .toList(),
    );

    // TEMP debug — instrumentação para diagnosticar o "SOLICITADO no conferir".
    // Remover quando o fluxo de separação estiver validado.
    debugPrint('[separar] pedido=$pedidoId payload => ${req.toJson()}');

    final result = await _repo.separar(pedidoId, req);

    return result.fold<bool>(
      onOk: (_) {
        // TEMP debug — remover junto com o de cima.
        debugPrint('[separar] OK pedido=$pedidoId');
        _loading = false;
        notifyListeners();
        return true;
      },
      onErr: (f) {
        // TEMP debug — remover junto com o de cima.
        debugPrint('[separar] ERRO pedido=$pedidoId => ${f.message}');
        _loading = false;
        _rotearErro(f);
        notifyListeners();
        return false;
      },
    );
  }

  void _rotearErro(Failure f) {
    if (f is NotFoundFailure) {
      _erro = 'Pedido não encontrado. Volte à fila.';
      return;
    }
    if (f is! BusinessRuleFailure) {
      _erro = f.message;
      return;
    }
    switch (f.code) {
      case FailureCodes.pedidoTransicaoInvalida:
        _erro = 'O pedido mudou de estado. Volte e recarregue.';
      case FailureCodes.semPermissao:
        _erro = 'Você não tem permissão para separar.';
      default:
        // Inclui PEDIDO_INVALIDO (regra de negócio da separação): a mensagem
        // do backend é a mais informativa.
        _erro = f.message;
    }
  }
}
