/// Corpo de POST /devices/activate. Rota NÃO autenticada — o próprio
/// enrollmentToken é a autorização.
class DeviceActivationRequest {
  final String enrollmentToken;
  final String publicKeyPem;

  const DeviceActivationRequest({
    required this.enrollmentToken,
    required this.publicKeyPem,
  });

  Map<String, dynamic> toJson() => {
    'enrollmentToken': enrollmentToken,
    'publicKeyPem': publicKeyPem,
  };
}

/// Resposta da ativação.
/// ⚠️ CONFERIR no Swagger os nomes exatos do record de resposta.
class DeviceActivationResponse {
  final String deviceId;
  final String tenantId;
  final String cashRegisterId;
  final String? credentialFingerprint;

  const DeviceActivationResponse({
    required this.deviceId,
    required this.tenantId,
    required this.cashRegisterId,
    this.credentialFingerprint,
  });

  factory DeviceActivationResponse.fromJson(Map<String, dynamic> j) =>
      DeviceActivationResponse(
        deviceId: j['deviceId'] as String,
        tenantId: j['tenantId'] as String,
        cashRegisterId: j['cashRegisterId'] as String,
        credentialFingerprint: j['credentialFingerprint'] as String?,
      );
}
