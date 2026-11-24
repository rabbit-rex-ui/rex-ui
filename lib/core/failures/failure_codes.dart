/// Códigos de roteamento de BusinessRuleFailure.code (guia §3.3 / §6).
///
/// Origem do `code` (ver `ApiClient`): o `code` do corpo quando existe (valor
/// literal, ex.: `acesso_negado`); senão o sufixo do `type` em UPPER_SNAKE
/// (ex.: `…/venda-bloqueada` → `VENDA_BLOQUEADA`). O texto do `detail` nunca
/// decide — é para humanos e pode mudar (respostas do backend v1, §7/§8).
abstract final class FailureCodes {
  /// 409 da venda com caixa bloqueado pelo teto Imediata (§6.3). Vem do
  /// `type` `…/venda-bloqueada` (não existe `…/caixa-bloqueado`).
  static const caixaBloqueado = 'VENDA_BLOQUEADA';

  /// 409 sem `code` nem `type` reconhecível.
  static const conflito = 'CONFLITO';

  static const semPermissao = 'SEM_PERMISSAO'; // 403 sem code nem type
  static const regraNegocio = 'REGRA_NEGOCIO'; // 422 fallback

  /// 403 por falta de permissão, venha com `code` (`acesso_negado`) ou não.
  /// Use em vez de comparar com as duas constantes em cada tela.
  static bool ehFaltaDePermissao(String code) =>
      code == acessoNegado || code == semPermissao;

  // ── Segurança (401/403 em problem+json, guia fiscal v2.2 §6.4). `code`
  //    LITERAL do corpo. ──
  /// 401: token ausente, inválido ou expirado. O `ApiClient` converte em
  /// `NetworkFailure(statusCode: 401)` — o mesmo sinal de sessão expirada de
  /// sempre.
  static const naoAutenticado = 'nao_autenticado';
  static const acessoNegado = 'acesso_negado'; // 403: papel sem a permissão

  // ── Login e sessão (/auth), guia fiscal v2.3 §6.4. `code` LITERAL. ──
  /// 401 no login (login ou senha errados) e na troca de senha (senha atual
  /// errada). NÃO é sessão expirada.
  static const credenciaisInvalidas = 'credenciais_invalidas';
  static const contaBloqueada = 'conta_bloqueada'; // 403: pelo administrador
  static const contaBloqueadaTemporariamente =
      'conta_bloqueada_temporariamente'; // 403: excesso de tentativas
  static const semTenantAtivo = 'sem_tenant_ativo'; // 403: sem vínculo
  static const refreshInvalido = 'refresh_invalido'; // 401 no /auth/refresh

  // ── Ativação de terminal (POST /devices/activate) — 409 com `type` URN;
  //    roteie pelo `code` literal. ──
  static const registerAlreadyActive = 'register_already_active';
  static const deviceFingerprintConflict = 'device_fingerprint_conflict';

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
      'movement-supervisor-required'; // 403 (saída Imediata/4-olhos sem fiscal)
  static const movementSegregation =
      'movement-segregation'; // 403 (fiscal = operador no step-up)
  static const movementExceedsCash =
      'movement-exceeds-cash'; // 422 (saída acima do dinheiro em caixa)
  static const invalidArgument =
      'invalid-argument'; // 422 (destino em movimento não-WITHDRAWAL)
  static const destinoNaoHabilitado =
      'destino-nao-habilitado'; // 422 (destino fora da lista do tenant)
  static const validationFailed =
      'validation-failed'; // 422 (amount ≤ 0) / 400 (corpo malformado)

  // ── Pedido de delivery (/pdv/pedidos) — guia §5. O ProblemDetail NÃO traz
  //    `code`, só `type`; o ApiClient deriva o code via `_codeFromType`
  //    (type → UPPER_SNAKE, último segmento). Portanto estes valores DEVEM ser
  //    o UPPER_SNAKE do sufixo do type — não são literais de corpo. ──
  static const pedidoTransicaoInvalida =
      'TRANSICAO_INVALIDA'; // 409 (estado mudou → recarregar)
  static const pedidoExpedicaoBloqueada =
      'EXPEDICAO_BLOQUEADA'; // 409 (nota não autorizada → tentar de novo)
  static const pedidoInvalido =
      'PEDIDO_INVALIDO'; // 422 (regra de negócio, ex.: concluir sem forma)

  // ── Notas fiscais (/fis/notas) — guia fiscal v2.0 §6. Mesma regra do
  //    delivery: UPPER_SNAKE do sufixo do `type` (sem `code` no corpo). 403 é
  //    o `acessoNegado` acima. 404 vira
  //    NotFoundFailure, 400 vira ValidationFailure e 503
  //    (`provedor-fiscal-indisponivel`) vira NetworkFailure(statusCode: 503) —
  //    por isso não têm constante aqui. ──
  static const vendaSemPedidoDeNota = 'VENDA_SEM_PEDIDO_DE_NOTA'; // 409
  static const notaFiscalAtivaExistente = 'NOTA_FISCAL_ATIVA_EXISTENTE'; // 409
  static const configuracaoFiscalAusente = 'CONFIGURACAO_FISCAL_AUSENTE'; // 422
  static const notaNaoCancelavel = 'NOTA_NAO_CANCELAVEL'; // 409
  static const transicaoNotaInvalida = 'TRANSICAO_NOTA_INVALIDA'; // 409
  static const prazoCancelamentoExpirado =
      'PRAZO_CANCELAMENTO_EXPIRADO'; // 422 (prazo local ou cStat 501)
  static const mercadoriaJaCirculou = 'MERCADORIA_JA_CIRCULOU'; // 422
  static const cancelamentoRejeitadoSefaz =
      'CANCELAMENTO_REJEITADO_SEFAZ'; // 422 (outra recusa da SEFAZ)

  // ── Impressão fiscal — códigos LOCAIS (não vêm do backend). ──
  /// Terminal sem térmica escolhida no diálogo "Impressoras".
  static const impressoraNaoConfigurada = 'IMPRESSORA_NAO_CONFIGURADA';

  /// Nota não autorizada ou com cancelamento em andamento (guia §9.4).
  static const notaNaoImprimivel = 'NOTA_NAO_IMPRIMIVEL';
}
