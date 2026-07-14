import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('deriveTurnSeed', () {
    const profile = RulesetProfile.v0_1_0;

    test('produces identical seed for identical stable inputs', () {
      final a = deriveTurnSeed(
        caseId: 'case-1',
        turnIndex: 3,
        actionName: 'open_question',
        rootSeed: 42,
        profile: profile,
      );
      final b = deriveTurnSeed(
        caseId: 'case-1',
        turnIndex: 3,
        actionName: 'open_question',
        rootSeed: 42,
        profile: profile,
      );
      expect(a, equals(b));
    });

    test('differs when any stable input changes', () {
      final base = deriveTurnSeed(
        caseId: 'case-1',
        turnIndex: 3,
        actionName: 'open_question',
        rootSeed: 42,
        profile: profile,
      );
      expect(
        deriveTurnSeed(
          caseId: 'case-2',
          turnIndex: 3,
          actionName: 'open_question',
          rootSeed: 42,
          profile: profile,
        ),
        isNot(equals(base)),
      );
      expect(
        deriveTurnSeed(
          caseId: 'case-1',
          turnIndex: 4,
          actionName: 'open_question',
          rootSeed: 42,
          profile: profile,
        ),
        isNot(equals(base)),
      );
      expect(
        deriveTurnSeed(
          caseId: 'case-1',
          turnIndex: 3,
          actionName: 'validate',
          rootSeed: 42,
          profile: profile,
        ),
        isNot(equals(base)),
      );
      expect(
        deriveTurnSeed(
          caseId: 'case-1',
          turnIndex: 3,
          actionName: 'open_question',
          rootSeed: 43,
          profile: profile,
        ),
        isNot(equals(base)),
      );
    });
  });
}
