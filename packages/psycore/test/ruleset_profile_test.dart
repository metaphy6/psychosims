import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('RulesetProfile', () {
    test('resolves the active 0.1.0 profile', () {
      final profile = RulesetProfile.forVersion('0.1.0');
      expect(profile.rulesetVersion, equals('0.1.0'));
      expect(profile.splitMixGamma, equals(0x9e3779b97f4a7c15));
      expect(profile.splitMixMul0, equals(0xbf58476d1ce4e5b9));
      expect(profile.splitMixMul1, equals(0x94d049bb133111eb));
    });

    test('resolves the PoC compatibility profile', () {
      final profile = RulesetProfile.forVersion('poc-1.0.0');
      expect(profile.rulesetVersion, equals('poc-1.0.0'));
      // Same constants as v0.1.0 for replay compatibility.
      expect(
          profile.splitMixGamma, equals(RulesetProfile.v0_1_0.splitMixGamma));
    });

    test('rejects unknown ruleset versions', () {
      expect(
        () => RulesetProfile.forVersion('9.9.9'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('supports lookup answers false for unknown version', () {
      expect(RulesetProfile.supports('0.1.0'), isTrue);
      expect(RulesetProfile.supports('9.9.9'), isFalse);
    });
  });
}
