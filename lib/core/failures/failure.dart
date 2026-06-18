import 'package:equatable/equatable.dart';

/// Falhas de domínio. Pareadas com [Result] para fluxo sem exceptions.
/// Agrupe por "como a UI reage" — não crie uma Failure por cenário.
sealed class Failure extends Equatable {
  final String message;
  final Object? cause;

  const Failure(this.message, {this.cause});

  @override
  List<Object?> get props => [runtimeType, message];
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.cause});
}

class ValidationFailure extends Failure {
  final Map<String, String> fieldErrors;
  const ValidationFailure(
    super.message, {
    this.fieldErrors = const {},
    super.cause,
  });

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

class NetworkFailure extends Failure {
  final int? statusCode;
  const NetworkFailure(super.message, {this.statusCode, super.cause});

  @override
  List<Object?> get props => [...super.props, statusCode];
}

class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.cause});
}

class BusinessRuleFailure extends Failure {
  /// Código curto pra roteamento na UI ("CAIXA_BLOQUEADO", "INDISPONIVEL").
  final String code;
  const BusinessRuleFailure(super.message, {required this.code, super.cause});

  @override
  List<Object?> get props => [...super.props, code];
}

class HardwareFailure extends Failure {
  final String device;
  const HardwareFailure(super.message, {required this.device, super.cause});

  @override
  List<Object?> get props => [...super.props, device];
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.cause});
}
