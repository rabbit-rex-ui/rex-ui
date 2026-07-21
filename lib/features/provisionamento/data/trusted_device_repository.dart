import 'package:rabbit_pdv/core/auth/jwt_decoder.dart';
import 'package:rabbit_pdv/core/auth/trusted_device_store.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/provisionamento/data/dto/device_enrollment_dtos.dart';

abstract interface class TrustedDeviceRepository {
  /// True se a estação já tem device para o tenant ativo.
  Future<bool> jaConfiavel();

  /// POST /admin/trusted-devices (bootstrap; sem headers de device). Persiste
  /// o par retornado em DPAPI, associado ao tenant ativo.
  Future<Result<void, Failure>> registrarEstacao(String deviceLabel);
}

class TrustedDeviceRepositoryImpl implements TrustedDeviceRepository {
  TrustedDeviceRepositoryImpl(this._api, this._devices, this._tokens);
  final ApiClient _api;
  final TrustedDeviceStore _devices;
  final TokenStore _tokens;

  String? get _tenantId {
    final t = _tokens.accessToken;
    return t == null ? null : decodeJwtPayload(t)['tenant_id'] as String?;
  }

  @override
  Future<bool> jaConfiavel() async {
    final tid = _tenantId;
    if (tid == null) return false;
    return (await _devices.get(tid)) != null;
  }

  @override
  Future<Result<void, Failure>> registrarEstacao(String deviceLabel) async {
    final tid = _tenantId;
    if (tid == null) {
      return const Err(
        BusinessRuleFailure('Sessão sem filial ativa.', code: 'SEM_TENANT'),
      );
    }
    final result = await _api.send<TrustedDeviceResponse>(
      (dio) => dio.post<dynamic>(
        '/admin/trusted-devices',
        data: TrustedDeviceRequest(deviceLabel: deviceLabel).toJson(),
      ),
      decode: (data) =>
          TrustedDeviceResponse.fromJson(data as Map<String, dynamic>),
    );
    return switch (result) {
      Ok(:final value) => await _persistir(tid, value),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<void, Failure>> _persistir(
    String tenantId,
    TrustedDeviceResponse r,
  ) async {
    await _devices.save(
      tenantId,
      TrustedDeviceCredential(deviceId: r.deviceId, secret: r.deviceSecret),
    );
    return const Ok<void, Failure>(null);
  }
}
