/// Formata datas e horas no padrão brasileiro (fuso local do terminal).
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

  /// `dd/MM/yyyy HH:mm`. Ex.: carimbos de eventos e de notas fiscais.
  static String dataHora(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year} ${hm(dt)}';
  }
}
