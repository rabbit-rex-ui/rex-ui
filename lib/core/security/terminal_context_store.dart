import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Identidade do terminal após a ativação.
class TerminalContext {
  final String deviceId;
  final String tenantId;
  final String cashRegisterId;

  /// Resolvido depois, no primeiro bootstrap autenticado
  /// (GET /pdv/caixas-fisicos/{cashRegisterId}).
  final String? terminalId;

  const TerminalContext({
    required this.deviceId,
    required this.tenantId,
    required this.cashRegisterId,
    this.terminalId,
  });

  TerminalContext comTerminalId(String t) => TerminalContext(
    deviceId: deviceId,
    tenantId: tenantId,
    cashRegisterId: cashRegisterId,
    terminalId: t,
  );

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'tenantId': tenantId,
    'cashRegisterId': cashRegisterId,
    if (terminalId != null) 'terminalId': terminalId,
  };

  factory TerminalContext.fromJson(Map<String, dynamic> j) => TerminalContext(
    deviceId: j['deviceId'] as String,
    tenantId: j['tenantId'] as String,
    cashRegisterId: j['cashRegisterId'] as String,
    terminalId: j['terminalId'] as String?,
  );
}

/// Guarda a identidade do terminal ativado. Se não há contexto, o terminal
/// não foi provisionado e o operador não deve operar (gate de ativação).
class TerminalContextStore {
  TerminalContextStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            wOptions: WindowsOptions(useBackwardCompatibility: false),
          );

  final FlutterSecureStorage _storage;
  static const _key = 'terminal_context';

  TerminalContext? _cache;
  TerminalContext? get atual => _cache;
  bool get ativado => _cache != null;

  /// Carrega no boot, antes de decidir login x ativação.
  Future<TerminalContext?> carregar() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return _cache = null;
    return _cache = TerminalContext.fromJson(
      json.decode(raw) as Map<String, dynamic>,
    );
  }

  Future<void> salvar(TerminalContext ctx) async {
    _cache = ctx;
    await _storage.write(key: _key, value: json.encode(ctx.toJson()));
  }

  Future<void> limpar() async {
    _cache = null;
    await _storage.delete(key: _key);
  }
}
