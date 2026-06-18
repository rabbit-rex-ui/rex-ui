/// Formata hora no padrão `HH:mm:ss`. Usado no relógio da topbar.
class TimeFormatter {
  TimeFormatter._();

  static String hms(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// `HH:mm` sem segundos. Útil em ticks menos críticos.
  static String hm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
