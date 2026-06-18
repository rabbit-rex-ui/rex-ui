/// Códigos de roteamento de BusinessRuleFailure.code (guia §3.3 / §6).
abstract final class FailureCodes {
  static const caixaBloqueado = 'CAIXA_BLOQUEADO'; // 409 Imediata (§6.3)
  static const caixaFechado = 'CAIXA_FECHADO'; // 409
  static const idempotenciaConflito = 'IDEMPOTENCIA_CONFLITO'; // 409
  static const exigeSupervisor = 'EXIGE_SUPERVISOR'; // 403 sangria Imediata
  static const contaBloqueada = 'CONTA_BLOQUEADA'; // 403 login
  static const semPermissao = 'SEM_PERMISSAO'; // 403 genérico
  static const regraNegocio = 'REGRA_NEGOCIO'; // 422 fallback
}
