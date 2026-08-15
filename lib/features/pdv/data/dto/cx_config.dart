/// Configuração do PDV por tenant — `GET /pdv/cx-config` (contrato v3 §5).
///
/// Lida no boot do [CaixaSessionController] para ajustar a UX conforme o porte
/// do tenant. Hoje só carrega [maloteHabilitado], mas o backend avisou que o
/// payload vai crescer — por isso o parse é **tolerante**: campos desconhecidos
/// são ignorados e a ausência da chave cai num default seguro.
///
/// É informativo, **não** um gate de segurança: mesmo com [maloteHabilitado]
/// `false`, os endpoints de malote (retaguarda web) seguem funcionando. No PDV,
/// a flag apenas decide se o destino `COFRE` aparece no diálogo de sangria.
class CxConfigResponse {
  const CxConfigResponse({this.maloteHabilitado = false});

  /// Se o tenant usa o ciclo de malote. Controla se o PDV oferece o destino
  /// `COFRE` na sangria (§8): `true` → mostra `COFRE`; `false` → esconde e
  /// deixa apenas `BANCO`/`OUTRO` (mercadinho sem cofre).
  final bool maloteHabilitado;

  factory CxConfigResponse.fromJson(Map<String, dynamic> j) => CxConfigResponse(
    maloteHabilitado: (j['maloteHabilitado'] as bool?) ?? false,
  );

  /// Default fail-safe quando a consulta não completa (ex.: sem rede no boot).
  /// Cai no comportamento mais restrito: sem `COFRE`. O boot do caixa **não**
  /// deve falhar por causa disto — a config é conveniência de UX, não pré-
  /// requisito para operar.
  static const CxConfigResponse fallback = CxConfigResponse();
}
