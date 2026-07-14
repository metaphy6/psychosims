import 'package:psyconfig/psyconfig.dart';
import 'package:test/test.dart';

void main() {
  test('ProgressionConfig exposes default economy constants', () {
    const config = ProgressionConfig();
    expect(config.baseXpPerSession, greaterThan(0));
    expect(config.currencyTypes, contains('xp'));
    expect(config.attractionWeights.reputationWeight, greaterThan(0));
  });
}
