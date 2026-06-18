/// Como o cliente está identificado no atendimento.
enum ClienteTipo {
  /// "Sem identificação" — fluxo padrão de supermercado.
  anonimo,

  /// Apenas CPF na nota, sem cadastro.
  cpf,

  /// Cliente cadastrado (fidelidade/crediário).
  cadastrado,
}
