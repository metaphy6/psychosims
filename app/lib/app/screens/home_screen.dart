import 'package:flutter/material.dart';

import '../../shared/l10n.dart';

/// Blank home screen for the Phase 0 skeleton.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(L10n.appTitle),
      ),
    );
  }
}
