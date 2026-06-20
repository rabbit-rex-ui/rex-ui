import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Sessão em memória do operador, derivada do access token.
/// Decodificada SOMENTE para adaptar a UI — nunca para segurança (guia §2.3).
class AuthSession extends Equatable {
  final String accessToken;
  final String? refreshToken;
  final String employeeId; // claim `sub`
  final String tenantId;
  final String loginCode; // claim `login_code`
  final List<String> permissions; // claim `permissions`
  final DateTime expiresAt;
  final bool passwordMustChange;
  final String? authUserId;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.employeeId,
    required this.tenantId,
    required this.loginCode,
    required this.permissions,
    required this.expiresAt,
    required this.passwordMustChange,
    required this.authUserId,
  });

  bool hasPermission(String code) => permissions.contains(code);

  factory AuthSession.fromAccessToken(
    String accessToken, {
    String? refreshToken,
    String? tenantId,
    bool passwordMustChange = false,
  }) {
    final claims = _decodeJwtPayload(accessToken);
    final exp = claims['exp'];
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      employeeId: (claims['sub'] as String?) ?? '',
      tenantId: tenantId ?? (claims['tenant_id'] as String?) ?? '',
      loginCode: (claims['login_code'] as String?) ?? '',
      permissions: ((claims['permissions'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      expiresAt: exp is int
          ? DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
          : DateTime.now().toUtc(),
      passwordMustChange: passwordMustChange,
      authUserId: claims['auth_user_id'] as String?,
    );
  }

  static Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return const {};
    var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    switch (payload.length % 4) {
      case 2:
        payload += '==';
      case 3:
        payload += '=';
    }
    final map = json.decode(utf8.decode(base64.decode(payload)));
    return map is Map<String, dynamic> ? map : const {};
  }

  @override
  List<Object?> get props => [
    accessToken,
    employeeId,
    tenantId,
    loginCode,
    permissions,
    expiresAt,
    passwordMustChange,
  ];
}
