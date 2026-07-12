import 'package:psyconfig/psyconfig.dart';
import 'package:test/test.dart';

void main() {
  group('safeConfig', () {
    test('redacts secret references', () {
      final cfg = loadConfig(environment: 'test');
      final safe = safeConfig(cfg);
      final secretRef =
          (safe['secretsRefs'] as Map<String, Object?>)['apiKeyRef'] as String;
      expect(secretRef, contains('***'));
    });

    test('emits every non-secret group', () {
      final cfg = loadConfig(environment: 'test');
      final safe = safeConfig(cfg);
      expect(safe.keys, contains('network'));
      expect(safe.keys, contains('model'));
      expect(safe.keys, contains('balance'));
      expect(safe.keys, contains('featureFlags'));
    });
  });
}
