class LoginRequest {
  final String loginCode;
  final String password;
  final String? tenantId; // opcional; normalmente NÃO enviar (guia §1.1)

  const LoginRequest({
    required this.loginCode,
    required this.password,
    this.tenantId,
  });

  Map<String, dynamic> toJson() => {
    'loginCode': loginCode,
    'password': password,
    // só inclui a chave se explicitamente setado (forçar filial específica)
    if (tenantId != null) 'tenantId': tenantId,
  };
}

class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.tenantId,
    required this.passwordMustChange,
    this.refreshToken,
  });
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final String tenantId;
  final bool passwordMustChange;
  final String? refreshToken;

  factory LoginResponse.fromJson(Map<String, dynamic> j) => LoginResponse(
    accessToken: j['accessToken'] as String,
    tokenType: (j['tokenType'] as String?) ?? 'Bearer',
    expiresIn: (j['expiresIn'] as num?)?.toInt() ?? 0,
    tenantId: (j['tenantId'] as String?) ?? '',
    passwordMustChange: (j['passwordMustChange'] as bool?) ?? false,
    refreshToken: j['refreshToken'] as String?,
  );
}

class TrocarSenhaRequest {
  const TrocarSenhaRequest({required this.senhaAtual, required this.novaSenha});
  final String senhaAtual;
  final String novaSenha;

  Map<String, dynamic> toJson() => {
    'senhaAtual': senhaAtual,
    'novaSenha': novaSenha,
  };
}
