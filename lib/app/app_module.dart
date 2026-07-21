import 'package:flutter_modular/flutter_modular.dart';
import 'package:rabbit_pdv/core/auth/trusted_device_store.dart';
import 'package:rabbit_pdv/core/core_module.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';
import 'package:rabbit_pdv/core/security/terminal_context_store.dart';
import 'package:rabbit_pdv/core/security/terminal_key_store.dart';
import 'package:rabbit_pdv/features/auth/domain/auth_repository.dart';
import 'package:rabbit_pdv/features/auth/presentation/login_controller.dart';
import 'package:rabbit_pdv/features/auth/presentation/login_page.dart';
import 'package:rabbit_pdv/features/auth/presentation/trocar_senha_controller.dart';
import 'package:rabbit_pdv/features/auth/presentation/trocar_senha_page.dart';
import 'package:rabbit_pdv/features/pdv/guards/auth_guard.dart';
import 'package:rabbit_pdv/features/pdv/pdv_module.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/ui_controllers.dart';
import 'package:rabbit_pdv/features/provisionamento/data/caixa_fisico_repository.dart';
import 'package:rabbit_pdv/features/provisionamento/data/device_activation_repository.dart';
import 'package:rabbit_pdv/features/provisionamento/data/device_enrollment_repository.dart';
import 'package:rabbit_pdv/features/provisionamento/data/trusted_device_repository.dart';
import 'package:rabbit_pdv/features/provisionamento/presentation/ativar_terminal_controller.dart';
import 'package:rabbit_pdv/features/provisionamento/presentation/ativar_terminal_page.dart';
import 'package:rabbit_pdv/features/provisionamento/presentation/provisionar_terminal_controller.dart';
import 'package:rabbit_pdv/features/provisionamento/presentation/provisionar_terminal_page.dart';
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
      () => LoginController(i.get<AuthRepository>()),
    );
    i.addSingleton<TrocarSenhaController>(
      () => TrocarSenhaController(i.get<AuthRepository>()),
    );
    i.addSingleton<DeviceEnrollmentRepository>(
      () => DeviceEnrollmentRepositoryImpl(i.get<ApiClient>()),
    );
    i.addSingleton<TrustedDeviceRepository>(
      () => TrustedDeviceRepositoryImpl(
        i.get<ApiClient>(),
        i.get<TrustedDeviceStore>(),
        i.get<TokenStore>(),
      ),
    );
    i.add<ProvisionarTerminalController>(
      () => ProvisionarTerminalController(
        i.get<TrustedDeviceRepository>(),
        i.get<CaixaFisicoRepository>(),
        i.get<DeviceEnrollmentRepository>(),
      ),
    );
    i.addSingleton<DeviceActivationRepository>(
      () => DeviceActivationRepositoryImpl(i.get<ApiClient>()),
    );
    i.add<AtivarTerminalController>(
      () => AtivarTerminalController(
        i.get<DeviceActivationRepository>(),
        i.get<TerminalKeyStore>(),
        i.get<TerminalContextStore>(),
      ),
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
    r.child(
      '/provisionar-terminal/',
      child: (_) => const ProvisionarTerminalPage(),
    );
    r.child('/ativar-terminal/', child: (_) => const AtivarTerminalPage());
  }
}
