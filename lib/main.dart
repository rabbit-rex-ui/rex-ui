import 'package:flutter_modular/flutter_modular.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rabbit_pdv/app/app_module.dart';
import 'package:rabbit_pdv/app/app_widget.dart';
import 'package:rabbit_pdv/bootstrap.dart';

Future<void> main() => bootstrap(() async {
      // SharedPreferences pré-resolvido (síncrono dali em diante) e
      // injetado no AppModule. Roda dentro da zone guard do bootstrap —
      // qualquer falha aqui é capturada e logada.
      final prefs = await SharedPreferences.getInstance();
      return ModularApp(
        module: AppModule(prefs),
        child: const AppWidget(),
      );
    });
