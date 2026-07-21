/// Corpo de POST /admin/device-enrollments.
class DeviceEnrollmentRequest {
  final String deviceLabel;
  final String cashRegisterId;

  const DeviceEnrollmentRequest({
    required this.deviceLabel,
    required this.cashRegisterId,
  });

  Map<String, dynamic> toJson() => {
    'deviceLabel': deviceLabel,
    'cashRegisterId': cashRegisterId,
  };
}

/// Resposta 201. Record backend: IssueDeviceEnrollmentResponse(enrollmentId,
/// enrollmentToken, expiresAt). O enrollmentToken aparece UMA vez, não
/// recuperável — nunca logar/persistir.
class DeviceEnrollmentResponse {
  final String enrollmentId;
  final String enrollmentToken;
  final DateTime expiresAt;

  const DeviceEnrollmentResponse({
    required this.enrollmentId,
    required this.enrollmentToken,
    required this.expiresAt,
  });

  factory DeviceEnrollmentResponse.fromJson(Map<String, dynamic> j) =>
      DeviceEnrollmentResponse(
        enrollmentId: j['enrollmentId'] as String,
        enrollmentToken: j['enrollmentToken'] as String,
        expiresAt: _parseInstant(j['expiresAt']),
      );
}

/// Corpo de POST /admin/trusted-devices (bootstrap da estação).
class TrustedDeviceRequest {
  final String deviceLabel;
  const TrustedDeviceRequest({required this.deviceLabel});

  Map<String, dynamic> toJson() => {'deviceLabel': deviceLabel};
}

/// Resposta 201. Record backend: EnrollDeviceResponse(deviceId, deviceSecret).
/// deviceSecret aparece UMA vez — persistir em DPAPI, nunca logar.
class TrustedDeviceResponse {
  final String deviceId;
  final String deviceSecret;

  const TrustedDeviceResponse({
    required this.deviceId,
    required this.deviceSecret,
  });

  factory TrustedDeviceResponse.fromJson(Map<String, dynamic> j) =>
      TrustedDeviceResponse(
        deviceId: j['deviceId'] as String,
        deviceSecret: j['deviceSecret'] as String,
      );
}

/// Parser defensivo de Instant: aceita ISO-8601 (String) ou epoch (num) —
/// cobre os dois modos do Jackson. Validar contra payload real no ambiente.
DateTime _parseInstant(Object? v) {
  if (v is String) return DateTime.parse(v).toUtc();
  if (v is num) {
    final n = v.toInt();
    final ms = n > 1000000000000 ? n : n * 1000; // >10^12 ≈ millis
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
  throw FormatException('expiresAt em formato inesperado: $v');
}
