import 'package:psyconfig/psyconfig.dart';
import 'package:test/test.dart';

void main() {
  test('ProgressionConfig exposes default economy constants', () {
    const config = ProgressionConfig();
    expect(config.baseXpPerSession, greaterThan(0));
    expect(config.currencyTypes, contains('xp'));
    expect(config.attractionWeights.reputationWeight, greaterThan(0));
  });

  test('effective config carries progression through copies and safe output',
      () {
    final base = loadConfig(environment: 'test');
    expect(base.progression.baseXpPerSession, 100);
    const progression = ProgressionConfig(baseXpPerSession: 73);
    final configured = base.copyWith(progression: progression);
    expect(configured.copyWith(schemaVersion: 'test').progression,
        same(progression));
    expect(
        (safeConfig(configured)['progression'] as Map)['baseXpPerSession'], 73);
  });
}
