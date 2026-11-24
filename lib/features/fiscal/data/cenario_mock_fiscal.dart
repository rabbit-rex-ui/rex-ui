/// Cenários do Focus NFe **simulado** (guia fiscal §11). Só têm efeito com o
/// backend em modo mock (perfis `dev`/`seed`); fora dele o header é ignorado.
///
/// A UI só oferece estes cenários em build de debug.
abstract final class CenarioMockFiscal {
  /// Header que escolhe o que a "SEFAZ" faz, por requisição.
  static const header = 'X-Fiscal-Mock-Scenario';

  /// `POST …/emitir`. O primeiro é o padrão do mock.
  static const emissao = ['AUTORIZADA', 'REJEITADA', 'PROCESSANDO', 'TIMEOUT'];

  /// `POST …/cancelar`. O primeiro é o padrão do mock.
  static const cancelamento = [
    'HOMOLOGADO',
    'PRAZO_EXPIRADO',
    'REJEITADO',
    'TIMEOUT',
    'SEM_RESPOSTA',
  ];

  /// Alavanca "SEFAZ terminou" — conclui na hora uma nota `SENT`.
  static const desfecho = ['AUTORIZADA', 'REJEITADA', 'PROCESSANDO'];
}
