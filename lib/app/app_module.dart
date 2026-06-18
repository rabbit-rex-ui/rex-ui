import 'package:flutter_modular/flutter_modular.dart';
import 'package:rabbit_pdv/features/pdv/pdv_module.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/ui_controllers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppModule extends Module {
  AppModule(this._prefs);

  final SharedPreferences _prefs;

  @override
  void binds(Injector i) {
    i.addInstance<SharedPreferences>(_prefs);

    i.addSingleton<ThemeController>(
      () => ThemeController(i.get<SharedPreferences>()),
    );
    i.addSingleton<ClockController>(ClockController.new);
  }

  @override
  void routes(RouteManager r) {
    r.module('/', module: PdvModule());
  }
}
