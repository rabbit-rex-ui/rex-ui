/// Identidade criptográfica do terminal.
///
/// A chave privada NUNCA sai do dispositivo. Em produção (Windows) a
/// implementação deve ser CNG/DPAPI via FFI, com a chave marcada como
/// NÃO-EXPORTÁVEL. O fallback em Dart puro existe só para desenvolvimento.
abstract interface class TerminalKeyStore {
  /// Já existe par de chaves neste terminal?
  Future<bool> hasKeyPair();

  /// Garante o par de chaves e devolve a PÚBLICA em PEM SPKI (X.509),
  /// formato exigido por POST /devices/activate.
  Future<String> ensureKeyPairAndExportPublicPem();

  /// SHA-256 (hex) do DER SPKI da pública — para conferência com o
  /// credentialFingerprint devolvido pelo servidor.
  Future<String> publicKeyFingerprint();

  /// Assina bytes com a chave privada (login por prova-de-posse — futuro).
  Future<List<int>> sign(List<int> data);

  /// Descarta a identidade local (re-provisionamento).
  Future<void> destroy();
}
