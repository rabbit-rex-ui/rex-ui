import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:rabbit_pdv/core/resilience/crash_record.dart';
import 'package:rabbit_pdv/core/resilience/sinks/error_sink.dart';

/// Persiste eventos em arquivos `crash-YYYY-MM-DD.log` (JSON Lines)
/// dentro de `<applicationSupportDirectory>/logs/`.
///
/// Princípios:
/// - **Fail-safe**: qualquer falha do sistema de arquivos é engolida.
///   Logar erros do logger criaria loops.
/// - **Append-only**: cada linha é independente; um crash a meio de
///   uma escrita não corrompe linhas anteriores.
/// - **Rotação por dia**: simples e legível. Sem rotação por tamanho
///   no MVP (PDV típico < 1 MB/dia de log).
/// - **Retenção**: mantém últimos N dias. Apaga o resto no boot.
/// - **Fila in-memory**: emit() é síncrono pra não bloquear caller.
///   Um isolate-loop drena a fila pro disco.
class FileErrorSink implements ErrorSink {
  FileErrorSink({this.retentionDays = 14, this.subdir = 'logs'});

  final int retentionDays;
  final String subdir;

  /// Buffer FIFO de registros aguardando flush. Limite: 1000 entradas.
  /// Se estourar (algo muito errado, loop de exceções), descarta o mais
  /// antigo — preserva o estado mais recente que é o que importa.
  final Queue<String> _queue = Queue<String>();
  static const _maxQueue = 1000;

  Directory? _dir;
  IOSink? _sink;
  String? _currentDayKey;

  Timer? _flushTimer;
  bool _flushing = false;
  bool _disposed = false;

  @override
  String get name => 'file';

  @override
  Future<void> init() async {
    try {
      final base = await getApplicationSupportDirectory();
      _dir = Directory('${base.path}${Platform.pathSeparator}$subdir');
      if (!await _dir!.exists()) {
        await _dir!.create(recursive: true);
      }
      await _cleanupOldFiles();
      await _rotateIfNeeded();

      // Drena a fila periodicamente. Intervalo curto pra latência baixa
      // sem comer CPU.
      _flushTimer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => unawaited(_drain()),
      );
    } catch (_) {
      // Disco/permissão indisponível: degrada pra "só console".
      // Não logamos isso pelo próprio sistema (evitar loop).
      _dir = null;
      _sink = null;
    }
  }

  @override
  void emit(CrashRecord record) {
    if (_disposed) return;
    if (_queue.length >= _maxQueue) {
      _queue.removeFirst(); // descarta o mais antigo
    }
    _queue.add(record.toJsonLine());
    // Best-effort flush imediato; se já está rodando, o timer cuida.
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_flushing || _disposed) return;
    if (_queue.isEmpty) return;
    if (_dir == null) {
      // Sem disco; descarta silenciosamente. Console sink já recebeu.
      _queue.clear();
      return;
    }
    _flushing = true;
    try {
      await _rotateIfNeeded();
      final sink = _sink;
      if (sink == null) {
        _queue.clear();
        return;
      }
      // Drena tudo que está na fila no momento (snapshot).
      while (_queue.isNotEmpty) {
        final line = _queue.removeFirst();
        sink.writeln(line);
      }
      await sink.flush();
    } catch (_) {
      // Engole. Próxima tentativa tentará de novo.
    } finally {
      _flushing = false;
    }
  }

  Future<void> _rotateIfNeeded() async {
    if (_dir == null) return;
    final today = DateTime.now();
    final key =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (key == _currentDayKey && _sink != null) return;

    // Fecha o anterior.
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}

    final file = File(
      '${_dir!.path}${Platform.pathSeparator}crash-$key.log',
    );
    try {
      _sink = file.openWrite(mode: FileMode.append, encoding: const SystemEncoding());
      _currentDayKey = key;
    } catch (_) {
      _sink = null;
    }
  }

  Future<void> _cleanupOldFiles() async {
    if (_dir == null) return;
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    try {
      await for (final entity in _dir!.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('crash-') || !name.endsWith('.log')) continue;
        try {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (_) {
          // Arquivo desaparecido ou permissão — ignora.
        }
      }
    } catch (_) {
      // Pasta não acessível — ignora.
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _flushTimer?.cancel();
    await _drain();
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
    _sink = null;
  }

  /// Caminho do arquivo do dia corrente. Útil pra exibir "Logs em: ..."
  /// num diálogo de diagnóstico. Retorna `null` se o sink degradou.
  String? get currentFilePath {
    if (_dir == null || _currentDayKey == null) return null;
    return '${_dir!.path}${Platform.pathSeparator}crash-$_currentDayKey.log';
  }

  /// Força flush imediato do que estiver na fila. Usado pelo
  /// `LifecycleMonitor` em `AppLifecycleState.detached` (última chance
  /// antes do app morrer) e em `paused` (operador travou o Windows).
  ///
  /// Best-effort: timeout de 500ms pra não bloquear o shutdown.
  Future<void> flushNow() async {
    try {
      await _drain().timeout(const Duration(milliseconds: 500));
    } catch (_) {
      // Timeout ou erro de IO — engole.
    }
  }
}
