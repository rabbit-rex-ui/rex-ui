/// Resposta de GET /auth/me. employeeName já vem resolvido pelo servidor
/// (nome social quando houver, senão nome completo). tenantName é o nome
/// fantasia da filial.
class AuthMe {
  final String employeeId;
  final String employeeName;
  final String loginCode;
  final String tenantId;
  final String tenantName;
  final List<String> permissions;
  final List<String> roles;

  const AuthMe({
    required this.employeeId,
    required this.employeeName,
    required this.loginCode,
    required this.tenantId,
    required this.tenantName,
    required this.permissions,
    required this.roles,
  });

  factory AuthMe.fromJson(Map<String, dynamic> j) => AuthMe(
    employeeId: (j['employeeId'] as String?) ?? '',
    employeeName: (j['employeeName'] as String?) ?? '',
    loginCode: (j['loginCode'] as String?) ?? '',
    tenantId: (j['tenantId'] as String?) ?? '',
    tenantName: (j['tenantName'] as String?) ?? '',
    permissions: ((j['permissions'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(growable: false),
    roles: ((j['roles'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(growable: false),
  );

  bool temPermissao(String code) => permissions.contains(code);

  /// Abreviação para a barra: "João da Silva" → "João S.".
  String get nomeAbreviado {
    final partes = employeeName.trim().split(RegExp(r'\s+'));
    if (partes.length < 2) return employeeName;
    return '${partes.first} ${partes.last[0]}.';
  }
}
