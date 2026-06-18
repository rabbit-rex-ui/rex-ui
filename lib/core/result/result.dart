/// Resultado tipado (ADR-0004). `T` = sucesso, `F` = falha.
/// Repositórios retornam Future<Result<T, Failure>>; a UI faz switch ou fold.
sealed class Result<T, F> {
  const Result();

  R fold<R>({
    required R Function(T value) onOk,
    required R Function(F failure) onErr,
  });
}

final class Ok<T, F> extends Result<T, F> {
  const Ok(this.value);
  final T value;

  @override
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(F failure) onErr,
  }) => onOk(value);
}

final class Err<T, F> extends Result<T, F> {
  const Err(this.failure);
  final F failure;

  @override
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(F failure) onErr,
  }) => onErr(failure);
}
