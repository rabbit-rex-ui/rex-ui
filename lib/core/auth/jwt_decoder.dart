import 'dart:convert';

/// Lê os claims do payload de um JWT (sem validar assinatura — o backend já
/// validou). Usado para extrair `sub`, `auth_user_id`, `permissions`.
Map<String, dynamic> decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) throw const FormatException('JWT malformado');
  final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
  return jsonDecode(payload) as Map<String, dynamic>;
}
