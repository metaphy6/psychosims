import 'package:psychemas/psychemas.dart';
import 'package:test/test.dart';

void main() {
  group('PatientManifest', () {
    test('round-trips through JSON', () {
      const manifest = PatientManifest(
        id: 'p-001',
        rulesetVersion: '0.1.0',
        nameKey: 'manifests.p001.name',
        presentationKey: 'manifests.p001.presentation',
      );
      final json = manifest.toJson();
      final restored = PatientManifest.fromJson(json);
      expect(restored, equals(manifest));
    });
  });
}
