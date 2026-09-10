import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:psyconfig/psyconfig.dart';

import '../../shared/logger.dart';
import '../../shared/l10n.dart';

/// Controller for the pre-session clinical preparation / loadout curation
/// screen.
///
/// Enforces the active-slot cap from config and exposes only owned cards as
/// equippable. The curated [Loadout] is passed to the session flow.
class LoadoutController extends GetxController {
  LoadoutController({
    required this.config,
    required this.logger,
    this.manifest,
    List<String> ownedCardIds = const [],
    List<String>? initialActiveIds,
  }) {
    _owned.addAll(ownedCardIds);
    final active = initialActiveIds ?? ownedCardIds.toList();
    _active.assignAll(active.take(config.balance.activeCardSlots));
  }

  final Config config;
  final PsyLog logger;
  final PatientManifest? manifest;

  final _owned = <String>[].obs;
  final _active = <String>[].obs;
  final _actionable = <String>{};
  final errorMessage = ''.obs;
  final isLoading = true.obs;
  final focus = FocusAxis.balanced.obs;
  final emotionalDelivery = EmotionalDelivery.balanced.obs;

  List<String> get ownedCardIds => _owned.toList();
  List<String> get activeCardIds => _active.toList();
  int get slotCap => config.balance.activeCardSlots;
  bool get isWithinCap => _active.length <= slotCap;
  bool get canStartSession =>
      !isLoading.value &&
      _active.isNotEmpty &&
      isWithinCap &&
      _active.toSet().length == _active.length &&
      _active.every((id) => _owned.contains(id) && _actionable.contains(id));

  bool isEquipped(String cardId) => _active.contains(cardId);
  @override
  void onInit() {
    super.onInit();
    _loadManifest();
  }

  Future<void> _loadManifest() async {
    try {
      final path = config.content.bundledManifestPath;
      final bytes = await rootBundle.load(path);
      final data = bytes.buffer.asUint8List();
      final loader = ManifestLoader(
        limits: ManifestLoaderLimits(
          maxBytes: config.content.maxManifestBytes,
          maxMapDepth: config.content.maxManifestDepth,
        ),
        catalog: const L10n(),
      );
      final loaded = loader.load(data);
      _actionable
        ..clear()
        ..addAll(loaded.interactionPatterns
            .map((action) => cardFromInteractionPattern(action).id));
      final resolvedCardIds = loaded.resolvedCards.map((c) => c.id).toList();
      _owned.assignAll(resolvedCardIds);
      if (_active.isEmpty) {
        _active.assignAll(resolvedCardIds.take(slotCap));
      }
      isLoading.value = false;
      logger.info('loadout', 'manifest_loaded', kv: {'case_id': loaded.id});
    } on Exception catch (e, st) {
      isLoading.value = false;
      errorMessage.value = 'loadout.error.load_failed';
      logger.error('loadout', 'manifest_load_failed',
          errorKind: ErrorKind.system, message: '$e\n$st');
    }
  }

  bool canEquip(String cardId) {
    return _owned.contains(cardId) &&
        !_active.contains(cardId) &&
        _active.length < slotCap;
  }

  void equip(String cardId) {
    if (!canEquip(cardId)) {
      errorMessage.value = 'loadout.error.slot_cap_reached';
      logger.warn('loadout', 'equip_rejected',
          kv: {'card_id': cardId, 'reason': 'slot_cap_reached'});
      return;
    }
    _active.add(cardId);
    errorMessage.value = '';
    logger.info('loadout', 'equipped', kv: {'card_id': cardId});
  }

  void unequip(String cardId) {
    _active.remove(cardId);
    errorMessage.value = '';
    logger.info('loadout', 'unequipped', kv: {'card_id': cardId});
  }

  Loadout toLoadout() {
    return Loadout(cardIds: _active.toList(), slotCap: slotCap);
  }

  CardLibrary toLibrary() {
    return CardLibrary(ownedCardIds: _owned.toSet());
  }

  TherapyControllerSettings toControllerSettings() {
    return TherapyControllerSettings(
      focus: focus.value,
      emotionalDelivery: emotionalDelivery.value,
    );
  }

  LoadoutGapReport? get gapReport {
    final m = manifest;
    if (m == null) return null;
    return const LoadoutAnalyzer().analyze(m, toLoadout());
  }
}
