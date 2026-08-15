/// Códigos de roteamento de BusinessRuleFailure.code (guia §3.3 / §6).
abstract final class FailureCodes {
  static const caixaBloqueado = 'CAIXA_BLOQUEADO'; // 409 Imediata (§6.3)
  static const caixaFechado = 'CAIXA_FECHADO'; // 409
  static const idempotenciaConflito = 'IDEMPOTENCIA_CONFLITO'; // 409
  static const exigeSupervisor = 'EXIGE_SUPERVISOR'; // 403 sangria Imediata
  static const contaBloqueada = 'CONTA_BLOQUEADA'; // 403 login
  static const semPermissao = 'SEM_PERMISSAO'; // 403 genérico
  static const regraNegocio = 'REGRA_NEGOCIO'; // 422 fallback
  static const credenciaisInvalidas = 'CREDENCIAIS_INVALIDAS';

  // ── Assumir caixa (cx.takeover) — contrato §8. `code` LITERAL do corpo de
  //    erro tipado (NÃO normalizar para UPPER_SNAKE). ──
  static const cxTakeoverSegregation = 'segregation';
  static const cxTakeoverJustificationRequired = 'justification-required';
  static const cxTakeoverSessionInvalid = 'session-invalid';
  static const cxTakeoverReasonNoteRequired = 'reason-note-required';
  static const cxTakeoverInvalidRequest = 'invalid-request';

  // ── Fechamento de caixa (cx.close) — contrato §7.4. `code` LITERAL do corpo
  //    tipado. ──
  static const closeJustificationRequired =
      'close-justification-required'; // 422
  static const closeApprovalRequired = 'close-approval-required'; // 422
  static const closeSegregation = 'close-segregation'; // 422
  static const stepupInvalidCredential = 'stepup-invalid-credential'; // 401
  static const stepupLocked = 'stepup-locked'; // 403
  static const stepupDenied = 'stepup-denied'; // 403
  static const closeApprovalUnavailable =
      'close-approval-unavailable'; // 501 (dev)

  // ── Movimento de caixa / sangria (POST /pdv/caixas/{id}/movimentos) —
  //    contrato v3 §3.8. `code` LITERAL do corpo tipado (NÃO normalizar).
  //    Os stepup-* (401/403) acima são COMPARTILHADOS com o fechamento —
  //    a credencial de supervisor entra no corpo do mesmo jeito. ──
  static const sessionClosed = 'session-closed'; // 409 (sessão já fechada)
  static const movementIdempotencyConflict =
      'movement-idempotency-conflict'; // 409 (mesma chave, conteúdo diferente)
  static const movementReasonRequired =
      'movement-reason-required'; // 422 (WITHDRAWAL sem reason)
  static const movementSupervisorRequired =
      'movement-supervisor-required'; // 403 (saída Imediata sem supervisor)
  static const movementSegregation =
      'movement-segregation'; // 403 (supervisor = operador no step-up)
  static const movementExceedsCash =
      'movement-exceeds-cash'; // 422 (saída acima do dinheiro em caixa)
  static const invalidArgument =
      'invalid-argument'; // 422 (destino em movimento não-WITHDRAWAL)
  static const validationFailed =
      'validation-failed'; // 422 (amount ≤ 0) / 400 (corpo malformado)
}
