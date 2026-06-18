import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:rabbit_pdv/core/resilience/crash_record.dart';
import 'package:rabbit_pdv/core/resilience/error_reporter.dart';
import 'package:rabbit_pdv/core/resilience/error_widget_builder.dart';
import 'package:rabbit_pdv/core/resilience/lifecycle_monitor.dart';
import 'package:rabbit_pdv/core/resilience/system_health.dart';

/// Bootstrap centraliza:
/// 1. Inicialização do [ErrorReporter] com sinks de console + arquivo.
/// 2. Registro dos três hooks globais do Flutter:
///    - [FlutterError.onError]: erros do framework (build/layout/paint).
///    - [PlatformDispatcher.instance.onError]: erros não tratados no
///      isolate raiz fora do framework (futures soltas).
///    - `runZonedGuarded`: rede de segurança que pega qualquer coisa
///      escapando das duas anteriores.
/// 3. Customização do [ErrorWidget.builder] pra não exibir tela vermelha.
/// 4. [LifecycleMonitor]: observa eventos do SO e força flush em
///    `paused`/`detached`.
/// 5. [SystemHealth.check]: health-check de boot (dir gravável,
///    instância única, drift de relógio).
/// 6. Timer periódico de refresh do lock de instância única.
///
/// Uso em main():
/// ```dart
/// await bootstrap(() async {
///   final prefs = await SharedPreferences.getInstance();
///   return ModularApp(module: AppModule(prefs), child: const AppWidget());
/// });
/// ```
Future<void> bootstrap(Future<Widget> Function() rootBuilder) async {
  // Tudo abaixo roda numa zona com tratador. Futures não-awaited ou
  // Streams sem listener de erro serão capturados aqui.
  await runZonedGuarded<Future<void>>(() async {
    // ---- Binding e reporter ------------------------------------------------
    WidgetsFlutterBinding.ensureInitialized();
    await ErrorReporter.instance.init();

    // ---- Hook 1: framework -------------------------------------------------
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      ErrorReporter.instance.captureFlutterError(details);
      if (kDebugMode) {
        originalOnError?.call(details);
      }
    };

    // ---- Hook 2: platform dispatcher --------------------------------------
    PlatformDispatcher.instance.onError = (error, stack) {
      ErrorReporter.instance.capture(
        error,
        stack,
        source: CrashSource.platform,
      );
      return true;
    };

    // ---- Hook 3: ErrorWidget customizado ----------------------------------
    ErrorWidget.builder = buildErrorWidget;

    // ---- Camada 2: lifecycle + health -------------------------------------
    LifecycleMonitor.instance.start();

    final health = await SystemHealth.check();
    if (!health.ok) {
      // Health check com erro: já foi logado dentro do check, mas marcamos
      // explicitamente aqui pra ficar visível como breadcrumb.
      ErrorReporter.instance.captureWarning(
        'app_starting_with_unhealthy_environment',
        source: CrashSource.health,
        context: {'issues_count': health.issues.length},
      );
    }

    // Refresh periódico do lock file pra detecção de instância única
    // continuar funcionando enquanto o app está vivo.
    Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(SystemHealth.refreshInstanceLock()),
    );

    // ---- Run app -----------------------------------------------------------
    ErrorReporter.instance.captureInfo(
      'app_start',
      source: CrashSource.lifecycle,
      context: {
        'mode': kDebugMode ? 'debug' : (kProfileMode ? 'profile' : 'release'),
        'platform': defaultTargetPlatform.name,
        'health_ok': health.ok,
      },
    );

    final root = await rootBuilder();
    runApp(root);
  }, (error, stack) {
    // Tudo que escapa cai aqui — última camada.
    ErrorReporter.instance.capture(
      error,
      stack,
      source: CrashSource.zone,
      severity: CrashSeverity.fatal,
    );
  });
}
