import 'package:flutter_modular/flutter_modular.dart';
import 'package:rabbit_pdv/core/config/env.dart';
import 'package:rabbit_pdv/core/core_module.dart';
import 'package:rabbit_pdv/features/auth/domain/auth_repository.dart';
import 'package:rabbit_pdv/features/auth/presentation/login_controller.dart';
import 'package:rabbit_pdv/features/auth/presentation/login_page.dart';
import 'package:rabbit_pdv/features/auth/presentation/trocar_senha_controller.dart';
import 'package:rabbit_pdv/features/auth/presentation/trocar_senha_page.dart';
import 'package:rabbit_pdv/features/pdv/guards/auth_guard.dart';
import 'package:rabbit_pdv/features/pdv/pdv_module.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/ui_controllers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppModule extends Module {
  AppModule(this._prefs);

  final SharedPreferences _prefs;

  @override
  List<Module> get imports => [CoreModule()];

  @override
  void binds(Injector i) {
    i.addInstance<SharedPreferences>(_prefs);

    i.addSingleton<ThemeController>(
      () => ThemeController(i.get<SharedPreferences>()),
    );
    i.addSingleton<ClockController>(ClockController.new);

    // LoginController resolve AuthRepository via CoreModule.
    i.addSingleton<LoginController>(
      () => LoginController(i.get<AuthRepository>(), tenantId: Env.tenantId),
    );
    i.addSingleton<TrocarSenhaController>(
      () => TrocarSenhaController(i.get<AuthRepository>()),
    );
  }

  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const LoginPage());
    r.child(
      '/trocar-senha/',
      child: (_) => const TrocarSenhaPage(),
      guards: [AuthGuard()], // precisa de token (login já o salvou)
    );
    r.module('/pdv', module: PdvModule());
  }
}
