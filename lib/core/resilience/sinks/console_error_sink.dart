import 'dart:async';
import 'dart:developer' as developer;

import 'package:rabbit_pdv/core/resilience/crash_record.dart';
import 'package:rabbit_pdv/core/resilience/sinks/error_sink.dart';

/// Sink que escreve no console via `dart:developer.log`. Em desenvolvimento
/// aparece nos logs do `flutter run`. Em release não custa nada.
class ConsoleErrorSink implements ErrorSink {
  @override
  String get name => 'console';

  @override
  Future<void> init() async {}

  @override
  void emit(CrashRecord record) {
    // Severity → level seguindo convenção do package:logging.
    // (FINE=500, INFO=800, WARNING=900, SEVERE=1000, SHOUT=1200)
    final level = switch (record.severity) {
      CrashSeverity.info => 800,
      CrashSeverity.warning => 900,
      CrashSeverity.error => 1000,
      CrashSeverity.fatal => 1200,
    };
    developer.log(
      record.message,
      time: record.timestamp,
      level: level,
      name: 'pdv.${record.source.name}',
      stackTrace: record.stackTrace == null
          ? null
          : StackTrace.fromString(record.stackTrace!),
    );
  }

  @override
  Future<void> dispose() async {}
}
