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
}
