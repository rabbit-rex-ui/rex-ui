import 'package:flutter/foundation.dart';

import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/failures/failure_codes.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/motivo_pedido_request.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/pedido_detalhe_response.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/dto/pedido_transicao_requests.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/data/pedido_delivery_repository.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/momento_pagamento.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_acao.dart';

/// Carrega o detalhe de um pedido (guia §4.13) e executa transições: diretas
/// (sem corpo — §4.2/§4.4/§4.5/§4.6), fim feliz com corpo (§4.7 entregar,
/// §4.8 concluir) e as de exceção com `motivo` (§4.9/§4.10/§4.11/§4.14). Um por
/// pedido aberto (descartável).
class PedidoDetalheController extends ChangeNotifier {
  PedidoDetalheController(this._repo, this.pedidoId);

  final PedidoDeliveryRepository _repo;
  final String pedidoId;

  // ── Carga da tela ──
  bool _loading = false;
  bool get loading => _loading;

  String? _erro;
  String? get erro => _erro;

  PedidoDetalheResponse? _detalhe;
  PedidoDetalheResponse? get detalhe => _detalhe;

  // ── Execução de ação (sobreposto ao detalhe carregado) ──
  PedidoAcao? _acaoEmExecucao;
  PedidoAcao? get acaoEmExecucao => _acaoEmExecucao;
  bool get executandoAcao => _acaoEmExecucao != null;

  String? _acaoErro;
  String? get acaoErro => _acaoErro;

  Future<void> carregar() async {
    _loading = true;
    _erro = null;
    _acaoErro = null;
    notifyListeners();

    final result = await _repo.detalhe(pedidoId);
    result.fold(
      onOk: (d) {
        _detalhe = d;
        _loading = false;
        notifyListeners();
      },
      onErr: (f) {
        _erro = f.message;
        _loading = false;
        notifyListeners();
      },
    );
  }

  void limparAcaoErro() {
    if (_acaoErro == null) return;
    _acaoErro = null;
    notifyListeners();
  }

  /// Executa uma transição DIRETA (sem corpo).
  Future<void> executar(PedidoAcao acao) async {
    final chamada = _chamadaDireta(acao);
    if (chamada == null) {
      _acaoErro = 'Esta ação será habilitada em breve.';
      notifyListeners();
      return;
    }
    await _executar(acao, chamada);
  }

  /// EM_ROTA → ENTREGUE (§4.7). [recebidoPor] é obrigatório (prova de entrega).
  Future<void> entregar(String recebidoPor) async {
    final quem = recebidoPor.trim();
    if (quem.isEmpty) {
      _acaoErro = 'Informe quem recebeu o pedido.';
      notifyListeners();
      return;
    }
    await _executar(
      PedidoAcao.entregar,
      () => _repo.entregar(pedidoId, EntregarPedidoRequest(recebidoPor: quem)),
    );
  }

  /// ENTREGUE → CONCLUIDO (§4.8). Regra do corpo decidida pelo
  /// `momentoPagamento` do detalhe: NA_ENTREGA exige [formaPagamento];
  /// ANTECIPADO ignora e envia corpo nulo.
  Future<void> concluir(String? formaPagamento) async {
    final exige = _detalhe?.momentoPagamento.exigeFormaNaConclusao ?? false;
    ConcluirPedidoRequest? req;
    if (exige) {
      final forma = formaPagamento?.trim() ?? '';
      if (forma.isEmpty) {
        _acaoErro = 'Selecione a forma de pagamento (pedido pago na entrega).';
        notifyListeners();
        return;
      }
      req = ConcluirPedidoRequest(formaPagamento: forma);
    }
    await _executar(PedidoAcao.concluir, () => _repo.concluir(pedidoId, req));
  }

  /// EM_ROTA → NAO_ENTREGUE (§4.9). [motivo] obrigatório.
  Future<void> naoEntregue(String motivo) async {
    await _comMotivoObrigatorio(
      PedidoAcao.naoEntregue,
      motivo,
      (m) => _repo.naoEntregue(pedidoId, MotivoPedidoRequest(motivo: m)),
    );
  }

  /// ENTREGUE → PAGAMENTO_RECUSADO (§4.10). [motivo] opcional (vazio → corpo
  /// omitido).
  Future<void> pagamentoRecusado(String motivo) async {
    final m = motivo.trim();
    final req = m.isEmpty ? null : MotivoPedidoRequest(motivo: m);
    await _executar(
      PedidoAcao.pagamentoRecusado,
      () => _repo.pagamentoRecusado(pedidoId, req),
    );
  }

  /// NAO_ENTREGUE|PAGAMENTO_RECUSADO → DEVOLVIDO (§4.11). [motivo] obrigatório.
  Future<void> devolver(String motivo) async {
    await _comMotivoObrigatorio(
      PedidoAcao.devolver,
      motivo,
      (m) => _repo.devolver(pedidoId, MotivoPedidoRequest(motivo: m)),
    );
  }

  /// RECEBIDO|CONFIRMANDO|SEPARANDO|CONFERIDO → CANCELADO (§4.14). [motivo]
  /// obrigatório.
  Future<void> cancelar(String motivo) async {
    await _comMotivoObrigatorio(
      PedidoAcao.cancelar,
      motivo,
      (m) => _repo.cancelar(pedidoId, MotivoPedidoRequest(motivo: m)),
    );
  }

  /// Valida motivo não-vazio e dispara a chamada com ele. Compartilhado pelas
  /// exceções que exigem motivo (cancelar/naoEntregue/devolver).
  Future<void> _comMotivoObrigatorio(
    PedidoAcao acao,
    String motivo,
    Future<Result<void, Failure>> Function(String motivo) chamada,
  ) async {
    final m = motivo.trim();
    if (m.isEmpty) {
      _acaoErro = 'Informe o motivo.';
      notifyListeners();
      return;
    }
    await _executar(acao, () => chamada(m));
  }

  /// Núcleo compartilhado: guard de concorrência, execução, roteamento de erro
  /// e recarga silenciosa. Todas as transições passam por aqui.
  Future<void> _executar(
    PedidoAcao acao,
    Future<Result<void, Failure>> Function() chamada,
  ) async {
    if (_acaoEmExecucao != null) return; // uma ação por vez

    _acaoEmExecucao = acao;
    _acaoErro = null;
    notifyListeners();

    final result = await chamada();
    final falha = result.fold<Failure?>(onOk: (_) => null, onErr: (f) => f);

    if (falha == null) {
      await _recarregarSilencioso();
      _acaoEmExecucao = null;
      notifyListeners();
      return;
    }

    _acaoEmExecucao = null;
    _rotearErroAcao(falha);
    // Estado mudou no servidor: ressincroniza as ações disponíveis.
    if (falha is BusinessRuleFailure &&
        falha.code == FailureCodes.pedidoTransicaoInvalida) {
      await _recarregarSilencioso();
    }
    notifyListeners();
  }

  Future<Result<void, Failure>> Function()? _chamadaDireta(PedidoAcao acao) {
    return switch (acao) {
      PedidoAcao.confirmar => () => _repo.confirmar(pedidoId),
      PedidoAcao.conferir => () => _repo.conferir(pedidoId),
      PedidoAcao.faturar => () => _repo.faturar(pedidoId),
      PedidoAcao.expedir => () => _repo.expedir(pedidoId),
      _ => null,
    };
  }

  /// Recarrega o detalhe sem tocar em [_loading] (não pisca a tela cheia).
  /// Não chama notifyListeners — quem invoca notifica.
  Future<void> _recarregarSilencioso() async {
    final result = await _repo.detalhe(pedidoId);
    result.fold(onOk: (d) => _detalhe = d, onErr: (f) => _acaoErro = f.message);
  }

  void _rotearErroAcao(Failure f) {
    if (f is NotFoundFailure) {
      _acaoErro = 'Pedido não encontrado. Volte à fila.';
      return;
    }
    if (f is! BusinessRuleFailure) {
      _acaoErro = f.message;
      return;
    }
    switch (f.code) {
      case FailureCodes.pedidoTransicaoInvalida:
        _acaoErro = 'O pedido mudou de estado. Atualizei as ações disponíveis.';
      case FailureCodes.pedidoExpedicaoBloqueada:
        _acaoErro =
            'A nota fiscal ainda não permite expedir (em autorização, '
            'rejeitada ou com cancelamento em andamento). Veja o painel da '
            'nota fiscal.';
      case FailureCodes.acessoNegado:
      case FailureCodes.semPermissao:
        _acaoErro = 'Você não tem permissão para esta ação.';
      default:
        _acaoErro = f.message;
    }
  }
}
