import 'package:psyconfig/psyconfig.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  test(
      'config adapter preserves the trust threshold unit and binds slot/freeze settings',
      () {
    final config = loadConfig(environment: 'test');
    final balance = CardBalance.fromConfig(config.balance);
    expect(balance.activeCardSlots, config.balance.activeCardSlots);
    expect(balance.postponingFreezeTurns, config.balance.postponingFreezeTurns);
    // The small per-card trust increment is not a patient trust threshold.
    expect(balance.fitBufferTrust, const CardBalance().fitBufferTrust);
    expect(balance.fitBufferTrust,
        greaterThan(config.balance.relatableTrustBumpMax));
  });
}
