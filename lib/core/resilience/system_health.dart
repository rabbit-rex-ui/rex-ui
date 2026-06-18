import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:rabbit_pdv/core/resilience/crash_record.dart';
import 'package:rabbit_pdv/core/resilience/error_reporter.dart';

/// Severidade de uma issue encontrada pelo health check.
enum HealthSeverity { info, warning, error }

/// Uma issue identificada pelo health check.
class HealthIssue {
  final String key;
  final String message;
  final HealthSeverity severity;
  final Map<String, Object?> context;

  HealthIssue({
    required this.key,
    required this.message,
    required this.severity,
    this.context = const {},
  });

  Map<String, Object?> toJson() => {
    'key': key,
    'msg': message,
    'lvl': severity.name,
    if (context.isNotEmpty) 'ctx': context,
  };
}

/// Resultado do health check de boot.
class SystemHealthReport {
  final List<HealthIssue> issues;
  final DateTime checkedAt;

  SystemHealthReport({required this.issues, required this.checkedAt});

  /// True se nenhuma issue de severidade `error` foi detectada. Warnings
  /// não bloqueiam — operador é avisado, app prossegue.
  bool get ok => !issues.any((i) => i.severity == HealthSeverity.error);
}

/// Verificações executadas no boot do app, antes de mostrar a UI.
///
/// **Filosofia:** quanto antes detectamos algo ruim, mais cedo o operador
/// (ou nosso sistema de log) sabe. Tudo aqui deve ser **rápido** (< 1s
/// total) e **idempotente** — chamar duas vezes não causa efeito colateral.
///
/// Checagens no MVP:
/// 1. Diretório de logs gravável.
/// 2. Detecção de outra instância em execução (lock file).
/// 3. Sanity check do relógio do sistema (drift vs Stopwatch monotônico).
///
/// **Fora do escopo do MVP, reservado pra Camada 3 (com FFI/plugins):**
/// - Espaço livre em disco (precisa `GetDiskFreeSpaceEx` no Win32).
/// - Estado da bateria do no-break (precisa `GetSystemPowerStatus`).
/// - Conectividade de rede (precisa `connectivity_plus`).
/// - Versão do Windows e patch level (telemetria).
class SystemHealth {
  static const _lockFileName = 'pdv.lock';

  /// Tempo (em segundos) sob o qual consideramos uma instância "viva".
  /// Refresh do lock file deve ocorrer em intervalo menor que isso.
  static const _lockStaleSeconds = 60;

  static Future<SystemHealthReport> check() async {
    final issues = <HealthIssue>[];

    await _checkLogDir(issues);
    await _checkSingleInstance(issues);
    await _checkClockDrift(issues);

    final report = SystemHealthReport(
      issues: issues,
      checkedAt: DateTime.now(),
    );

    // Sempre registra um sumário do boot, pra termos breadcrumb.
    ErrorReporter.instance.captureInfo(
      'health_check_completed',
      source: CrashSource.health,
      context: {
        'ok': report.ok,
        'count': issues.length,
        if (issues.isNotEmpty) 'issues': issues.map((i) => i.toJson()).toList(),
      },
    );

    // Cada issue não-info também vira um warning no reporter.
    for (final i in issues.where((i) => i.severity != HealthSeverity.info)) {
      ErrorReporter.instance.captureWarning(
        'health_${i.key}',
        source: CrashSource.health,
        context: {'msg': i.message, ...i.context},
      );
    }

    return report;
  }

  // ---- Checagens ------------------------------------------------------------

  static Future<void> _checkLogDir(List<HealthIssue> issues) async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}${Platform.pathSeparator}logs');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      // Tenta criar e remover um arquivo de teste.
      final probe = File('${dir.path}${Platform.pathSeparator}.health-probe');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
    } catch (e) {
      issues.add(
        HealthIssue(
          key: 'log_dir_unwritable',
          message:
              'Diretório de logs não está gravável. '
              'Logs e crash reports vão se perder.',
          severity: HealthSeverity.error,
          context: {'error': e.toString()},
        ),
      );
    }
  }

  static Future<void> _checkSingleInstance(List<HealthIssue> issues) async {
    try {
      final base = await getApplicationSupportDirectory();
      final lockFile = File(
        '${base.path}${Platform.pathSeparator}$_lockFileName',
      );

      // Se já existe e foi atualizado recentemente, outra instância pode
      // estar viva. Não bloqueamos — apenas avisamos.
      if (await lockFile.exists()) {
        try {
          final raw = await lockFile.readAsString();
          final data = jsonDecode(raw) as Map<String, Object?>;
          final tsStr = data['ts'] as String?;
          if (tsStr != null) {
            final ts = DateTime.tryParse(tsStr);
            if (ts != null) {
              final age = DateTime.now().difference(ts).inSeconds;
              if (age < _lockStaleSeconds) {
                issues.add(
                  HealthIssue(
                    key: 'possible_second_instance',
                    message:
                        'Outro processo PDV pode estar rodando '
                        '(lock file atualizado há ${age}s).',
                    severity: HealthSeverity.warning,
                    context: {'lock_age_s': age, 'other_pid': data['pid']},
                  ),
                );
              }
            }
          }
        } catch (_) {
          // Lock file corrompido — ignora e sobrescreve.
        }
      }

      // Sobrescreve com nosso PID e timestamp atuais.
      await lockFile.writeAsString(
        jsonEncode({
          'pid': pid,
          'ts': DateTime.now().toUtc().toIso8601String(),
          'platform': Platform.operatingSystem,
        }),
        flush: true,
      );
    } catch (e) {
      // Falha ao mexer com lock: warning, não bloqueia.
      issues.add(
        HealthIssue(
          key: 'lock_file_io_failure',
          message: 'Não foi possível verificar instância única.',
          severity: HealthSeverity.warning,
          context: {'error': e.toString()},
        ),
      );
    }
  }

  static Future<void> _checkClockDrift(List<HealthIssue> issues) async {
    // Compara DateTime.now() com Stopwatch (relógio monotônico que não
    // mexe quando o operador altera a hora do Windows). Drift > 200ms
    // num intervalo de 100ms indica que o relógio do sistema foi mexido
    // ou está com algum bug.
    try {
      final sw = Stopwatch()..start();
      final t0 = DateTime.now();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final t1 = DateTime.now();
      sw.stop();

      final wallDelta = t1.difference(t0).inMilliseconds;
      final monoDelta = sw.elapsedMilliseconds;
      final drift = (wallDelta - monoDelta).abs();

      if (drift > 200) {
        issues.add(
          HealthIssue(
            key: 'clock_drift_suspect',
            message:
                'Relógio do sistema parece instável '
                '(drift ${drift}ms em 100ms). '
                'Vendas podem ficar com timestamp incorreto.',
            severity: HealthSeverity.warning,
            context: {
              'wall_delta_ms': wallDelta,
              'mono_delta_ms': monoDelta,
              'drift_ms': drift,
            },
          ),
        );
      }
    } catch (e) {
      // Se nem isso roda, algo está bem errado mas não vamos bloquear.
      issues.add(
        HealthIssue(
          key: 'clock_check_failed',
          message: 'Health check do relógio falhou.',
          severity: HealthSeverity.warning,
          context: {'error': e.toString()},
        ),
      );
    }
  }

  /// Refresh do lock file — chamar periodicamente (ex: a cada 20s) pra
  /// que detecção de "instância viva" funcione. Falha silenciosamente.
  static Future<void> refreshInstanceLock() async {
    try {
      final base = await getApplicationSupportDirectory();
      final lockFile = File(
        '${base.path}${Platform.pathSeparator}$_lockFileName',
      );
      await lockFile.writeAsString(
        jsonEncode({
          'pid': pid,
          'ts': DateTime.now().toUtc().toIso8601String(),
          'platform': Platform.operatingSystem,
        }),
        flush: true,
      );
    } catch (_) {
      // Ignora — best-effort.
    }
  }
}
