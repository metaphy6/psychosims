import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psychosims/features/loadout/loadout_controller.dart';
import 'package:psychosims/shared/logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    Get.put<Config>(loadConfig(environment: 'test'));
    Get.put<PsyLog>(PsyLog(minLevel: LogLevel.warn));
  });

  tearDown(Get.reset);

  test('enforces active slot cap from config', () {
    final controller = LoadoutController(
      config: Get.find<Config>(),
      logger: Get.find<PsyLog>(),
      ownedCardIds: const ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
    );
    final cap = controller.slotCap;
    expect(controller.isWithinCap, isTrue);
    for (var i = 0; i < cap; i++) {
      controller.equip(controller.ownedCardIds[i]);
    }
    expect(controller.activeCardIds.length, equals(cap));
    controller.equip(controller.ownedCardIds[cap]);
    expect(controller.activeCardIds.length, equals(cap));
    expect(controller.errorMessage.value, isNotEmpty);
  });

  test('produces a valid Loadout and CardLibrary', () {
    final controller = LoadoutController(
      config: Get.find<Config>(),
      logger: Get.find<PsyLog>(),
      ownedCardIds: const ['a', 'b', 'c'],
      initialActiveIds: const ['a', 'c'],
    );
    final loadout = controller.toLoadout();
    final library = controller.toLibrary();
    expect(loadout.cardIds, equals(const ['a', 'c']));
    expect(loadout.isValidForLibrary(library.ownedCardIds), isTrue);
  });
}
