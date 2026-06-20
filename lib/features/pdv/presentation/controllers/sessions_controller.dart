import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/domain/entities/atendimento.dart';
import 'package:rabbit_pdv/domain/entities/cliente.dart';
import 'package:rabbit_pdv/domain/entities/pagamento.dart';
import 'package:rabbit_pdv/domain/entities/produto.dart';
import 'package:rabbit_pdv/domain/enums/atendimento_status.dart';
import 'package:rabbit_pdv/domain/repositories/produtos_repository.dart';

/// Resultado da operação de adicionar um item. A UI usa isso para
/// disparar feedback visual (flash verde / vermelho + toast).
class AddItemOutcome {
  final bool sucesso;
  final Produto? produto;
  final Failure? erro;

  const AddItemOutcome.ok(this.produto) : sucesso = true, erro = null;

  const AddItemOutcome.fail(this.erro) : sucesso = false, produto = null;
}

/// Controlador dos atendimentos abertos.
///
/// É um [ChangeNotifier] simples — sem libs de estado. A regra é: toda
/// mutação produz uma nova instância de [Atendimento] (imutável) e dispara
/// `notifyListeners`. A UI lê via [ListenableBuilder] ou widgets que
/// observam o controller diretamente.
///
/// **Invariantes:**
/// 1. Existe sempre ao menos um atendimento aberto (criado um vazio se
///    todos forem fechados).
/// 2. `activeId` aponta sempre para um atendimento existente em `sessions`.
/// 3. No máximo UM atendimento em status `digitando`. Quando outro é
///    selecionado, o anterior passa a `aguardando` (se estava `digitando`).
class SessionsController extends ChangeNotifier {
  SessionsController(this._repo, {String operadorId = 'op_demo'})
    : _operadorId = operadorId {
    _bootstrap();
  }

  final ProdutosRepository _repo;
  final String _operadorId;
  final _uuid = const Uuid();
  int _proximaOrdem = 1;

  /// Lista de atendimentos abertos (não inclui pagos/cancelados).
  final List<Atendimento> _sessions = [];
  List<Atendimento> get sessions => List.unmodifiable(_sessions);

  String? _activeId;
  String? get activeId => _activeId;

  Atendimento? get active {
    if (_activeId == null) return null;
    return _sessions.firstWhere(
      (s) => s.id == _activeId,
      orElse: () => _sessions.first,
    );
  }

  // ---- Bootstrap -----------------------------------------------------------

  void _bootstrap() {
    // Atendimento inicial vazio com cliente anônimo. Em produção, isso
    // viria do estado salvo (atendimentos pendentes do operador).
    final a = Atendimento.novo(
      id: _uuid.v4(),
      ordem: _proximaOrdem++,
      operadorId: _operadorId,
    );
    _sessions.add(a);
    _activeId = a.id;
  }

  // ---- Atendimentos --------------------------------------------------------

  /// Cria um novo atendimento vazio e o torna ativo.
  void novoAtendimento({Cliente? cliente}) {
    _passivarAtivoSeDigitando();

    final a = Atendimento.novo(
      id: _uuid.v4(),
      ordem: _proximaOrdem++,
      operadorId: _operadorId,
      cliente: cliente ?? Cliente.anonimo,
    );
    _sessions.add(a);
    _activeId = a.id;
    notifyListeners();
  }

  /// Alterna para outra aba. Atualiza statuses de forma coerente.
  void alternarPara(String id) {
    if (id == _activeId) return;
    final alvo = _sessions.indexWhere((s) => s.id == id);
    if (alvo < 0) return;

    _passivarAtivoSeDigitando();

    _activeId = id;
    final s = _sessions[alvo];
    // Se estava aguardando, volta para digitando ao ativar.
    if (s.status == AtendimentoStatus.aguardando) {
      _sessions[alvo] = s.marcarComoStatus(AtendimentoStatus.digitando);
    }
    notifyListeners();
  }

  /// Fecha (cancela) um atendimento. Retorna a próxima aba ativa.
  /// Se sobrou nenhuma, cria uma nova vazia.
  void fechar(String id) {
    final idx = _sessions.indexWhere((s) => s.id == id);
    if (idx < 0) return;

    _sessions.removeAt(idx);

    if (_sessions.isEmpty) {
      // Garante invariante #1: sempre há ao menos um atendimento aberto.
      final novo = Atendimento.novo(
        id: _uuid.v4(),
        ordem: _proximaOrdem++,
        operadorId: _operadorId,
      );
      _sessions.add(novo);
      _activeId = novo.id;
    } else if (id == _activeId) {
      // Ativa o vizinho à esquerda (ou o primeiro se removeu o primeiro).
      final novoIdx = idx > 0 ? idx - 1 : 0;
      _activeId = _sessions[novoIdx].id;
      final s = _sessions[novoIdx];
      if (s.status == AtendimentoStatus.aguardando) {
        _sessions[novoIdx] = s.marcarComoStatus(AtendimentoStatus.digitando);
      }
    }

    notifyListeners();
  }

  /// Pausa o atendimento ativo (→ aguardando) e SAI dele: vai para o próximo
  /// atendimento aguardando, ou cria um novo vazio se este era o único.
  /// Libera o caixa para o próximo cliente.
  void pausarAtivo() {
    if (_activeId == null) return;
    final idx = _sessions.indexWhere((s) => s.id == _activeId);
    if (idx < 0) return;

    // Marca o atual como aguardando.
    _sessions[idx] = _sessions[idx].marcarComoStatus(
      AtendimentoStatus.aguardando,
    );

    // Procura outro atendimento para assumir o foco (qualquer um != atual).
    final proximoIdx = _sessions.indexWhere((s) => s.id != _activeId);

    if (proximoIdx >= 0) {
      _activeId = _sessions[proximoIdx].id;
      // Se o destino estava aguardando, reativa para digitação.
      final destino = _sessions[proximoIdx];
      if (destino.status == AtendimentoStatus.aguardando) {
        _sessions[proximoIdx] = destino.marcarComoStatus(
          AtendimentoStatus.digitando,
        );
      }
    } else {
      // Era o único atendimento → abre um novo vazio e foca nele.
      final novo = Atendimento.novo(
        id: _uuid.v4(),
        ordem: _proximaOrdem++,
        operadorId: _operadorId,
      );
      _sessions.add(novo);
      _activeId = novo.id;
    }

    notifyListeners();
  }

  /// Marca o ativo como pronto para pagamento. O modal de pagamento usa esse
  /// hook como gatilho.
  void marcarProntoParaPagamento() {
    _mutateActive((a) => a.marcarComoStatus(AtendimentoStatus.pronto));
  }

  /// Volta o ativo para digitando (saindo do modal de pagamento sem
  /// confirmar).
  void retomarDigitacao() {
    _mutateActive((a) => a.marcarComoStatus(AtendimentoStatus.digitando));
  }

  /// Finaliza a venda do atendimento ativo. Marca como `pago`, remove da
  /// lista de abertos e abre um novo vazio se ficou nenhum.
  ///
  /// Os [pagamentos] são gerados pelo modal de pagamento; aqui eles ainda
  /// não são persistidos individualmente (Pagamento Repository virá no
  /// Passo de integração com backend). Por enquanto só sinalizamos.
  void finalizarVenda(List<Pagamento> pagamentos) {
    if (_activeId == null) return;
    final idx = _sessions.indexWhere((s) => s.id == _activeId);
    if (idx < 0) return;

    // TODO: persistir pagamentos via PagamentoRepository (futuro).
    // TODO: enviar comando de impressão de cupom (futuro).

    _sessions.removeAt(idx);

    if (_sessions.isEmpty) {
      // Mantém invariante: sempre há ao menos um atendimento aberto.
      final novo = Atendimento.novo(
        id: _uuid.v4(),
        ordem: _proximaOrdem++,
        operadorId: _operadorId,
      );
      _sessions.add(novo);
      _activeId = novo.id;
    } else {
      // Ativa o vizinho à esquerda, ou o primeiro.
      final novoIdx = idx > 0 ? idx - 1 : 0;
      _activeId = _sessions[novoIdx].id;
      final s = _sessions[novoIdx];
      if (s.status == AtendimentoStatus.aguardando) {
        _sessions[novoIdx] = s.marcarComoStatus(AtendimentoStatus.digitando);
      }
    }

    notifyListeners();
  }

  // ---- Itens ---------------------------------------------------------------

  /// Adiciona um produto via leitor / busca / atalhos. Retorna outcome
  /// para a UI fazer flash + toast.
  Future<AddItemOutcome> adicionarPorBarcode(String codigo) async {
    final r = await _repo.porBarcode(codigo);
    return r.fold(
      onOk: (produto) {
        _mutateActive((a) => a.addProduto(produto));
        return AddItemOutcome.ok(produto);
      },
      onErr: (f) => AddItemOutcome.fail(f),
    );
  }

  /// Adiciona produto já resolvido (vindo do dropdown de busca ou do grid
  /// de atalhos).
  AddItemOutcome adicionarProduto(Produto produto, {double? qtd}) {
    if (!produto.ativo || !produto.temPreco) {
      return const AddItemOutcome.fail(
        BusinessRuleFailure('Produto não disponível', code: 'INDISPONIVEL'),
      );
    }
    _mutateActive((a) => a.addProduto(produto, qtd: qtd));
    return AddItemOutcome.ok(produto);
  }

  void ajustarQtd(int itemId, double delta) {
    _mutateActive((a) => a.ajustarQtd(itemId, delta));
  }

  void removerItem(int itemId) {
    _mutateActive((a) => a.removeItem(itemId));
  }

  void limparItens() {
    _mutateActive((a) => a.limparItens());
  }

  // ---- Cliente / desconto --------------------------------------------------

  void setCliente(Cliente novo) {
    _mutateActive((a) => a.setCliente(novo));
  }

  void setDesconto(double valor) {
    _mutateActive((a) => a.setDesconto(valor));
  }

  // ---- Helpers privados ----------------------------------------------------

  void _mutateActive(Atendimento Function(Atendimento) f) {
    if (_activeId == null) return;
    final idx = _sessions.indexWhere((s) => s.id == _activeId);
    if (idx < 0) return;
    _sessions[idx] = f(_sessions[idx]);
    notifyListeners();
  }

  void _passivarAtivoSeDigitando() {
    if (_activeId == null) return;
    final idx = _sessions.indexWhere((s) => s.id == _activeId);
    if (idx < 0) return;
    final s = _sessions[idx];
    if (s.status == AtendimentoStatus.digitando) {
      _sessions[idx] = s.marcarComoStatus(AtendimentoStatus.aguardando);
    }
  }
}
