/// Caixa físico (PDV) da filial. Espelha PdvFisicoResponse do backend.
/// Campos opcionais tratados como ausentes (backend pode usar NON_NULL).
class PdvFisico {
  final String id;
  final String code;
  final String name;
  final String terminalId;
  final String defaultWarehouseId;
  final bool active;
  final double? cashVarianceTolerance;

  const PdvFisico({
    required this.id,
    required this.code,
    required this.name,
    required this.terminalId,
    required this.defaultWarehouseId,
    required this.active,
    this.cashVarianceTolerance,
  });

  factory PdvFisico.fromJson(Map<String, dynamic> j) => PdvFisico(
    id: j['id'] as String,
    code: (j['code'] as String?) ?? '',
    name: (j['name'] as String?) ?? '',
    terminalId: (j['terminalId'] as String?) ?? '',
    defaultWarehouseId: (j['defaultWarehouseId'] as String?) ?? '',
    active: (j['active'] as bool?) ?? false,
    cashVarianceTolerance: (j['cashVarianceTolerance'] as num?)?.toDouble(),
  );

  /// Confirmação exibida ao gestor: "PDV-01 · Caixa 03 · TERM-001".
  String get resumo {
    final parts = [code, name, terminalId].where((s) => s.isNotEmpty);
    return parts.join(' · ');
  }
}
