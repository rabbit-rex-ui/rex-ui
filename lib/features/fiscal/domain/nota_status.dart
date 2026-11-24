/// Estado de uma nota fiscal no backend (guia fiscal §5).
///
/// ```
/// PENDING → SENT → AUTHORIZED → CANCELLED
///    └────────┴──→ DENIED
/// ```
/// `DENIED` e `CANCELLED` são definitivos: reemitir cria uma NOVA nota.
enum NotaStatus {
  pendente('PENDING'),
  enviada('SENT'),
  autorizada('AUTHORIZED'),
  rejeitada('DENIED'),
  cancelada('CANCELLED'),
  inutilizada('INUTILIZED');

  const NotaStatus(this.wire);

  /// Valor de fio trocado com o backend.
  final String wire;

  /// Converte o valor do backend. Lança [ArgumentError] em valor desconhecido
  /// — divergência de contrato deve estourar cedo, não virar estado silencioso.
  static NotaStatus fromWire(String value) => values.firstWhere(
    (s) => s.wire == value,
    orElse: () => throw ArgumentError.value(
      value,
      'value',
      'NotaStatus desconhecido vindo do backend',
    ),
  );
}

extension NotaStatusX on NotaStatus {
  /// Rótulo do badge (guia §5).
  String get label => switch (this) {
    NotaStatus.pendente => 'Enviando…',
    NotaStatus.enviada => 'Aguardando SEFAZ',
    NotaStatus.autorizada => 'Autorizada',
    NotaStatus.rejeitada => 'Rejeitada',
    NotaStatus.cancelada => 'Cancelada',
    NotaStatus.inutilizada => 'Inutilizada',
  };

  /// A SEFAZ ainda não deu o desfecho. Não é erro: a reconciliação do backend
  /// conclui a nota sozinha.
  bool get emProcessamento =>
      this == NotaStatus.pendente || this == NotaStatus.enviada;

  /// Ocupa a venda: enquanto existir uma nota assim, o backend recusa nova
  /// emissão (409 `nota-fiscal-ativa-existente`).
  bool get ativa => emProcessamento || this == NotaStatus.autorizada;
}
