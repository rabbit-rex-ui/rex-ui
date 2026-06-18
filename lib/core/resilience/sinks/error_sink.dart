import 'package:rabbit_pdv/core/resilience/crash_record.dart';

/// Destino para registros de crash. Múltiplos sinks coexistem (console +
/// arquivo, no futuro outbox de telemetria).
///
/// Sinks devem ser **fail-safe**: nunca lançar exceção. Se o destino
/// próprio falha (disco cheio, permissão negada), engolir silenciosamente.
/// Erros no sistema de erros não podem cascatear.
abstract class ErrorSink {
  /// Identificador legível em logs internos.
  String get name;

  /// Inicializa recursos (abrir arquivo, criar pasta). Chamado uma única
  /// vez no boot. Idempotente.
  Future<void> init();

  /// Recebe um evento. Não bloqueia o caller — implementações pesadas
  /// (disco, rede) devem despachar pra background sem await.
  void emit(CrashRecord record);

  /// Fecha recursos. Raro de chamar em PDV (app vive enquanto a máquina
  /// vive), mas existe pra cleanup determinístico em testes.
  Future<void> dispose();
}
