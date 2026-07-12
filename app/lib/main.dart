import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/app_routes.dart';
import 'features/session/session_bindings.dart';
import 'features/session/session_screen.dart';
import 'screens/home_screen.dart';
import 'shared/injection.dart';
import 'shared/l10n.dart';

void main() {
  runApp(const PsychosimsApp());
}

class PsychosimsApp extends StatelessWidget {
  const PsychosimsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: L10n.appTitle,
      initialBinding: AppBindings(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.home,
      getPages: [
        GetPage(
          name: AppRoutes.home,
          page: () => const HomeScreen(),
        ),
        GetPage(
          name: AppRoutes.session,
          page: () => const SessionScreen(),
          binding: SessionBindings(),
        ),
      ],
    );
  }
}
