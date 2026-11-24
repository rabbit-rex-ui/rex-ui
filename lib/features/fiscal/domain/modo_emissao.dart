/// Modo de emissão da nota (guia fiscal v2.2 §4) — enum fechado no backend.
enum ModoEmissao {
  normal('NORMAL', 'Normal'),
  contingenciaOffline('CONTINGENCY_OFFLINE', 'Contingência offline'),
  contingenciaSvc('CONTINGENCY_SVC', 'Contingência SVC'),

  /// Valor que este app ainda não conhece. O backend pede tratar como
  /// contingência genérica (compatibilidade futura), não como erro.
  contingenciaDesconhecida('', 'Contingência');

  const ModoEmissao(this.wire, this.label);

  final String wire;
  final String label;

  bool get emContingencia => this != ModoEmissao.normal;

  /// Ausente → [normal] (o backend sempre envia; é só defesa). Desconhecido →
  /// [contingenciaDesconhecida].
  static ModoEmissao fromWire(String? value) {
    if (value == null || value.isEmpty) return ModoEmissao.normal;
    for (final m in values) {
      if (m.wire == value) return m;
    }
    return ModoEmissao.contingenciaDesconhecida;
  }
}
