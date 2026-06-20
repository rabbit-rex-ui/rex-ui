import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:rabbit_pdv/core/auth/lock_controller.dart';
import 'package:rabbit_pdv/core/theme/app_theme.dart';
import 'package:rabbit_pdv/features/auth/presentation/lock_overlay.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/ui_controllers.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Modular.get<ThemeController>();
    final lock = Modular.get<LockController>();
    return ListenableBuilder(
      listenable: theme,
      builder: (_, __) {
        return MaterialApp.router(
          title: 'Rabbit PDV',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(dark: false),
          darkTheme: buildTheme(dark: true),
          themeMode: theme.dark ? ThemeMode.dark : ThemeMode.light,
          routerConfig: Modular.routerConfig,
          builder: (context, child) {
            return ListenableBuilder(
              listenable: lock,
              builder: (_, __) => Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  if (lock.locked) const Positioned.fill(child: LockOverlay()),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
