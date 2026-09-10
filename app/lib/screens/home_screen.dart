import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psychemas/psychemas.dart';

import '../app/app_routes.dart';
import '../shared/career_persistence.dart';
import '../shared/l10n.dart';

/// Local practice entry point and durable career progress.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<CareerSave?> _career;

  @override
  void initState() {
    super.initState();
    _career = Get.find<CareerPersistenceService>().load();
  }

  Future<void> _navigate(String route) async {
    await Get.toNamed(route);
    if (mounted) {
      setState(() => _career = Get.find<CareerPersistenceService>().load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(L10n.appTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ElevatedButton(
            onPressed: () => _navigate(AppRoutes.loadout),
            child: const Text(L10n.homeStartPocSession),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _navigate(AppRoutes.modelFetch),
            child: const Text(L10n.homeFetchModel),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
              onPressed: () => _navigate(AppRoutes.online),
              child: const Text(L10n.onlineTitle)),
          const SizedBox(height: 24),
          FutureBuilder<CareerSave?>(
            future: _career,
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text(L10n.careerLoadError);
              final save = snapshot.data;
              if (save == null || save.completedSessions.isEmpty) {
                return const Text(L10n.careerEmpty);
              }
              int balance(CurrencyType currency) =>
                  (save.profile.snapshotBalancesMicros[currency.name] ?? 0) +
                  save.profile.eventTail
                      .where((e) => e.currency == currency)
                      .fold(0, (total, event) => total + event.amountMicros);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L10n.careerTitle,
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(L10n.careerSessions(save.completedSessions.length)),
                  Text(L10n.careerBalances(
                    xp: balance(CurrencyType.xp) ~/ 1000000,
                    study: balance(CurrencyType.study) ~/ 1000000,
                    cash: balance(CurrencyType.cash) ~/ 1000000,
                  )),
                  const SizedBox(height: 16),
                  for (final record in save.completedSessions.reversed.take(10))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(record.outcome == SessionOutcome.succeed
                          ? Icons.check_circle_outline
                          : Icons.history),
                      title: Text(record.outcome == SessionOutcome.succeed
                          ? L10n.sessionSuccess
                          : L10n.sessionFailure),
                      subtitle:
                          Text(L10n.careerTurns(record.receipt.turnCount)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
