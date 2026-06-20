import 'package:flutter_modular/flutter_modular.dart';
import 'package:rabbit_pdv/core/config/env.dart'; // ⚠️ confirme o caminho real do Env
import 'package:rabbit_pdv/features/auth/data/auth_repository_impl.dart';
import 'package:rabbit_pdv/features/auth/domain/auth_repository.dart';
import 'package:rabbit_pdv/features/auth/presentation/login_controller.dart';
import 'package:rabbit_pdv/features/auth/presentation/login_page.dart';

class AuthModule extends Module {
  @override
  void binds(Injector i) {
    i.addSingleton<AuthRepository>(AuthRepositoryImpl.new);
    i.add<LoginController>(
      (Injector i) =>
          LoginController(i<AuthRepository>(), tenantId: Env.tenantId),
    );
  }

  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const LoginPage());
  }
}
