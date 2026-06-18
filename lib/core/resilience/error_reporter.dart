import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:rabbit_pdv/core/resilience/crash_record.dart';
import 'package:rabbit_pdv/core/resilience/sinks/console_error_sink.dart';
import 'package:rabbit_pdv/core/resilience/sinks/error_sink.dart';
import 'package:rabbit_pdv/core/resilience/sinks/file_error_sink.dart';

/// Coordenador central da captura de eventos. Singleton porque os hooks
/// do framework (`FlutterError.onError`, `PlatformDispatcher.onError`) são
/// globais — não faz sentido instanciar múltiplos.
///
/// **Contrato:**
/// - Nunca lança exceção. Se algo dá errado no próprio reporter, engole.
///   Erros do logger não podem cascatear.
/// - É seguro chamar `capture*` mesmo antes de `init()` completar
///   (eventos vão pro console e ficam buffered no FileSink interno).
class ErrorReporter {
  ErrorReporter._();
  static final ErrorReporter instance = ErrorReporter._();

  final List<ErrorSink> _sinks = [];
  bool _initialized = false;
  String? _appVersion;

  ConsoleErrorSink? _console;
  FileErrorSink? _file;

  /// Acesso ao sink de arquivo. Útil pra UI de diagnóstico ("Abrir pasta
  /// de logs"). Pode ser `null` se a inicialização falhar.
  FileErrorSink? get fileSink => _file;

  /// Inicializa os sinks padrão. Idempotente.
  Future<void> init({String? appVersion}) async {
    if (_initialized) return;
    _appVersion = appVersion;

    _console = ConsoleErrorSink();
    _file = FileErrorSink();

    _sinks
      ..add(_console!)
      ..add(_file!);

    // Inicializa cada sink protegido — se um falhar, os outros continuam.
    for (final s in _sinks) {
      try {
        await s.init();
      } catch (_) {
        // Sink sem init válido vira no-op (sua próprio emit já é fail-safe).
      }
    }

    _initialized = true;
    captureInfo('reporter_initialized', source: CrashSource.lifecycle);
  }

  /// Captura uma exception qualquer com a stack opcional.
  void capture(
    Object error,
    StackTrace? stack, {
    CrashSource source = CrashSource.domain,
    CrashSeverity severity = CrashSeverity.error,
    String? message,
    Map<String, Object?> context = const {},
  }) {
    final rec = CrashRecord(
      timestamp: DateTime.now(),
      severity: severity,
      source: source,
      message: message ?? error.toString(),
      stackTrace: stack?.toString(),
      context: context,
      appVersion: _appVersion,
    );
    _emit(rec);
  }

  /// Atalho para erros vindos do framework.
  void captureFlutterError(FlutterErrorDetails details) {
    capture(
      details.exception,
      details.stack,
      source: CrashSource.flutter,
      severity: CrashSeverity.error,
      message: details.exceptionAsString(),
      context: {
        if (details.library != null) 'library': details.library,
        if (details.context != null) 'context': details.context.toString(),
      },
    );
  }

  /// Eventos informativos / breadcrumbs.
  void captureInfo(
    String message, {
    CrashSource source = CrashSource.domain,
    Map<String, Object?> context = const {},
  }) {
    _emit(CrashRecord(
      timestamp: DateTime.now(),
      severity: CrashSeverity.info,
      source: source,
      message: message,
      context: context,
      appVersion: _appVersion,
    ));
  }

  /// Avisos não-fatais (health-check parcial, etc.).
  void captureWarning(
    String message, {
    CrashSource source = CrashSource.domain,
    Map<String, Object?> context = const {},
  }) {
    _emit(CrashRecord(
      timestamp: DateTime.now(),
      severity: CrashSeverity.warning,
      source: source,
      message: message,
      context: context,
      appVersion: _appVersion,
    ));
  }

  void _emit(CrashRecord rec) {
    // Em debug, joga no print também — facilita ver no terminal mesmo
    // sem dart:developer.log estar visível.
    if (kDebugMode) {
      // ignore: avoid_print
      print('[pdv][${rec.severity.name}][${rec.source.name}] ${rec.message}');
      if (rec.stackTrace != null && rec.severity.index >= CrashSeverity.error.index) {
        // ignore: avoid_print
        print(rec.stackTrace);
      }
    }

    for (final s in _sinks) {
      try {
        s.emit(rec);
      } catch (_) {
        // Sink quebrado é problema do sink; não pode interromper o caller.
      }
    }
  }

  /// Encerra os sinks. Em PDV raramente é chamado (app vive enquanto a
  /// máquina vive), mas existe pra cleanup determinístico em testes.
  Future<void> dispose() async {
    for (final s in _sinks) {
      try {
        await s.dispose();
      } catch (_) {}
    }
    _sinks.clear();
    _initialized = false;
  }

  /// Força flush dos sinks com persistência (arquivo, eventualmente
  /// telemetria). Chamado em `AppLifecycleState.detached` pelo
  /// [LifecycleMonitor] — última chance de gravar antes do processo morrer.
  Future<void> flushAll() async {
    if (_file != null) await _file!.flushNow();
  }
}
