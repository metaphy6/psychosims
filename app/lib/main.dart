import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app_routes.dart';
import 'features/loadout/loadout_bindings.dart';
import 'features/loadout/loadout_screen.dart';
import 'features/model_fetch/model_fetch_bindings.dart';
import 'features/model_fetch/model_fetch_screen.dart';
import 'features/session/session_bindings.dart';
import 'features/session/session_screen.dart';
import 'screens/home_screen.dart';
import 'shared/injection.dart';
import 'shared/l10n.dart';
import 'shared/session_persistence.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDir = await getApplicationDocumentsDirectory();
  Get.put<SessionPersistenceService>(
    SessionPersistenceService(directory: appDir),
    permanent: true,
  );
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
        GetPage(
          name: AppRoutes.loadout,
          page: () => const LoadoutScreen(),
          binding: LoadoutBindings(),
        ),
        GetPage(
          name: AppRoutes.modelFetch,
          page: () => const ModelFetchScreen(),
          binding: ModelFetchBindings(),
        ),
      ],
    );
  }
}
