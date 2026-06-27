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
}
