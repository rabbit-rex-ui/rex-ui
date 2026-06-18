import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo de visualização do painel central.
enum ItemsView { carrinho, atalhos }

/// Controla o toggle Carrinho/Atalhos. Não acopla ao SessionsController
/// — esse estado é por **operador**, não por **atendimento**.
class ViewController extends ValueNotifier<ItemsView> {
  ViewController() : super(ItemsView.carrinho);

  void setView(ItemsView v) => value = v;

  String? _categoriaSelecionada;
  String? get categoriaSelecionada => _categoriaSelecionada;

  /// Preserva a categoria escolhida mesmo se o operador alterna para
  /// Carrinho e volta — vide checklist no doc.
  void setCategoria(String? c) {
    _categoriaSelecionada = c;
    notifyListeners();
  }
}

/// Relógio HH:mm:ss da topbar. Tick a cada 1s. Encapsula o Timer.
///
/// Por que separar? Para que rebuild do relógio **não** rebuilde o
/// resto da topbar (só o widget do relógio escuta).
class ClockController extends ChangeNotifier {
  ClockController() {
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _now = DateTime.now();
      notifyListeners();
    });
  }

  late DateTime _now;
  late final Timer _timer;

  DateTime get now => _now;

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

/// Controla a preferência de tema. Persiste em SharedPreferences.
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    _dark = _prefs.getBool(_key) ?? false;
  }

  static const _key = 'theme.dark';
  final SharedPreferences _prefs;
  late bool _dark;

  bool get dark => _dark;

  void toggle() {
    _dark = !_dark;
    _prefs.setBool(_key, _dark);
    notifyListeners();
  }

  void setDark(bool v) {
    if (_dark == v) return;
    _dark = v;
    _prefs.setBool(_key, _dark);
    notifyListeners();
  }
}

/// Estado da animação de flash do scanner (verde para sucesso,
/// vermelho para erro).
enum ScannerFlash { none, success, error }

/// Controla o input do scanner, busca debounced e flash de feedback.
class ScannerController extends ChangeNotifier {
  ScannerController();

  String _query = '';
  String get query => _query;

  ScannerFlash _flash = ScannerFlash.none;
  ScannerFlash get flash => _flash;

  Timer? _flashTimer;

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  void clear() {
    _query = '';
    notifyListeners();
  }

  void flashSuccess() {
    _flash = ScannerFlash.success;
    notifyListeners();
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 500), () {
      _flash = ScannerFlash.none;
      notifyListeners();
    });
  }

  void flashError() {
    _flash = ScannerFlash.error;
    notifyListeners();
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 500), () {
      _flash = ScannerFlash.none;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }
}
