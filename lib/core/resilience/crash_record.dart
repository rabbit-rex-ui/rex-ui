import 'dart:convert';

/// Severidade de um evento capturado pelo [ErrorReporter].
enum CrashSeverity {
  /// Informação contextual (boot, transição de estado importante).
  info,

  /// Algo está fora do ideal mas não impede operação. Ex: health-check
  /// falhou em uma checagem opcional, latência alta.
  warning,

  /// Exception capturada. App continua, mas algo errado aconteceu.
  error,

  /// Erro grave: provavelmente perdemos dados ou estado. Reservar para
  /// situações onde queremos prioridade no rastreio.
  fatal,
}

/// Origem do evento. Útil pra filtrar em análise pós-mortem.
enum CrashSource {
  /// `FlutterError.onError` — erros do framework durante build/layout/paint.
  flutter,

  /// `PlatformDispatcher.instance.onError` — erros não capturados por zonas
  /// dentro do isolate raiz.
  platform,

  /// `runZonedGuarded` — erros que escaparam de tudo.
  zone,

  /// Disparado manualmente por código de domínio (ex: regra de negócio
  /// detectou inconsistência mas escolheu continuar).
  domain,

  /// Health-check de boot.
  health,

  /// Sinais de lifecycle (paused / detached etc).
  lifecycle,
}

/// Um evento imutável capturado pelo sistema de resiliência. Serializável
/// como JSON Lines para append em arquivo de log.
class CrashRecord {
  final DateTime timestamp;
  final CrashSeverity severity;
  final CrashSource source;

  /// Mensagem curta e descritiva. Não inclui stack — a stack vai em
  /// [stackTrace] separado.
  final String message;

  /// String do stack trace. Mantemos como String em vez de [StackTrace]
  /// porque o sink final é texto plano (arquivo).
  final String? stackTrace;

  /// Contexto adicional estruturado. Vai como objeto JSON no log.
  /// Exemplos: `{'session_id': 'abc', 'atendimento_ordem': 12}`.
  final Map<String, Object?> context;

  /// Versão do app no momento da captura. Útil quando o operador
  /// reporta "crashou ontem" e queremos saber qual build estava rodando.
  final String? appVersion;

  CrashRecord({
    required this.timestamp,
    required this.severity,
    required this.source,
    required this.message,
    this.stackTrace,
    this.context = const {},
    this.appVersion,
  });

  /// Serializa em uma única linha JSON. Append-safe e fácil de fazer
  /// `tail -f | jq` em campo.
  String toJsonLine() {
    final map = <String, Object?>{
      'ts': timestamp.toUtc().toIso8601String(),
      'lvl': severity.name,
      'src': source.name,
      'msg': message,
      if (stackTrace != null) 'stack': stackTrace,
      if (context.isNotEmpty) 'ctx': context,
      if (appVersion != null) 'ver': appVersion,
    };
    return jsonEncode(map);
  }
}
