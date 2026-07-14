import 'package:psyconfig/psyconfig.dart';
import 'package:test/test.dart';

void main() {
  test('RecoveryConfig exposes default recovery constants', () {
    const config = RecoveryConfig();
    expect(config.discountPracticeXpMultiplierMillis, 500);
    expect(config.recoveryCooldownSeconds, greaterThan(0));
  });
}
