import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/app_routes.dart';
import '../shared/l10n.dart';

/// Placeholder home screen for the PoC session loop.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(L10n.appTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => Get.toNamed(AppRoutes.session),
              child: const Text(L10n.homeStartPocSession),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Get.toNamed(AppRoutes.modelFetch),
              child: const Text(L10n.homeFetchModel),
            ),
          ],
        ),
      ),
    );
  }
}
