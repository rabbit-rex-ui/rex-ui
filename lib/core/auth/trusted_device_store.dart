import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Par (deviceId, secret) de uma estação confiável, para uma filial.
class TrustedDeviceCredential {
  final String deviceId;
  final String secret;
  const TrustedDeviceCredential({required this.deviceId, required this.secret});

  Map<String, dynamic> toJson() => {'deviceId': deviceId, 'secret': secret};
  factory TrustedDeviceCredential.fromJson(Map<String, dynamic> j) =>
      TrustedDeviceCredential(
        deviceId: j['deviceId'] as String,
        secret: j['secret'] as String,
      );
}

/// Guarda credenciais de trusted device POR TENANT, em armazenamento seguro
/// (DPAPI no Windows). O secret é bearer — nunca vai para log/ErrorReporter.
///
/// Por-tenant porque o backend casa id+secret+tenant_id (guia §3.2): a mesma
/// estação operando 2 filiais precisa de 1 device por filial.
class TrustedDeviceStore {
  TrustedDeviceStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            wOptions: WindowsOptions(useBackwardCompatibility: false),
          );

  final FlutterSecureStorage _storage;
  static const _key =
      'trusted_devices'; // JSON: { tenantId: {deviceId, secret} }

  Map<String, TrustedDeviceCredential>? _cache;

  Future<Map<String, TrustedDeviceCredential>> _load() async {
    if (_cache != null) return _cache!;
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return _cache = {};
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return _cache = decoded.map(
      (k, v) => MapEntry(
        k,
        TrustedDeviceCredential.fromJson(v as Map<String, dynamic>),
      ),
    );
  }

  /// Pré-carrega o cache no bootstrap (antes de qualquer request /admin).
  Future<void> warmUp() => _load();

  /// Leitura síncrona para o interceptor (usa o cache aquecido).
  TrustedDeviceCredential? peek(String tenantId) => _cache?[tenantId];

  Future<TrustedDeviceCredential?> get(String tenantId) async =>
      (await _load())[tenantId];

  Future<void> save(String tenantId, TrustedDeviceCredential cred) async {
    final m = await _load();
    m[tenantId] = cred;
    _cache = m;
    await _persist(m);
  }

  Future<void> remove(String tenantId) async {
    final m = await _load();
    m.remove(tenantId);
    _cache = m;
    await _persist(m);
  }

  Future<void> _persist(Map<String, TrustedDeviceCredential> m) async {
    await _storage.write(
      key: _key,
      value: json.encode(m.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }
}
