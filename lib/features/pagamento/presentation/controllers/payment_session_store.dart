import 'package:rabbit_pdv/domain/entities/atendimento.dart';
import 'package:rabbit_pdv/features/pagamento/domain/payment_state.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/controllers/payment_session_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/sessions_controller.dart';

/// Guarda a configuração de pagamento POR ATENDIMENTO entre aberturas do
/// modal. Mantém apenas snapshots imutáveis ([PaymentState]); o controller
/// é criado sob demanda e hidratado do snapshot.
///
/// Descarte defensivo: observa o [SessionsController] e remove qualquer
/// pagamento cujo atendimento não esteja mais aberto (finalizado, cancelado
/// ou fechado) — sem depender de chamadas explícitas de limpeza.
class PaymentSessionStore {
  PaymentSessionStore(this._sessions) {
    _sessions.addListener(_descartarOrfaos);
  }

  final SessionsController _sessions;
  final Map<String, PaymentState> _porAtendimento = {};

  /// Controller hidratado e reconciliado com os itens atuais do atendimento.
  /// Se não há estado salvo, cria do zero.
  PaymentSessionController controllerFor(Atendimento atendimento) {
    final salvo = _porAtendimento[atendimento.id];
    if (salvo == null) {
      return PaymentSessionController(atendimento: atendimento);
    }
    return PaymentSessionController.fromState(
      atendimento: atendimento,
      state: salvo,
    );
  }

  /// Persiste o snapshot do controller (chamado quando o modal fecha sem
  /// finalizar a venda).
  void save(String atendimentoId, PaymentSessionController controller) {
    _porAtendimento[atendimentoId] = controller.exportState();
  }

  /// Remove explicitamente (ex.: venda concluída).
  void descartar(String atendimentoId) {
    _porAtendimento.remove(atendimentoId);
  }

  /// Remove snapshots de atendimentos que não estão mais abertos.
  void _descartarOrfaos() {
    final abertos = _sessions.sessions.map((a) => a.id).toSet();
    _porAtendimento.keys
        .where((id) => !abertos.contains(id))
        .toList()
        .forEach(_porAtendimento.remove);
  }

  void dispose() {
    _sessions.removeListener(_descartarOrfaos);
    _porAtendimento.clear();
  }
}
