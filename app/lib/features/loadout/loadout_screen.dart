import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psychemas/psychemas.dart';

import '../../app/app_routes.dart';
import '../../shared/l10n.dart';
import 'loadout_controller.dart';

/// Pre-session clinical preparation screen: curate the active loadout.
class LoadoutScreen extends StatelessWidget {
  const LoadoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LoadoutController>();
    return Scaffold(
      appBar: AppBar(title: const Text(L10n.loadoutTitle)),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final owned = controller.ownedCardIds;
        final manifest = controller.manifest;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (manifest != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manifest.id,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(L10n.loadoutStyle(manifest.styleArchetype.name)),
                    Text(L10n.loadoutInitialState(
                        manifest.initialState.toString())),
                    const Divider(),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                L10n.loadoutActiveCards(
                  controller.activeCardIds.length,
                  controller.slotCap,
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (controller.errorMessage.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  controller.errorMessage.value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            if (controller.gapReport?.hasGap ?? false)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  L10n.loadoutMissingTactics(
                    controller.gapReport!.missingSignatures
                        .map((s) => s.name)
                        .toList(),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Expanded(
              child: Semantics(
                label: L10n.loadoutOwnedCardsSemanticLabel,
                child: ListView.builder(
                  itemCount: owned.length,
                  itemBuilder: (context, index) {
                    final cardId = owned[index];
                    final equipped = controller.isEquipped(cardId);
                    return ListTile(
                      title: Text(cardId),
                      subtitle: Text(
                          equipped ? L10n.loadoutEquipped : L10n.loadoutOwned),
                      trailing: equipped
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle),
                              onPressed: () => controller.unequip(cardId),
                              tooltip: '${L10n.loadoutRemoveTooltip} $cardId',
                            )
                          : IconButton(
                              icon: const Icon(Icons.add_circle),
                              onPressed: controller.canEquip(cardId)
                                  ? () => controller.equip(cardId)
                                  : null,
                              tooltip: '${L10n.loadoutAddTooltip} $cardId',
                            ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(L10n.loadoutFocusLabel),
                  Obx(() => SegmentedButton<FocusAxis>(
                        segments: const [
                          ButtonSegment(
                              value: FocusAxis.childhood,
                              label: Text(L10n.loadoutFocusChildhood)),
                          ButtonSegment(
                              value: FocusAxis.balanced,
                              label: Text(L10n.loadoutFocusBalanced)),
                          ButtonSegment(
                              value: FocusAxis.workspace,
                              label: Text(L10n.loadoutFocusWorkspace)),
                        ],
                        selected: {controller.focus.value},
                        onSelectionChanged: (selected) =>
                            controller.focus.value = selected.first,
                      )),
                  const SizedBox(height: 16),
                  const Text(L10n.loadoutEmotionalDeliveryLabel),
                  Obx(() => SegmentedButton<EmotionalDelivery>(
                        segments: const [
                          ButtonSegment(
                              value: EmotionalDelivery.warm,
                              label: Text(L10n.loadoutDeliveryWarm)),
                          ButtonSegment(
                              value: EmotionalDelivery.balanced,
                              label: Text(L10n.loadoutDeliveryBalanced)),
                          ButtonSegment(
                              value: EmotionalDelivery.objective,
                              label: Text(L10n.loadoutDeliveryObjective)),
                        ],
                        selected: {controller.emotionalDelivery.value},
                        onSelectionChanged: (selected) =>
                            controller.emotionalDelivery.value = selected.first,
                      )),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: controller.isWithinCap
                    ? () => Get.toNamed(
                          AppRoutes.session,
                          arguments: {
                            'loadout': controller.toLoadout(),
                            'library': controller.toLibrary(),
                            'controllers': controller.toControllerSettings(),
                          },
                        )
                    : null,
                child: const Text(L10n.loadoutStartSession),
              ),
            ),
          ],
        );
      }),
    );
  }
}
