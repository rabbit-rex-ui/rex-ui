import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'package:rabbit_pdv/core/resilience/crash_record.dart';
import 'package:rabbit_pdv/core/resilience/error_reporter.dart';

/// Observa o ciclo de vida do app e reage a eventos críticos do SO.
///
/// **Eventos relevantes em desktop Windows:**
/// - `resumed`: janela ganhou foco — operador voltou.
/// - `inactive`: janela perdeu foco (Alt+Tab, outro programa).
/// - `hidden`: minimizada ou coberta por outra janela.
/// - `paused`: sistema sinalizou que o app vai parar (lock screen, switch
///   user). Persistir o que dá agora.
/// - `detached`: o app está prestes a morrer (shutdown do Windows ou
///   fechamento). Última chance — força flush dos logs.
///
/// Também escuta `didHaveMemoryPressure` (raro em desktop mas existe) e
/// mudanças de localização (timezone/locale alteradas no SO).
class LifecycleMonitor with WidgetsBindingObserver {
  LifecycleMonitor._();
  static final LifecycleMonitor instance = LifecycleMonitor._();

  AppLifecycleState? _lastState;
  AppLifecycleState? get lastState => _lastState;

  bool _started = false;

  /// Registra o observador. Idempotente.
  void start() {
    if (_started) return;
    WidgetsBinding.instance.addObserver(this);
    _started = true;
    ErrorReporter.instance.captureInfo(
      'lifecycle_monitor_started',
      source: CrashSource.lifecycle,
    );
  }

  /// Remove o observador. Em PDV raramente é chamado.
  void stop() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previous = _lastState;
    _lastState = state;

    ErrorReporter.instance.captureInfo(
      'lifecycle_${state.name}',
      source: CrashSource.lifecycle,
      context: {
        if (previous != null) 'previous': previous.name,
      },
    );

    // Em `paused` (Windows lock screen, switch user) e `detached`
    // (shutdown), forçamos flush — pode ser nossa última chance.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(ErrorReporter.instance.flushAll());
    }
  }

  @override
  void didHaveMemoryPressure() {
    // Em desktop, esse sinal é raríssimo, mas se chegar é forte indício
    // de que outro processo (Windows Update, scan de AV) estourou a RAM.
    ErrorReporter.instance.captureWarning(
      'memory_pressure',
      source: CrashSource.lifecycle,
    );
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // Operador trocou de locale no Windows — pode afetar nosso parser
    // de valor monetário (vírgula vs ponto). Registrar pra investigação.
    ErrorReporter.instance.captureWarning(
      'locale_changed',
      source: CrashSource.lifecycle,
      context: {
        'locales': locales?.map((l) => l.toLanguageTag()).toList() ?? const [],
      },
    );
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    // Disparado quando o SO pede pra fechar (Alt+F4, botão X). Damos a
    // chance de flush antes de confirmar a saída. Retornar `exit` aceita
    // o fechamento; retornar `cancel` impediria — não fazemos isso porque
    // recusar fechamento em PDV pode irritar o operador legítimo.
    ErrorReporter.instance.captureInfo(
      'exit_requested',
      source: CrashSource.lifecycle,
    );
    await ErrorReporter.instance.flushAll();
    return AppExitResponse.exit;
  }
}
