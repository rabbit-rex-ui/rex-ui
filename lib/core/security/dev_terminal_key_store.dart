import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

import 'package:rabbit_pdv/core/security/terminal_key_store.dart';

/// ⚠️⚠️ IMPLEMENTAÇÃO DE DESENVOLVIMENTO — NÃO USAR EM PRODUÇÃO ⚠️⚠️
///
/// Gera EC P-256 em Dart puro (pointycastle) e guarda a privada em secure
/// storage. A chave privada É EXPORTÁVEL — viola o requisito de identidade
/// do terminal. Produção exige Windows CNG via FFI
/// (NCryptCreatePersistedKey sem flag de export).
class DevTerminalKeyStore implements TerminalKeyStore {
  DevTerminalKeyStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            wOptions: WindowsOptions(useBackwardCompatibility: false),
          ) {
    assert(() {
      debugPrint(
        '[SEGURANÇA] DevTerminalKeyStore em uso — chave EXPORTÁVEL. '
        'Trocar por CNG/FFI antes de release.',
      );
      return true;
    }());
  }

  final FlutterSecureStorage _storage;
  static const _keyPriv = 'terminal_key_d';
  static const _keyX = 'terminal_key_x';
  static const _keyY = 'terminal_key_y';

  @override
  Future<bool> hasKeyPair() async =>
      (await _storage.read(key: _keyPriv)) != null;

  @override
  Future<String> ensureKeyPairAndExportPublicPem() async =>
      _toPem(await _ensureSpkiDer());

  @override
  Future<String> publicKeyFingerprint() async {
    final spki = await _ensureSpkiDer();
    final hash = SHA256Digest().process(spki);
    return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Future<List<int>> sign(List<int> data) async {
    // Só necessário no login por prova-de-posse (backend ainda não implementou).
    // O formato esperado (DER x raw r||s) precisa ser confirmado antes.
    throw UnimplementedError(
      'sign() será implementado junto com o login por prova-de-posse.',
    );
  }

  @override
  Future<void> destroy() async {
    await _storage.delete(key: _keyPriv);
    await _storage.delete(key: _keyX);
    await _storage.delete(key: _keyY);
  }

  // ---- interno --------------------------------------------------------

  Future<Uint8List> _ensureSpkiDer() async {
    var xB64 = await _storage.read(key: _keyX);
    var yB64 = await _storage.read(key: _keyY);

    if (xB64 == null || yB64 == null) {
      final par = _gerarParDeChaves();
      final pub = par.publicKey as ECPublicKey;
      final priv = par.privateKey as ECPrivateKey;

      final x = _bigIntPara32(pub.Q!.x!.toBigInteger()!);
      final y = _bigIntPara32(pub.Q!.y!.toBigInteger()!);

      await _storage.write(
        key: _keyPriv,
        value: base64.encode(_bigIntPara32(priv.d!)),
      );
      await _storage.write(key: _keyX, value: base64.encode(x));
      await _storage.write(key: _keyY, value: base64.encode(y));

      xB64 = base64.encode(x);
      yB64 = base64.encode(y);
    }

    return _spkiDe(base64.decode(xB64), base64.decode(yB64));
  }

  AsymmetricKeyPair<PublicKey, PrivateKey> _gerarParDeChaves() {
    final secure = Random.secure();
    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => secure.nextInt(256)),
    );
    final rnd = FortunaRandom()..seed(KeyParameter(seed));
    final gerador = ECKeyGenerator()
      ..init(
        ParametersWithRandom(
          ECKeyGeneratorParameters(ECCurve_secp256r1()),
          rnd,
        ),
      );
    return gerador.generateKeyPair();
  }

  static Uint8List _bigIntPara32(BigInt v) {
    final out = Uint8List(32);
    var n = v;
    for (var i = 31; i >= 0; i--) {
      out[i] = (n & BigInt.from(0xff)).toInt();
      n = n >> 8;
    }
    return out;
  }

  /// SPKI DER de chave P-256: cabeçalho fixo (OIDs ecPublicKey + prime256v1)
  /// + ponto não-comprimido 0x04||X||Y.
  static Uint8List _spkiDe(List<int> x, List<int> y) {
    const header = <int>[
      0x30,
      0x59,
      0x30,
      0x13,
      0x06,
      0x07,
      0x2a,
      0x86,
      0x48,
      0xce,
      0x3d,
      0x02,
      0x01,
      0x06,
      0x08,
      0x2a,
      0x86,
      0x48,
      0xce,
      0x3d,
      0x03,
      0x01,
      0x07,
      0x03,
      0x42,
      0x00,
      0x04,
    ];
    return Uint8List.fromList([...header, ...x, ...y]);
  }

  static String _toPem(Uint8List der) {
    final b64 = base64.encode(der);
    final linhas = <String>[];
    for (var i = 0; i < b64.length; i += 64) {
      linhas.add(b64.substring(i, i + 64 > b64.length ? b64.length : i + 64));
    }
    return '-----BEGIN PUBLIC KEY-----\n${linhas.join('\n')}\n-----END PUBLIC KEY-----';
  }
}
