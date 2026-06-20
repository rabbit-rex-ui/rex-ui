import 'package:equatable/equatable.dart';

/// Resposta 200 de POST /auth/login. Campos null são OMITIDOS (guia §3.1).
class LoginResponse extends Equatable {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final bool passwordMustChange;
  final String? refreshToken;
  final String? tenantId;

  const LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.passwordMustChange,
    this.refreshToken,
    this.tenantId,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    accessToken: json['accessToken'] as String,
    tokenType: (json['tokenType'] as String?) ?? 'Bearer',
    expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
    passwordMustChange: (json['passwordMustChange'] as bool?) ?? false,
    refreshToken: json['refreshToken'] as String?,
    tenantId: json['tenantId'] as String?,
  );

  @override
  List<Object?> get props => [
    accessToken,
    tokenType,
    expiresIn,
    passwordMustChange,
    refreshToken,
    tenantId,
  ];
}
