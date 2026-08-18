import 'package:rabbit_pdv/features/pdv/data/dto/movimento_caixa_dtos.dart';

/// Configuração do PDV por tenant — `GET /pdv/cx-config` (contrato v3 §5).
///
/// Lida no boot do `CaixaSessionController` para ajustar a UX da sangria. É a
/// fonte que diz ao terminal **como desenhar a tela** para aquele tenant. Parse
/// **tolerante**: o DTO cresce, então campos desconhecidos são ignorados e a
/// ausência de cada chave cai num default seguro.
///
/// É informativa, **não** um gate de segurança: o backend sempre revalida
/// (4 olhos e destino habilitado). No PDV, a config só orienta a tela.
class CxConfigResponse {
  const CxConfigResponse({
    this.maloteHabilitado = false,
    this.sangriaQuatroOlhos = false,
    this.destinosHabilitados = MovimentoDestino.values,
  });

  /// Se o tenant usa o ciclo de malote. Controla se o destino `COFRE` pode
  /// aparecer na sangria (§8): `false` → esconde `COFRE` mesmo que ele venha em
  /// [destinosHabilitados].
  final bool maloteHabilitado;

  /// Sangria a 4 olhos (D-M44): se `true`, **toda** sangria exige a presença
  /// atestada de um fiscal (mesmo fluxo do step-up, §3.5), independente do modo
  /// do caixa. Se `false`, a sangria só exige fiscal em caixa IMMEDIATE.
  final bool sangriaQuatroOlhos;

  /// Destinos que **este tenant aceita** (D-M45). O seletor de destino é
  /// populado **apenas** com estes valores; o backend também valida (destino
  /// fora da lista → `422 destino-nao-habilitado`). Default: todos.
  ///
  /// Valores desconhecidos no JSON (enum futuro) são descartados no parse.
  final List<MovimentoDestino> destinosHabilitados;

  factory CxConfigResponse.fromJson(Map<String, dynamic> j) => CxConfigResponse(
    maloteHabilitado: (j['maloteHabilitado'] as bool?) ?? false,
    sangriaQuatroOlhos: (j['sangriaQuatroOlhos'] as bool?) ?? false,
    destinosHabilitados: _parseDestinos(j['sangriaDestinosHabilitados']),
  );

  /// Lê a lista de destinos por `wire`, ignorando valores fora do enum. Ausente
  /// ou vazia/ inválida → todos os destinos (default permissivo; quem restringe
  /// de fato é o backend).
  static List<MovimentoDestino> _parseDestinos(dynamic raw) {
    if (raw is! List) return MovimentoDestino.values;
    final wires = raw.whereType<String>().toSet();
    final out = MovimentoDestino.values
        .where((d) => wires.contains(d.wire))
        .toList(growable: false);
    return out.isEmpty ? MovimentoDestino.values : out;
  }

  /// Default fail-safe quando a consulta não completa (ex.: sem rede no boot):
  /// comportamento mais restrito na tela (sem `COFRE`, sem 4 olhos), destinos
  /// todos liberados (o backend barra o que não valer).
  static const CxConfigResponse fallback = CxConfigResponse();
}
