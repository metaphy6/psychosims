import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart' as core;
import 'package:psychosims/shared/session_persistence.dart';

void main() {
  group('SessionPersistenceService', () {
    late Directory dir;
    late SessionPersistenceService service;

    setUp(() {
      dir = Directory(p.join(Directory.systemTemp.path,
          'psychosims_session_persistence_test_${DateTime.now().microsecondsSinceEpoch}'));
      service = SessionPersistenceService(directory: dir);
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('round-trips a checkpoint', () async {
      const checkpoint = SessionCheckpoint(
        correlationId: 'corr-1',
        manifestId: 'manifest-1',
        state: core.SimState(seed: 42, axes: {'trust': 30}),
        conversationWindow: [
          core.ConversationTurn(role: 'user', text: 'hello'),
        ],
        deltaLog: [
          StructuredDelta(
            rulesetVersion: '0.1.0',
            axis: 'trust',
            deltaMillis: 5,
            reasonKey: 'reason.open_question',
            cardType: CardType.disclosing,
            cardSignature: CardSignature.breaker,
            contextFit: ContextFit.aligned,
          ),
        ],
      );

      await service.save(checkpoint);
      final loaded = await service.load();

      expect(loaded, isNotNull);
      expect(loaded!.correlationId, 'corr-1');
      expect(loaded.manifestId, 'manifest-1');
      expect(loaded.state.seed, 42);
      expect(loaded.state.axes['trust'], 30);
      expect(loaded.conversationWindow.first.text, 'hello');
      expect(loaded.deltaLog.first.axis, 'trust');
    });

    test('returns null when no checkpoint exists', () async {
      final loaded = await service.load();
      expect(loaded, isNull);
    });

    test('clears a checkpoint', () async {
      const checkpoint = SessionCheckpoint(
        correlationId: 'corr-2',
        manifestId: 'manifest-2',
        state: core.SimState(seed: 1, axes: {}),
        conversationWindow: [],
        deltaLog: [],
      );
      await service.save(checkpoint);
      expect(await service.load(), isNotNull);
      await service.clear();
      expect(await service.load(), isNull);
    });

    test('atomic write leaves no partial file on corruption simulation',
        () async {
      const checkpoint = SessionCheckpoint(
        correlationId: 'corr-3',
        manifestId: 'manifest-3',
        state: core.SimState(seed: 3, axes: {}),
        conversationWindow: [],
        deltaLog: [],
      );
      await service.save(checkpoint);
      // Overwrite the checkpoint with invalid JSON.
      await File(p.join(dir.path, 'session_checkpoint.json'))
          .writeAsString('not json');
      expect(await service.load(), isNull);
    });
  });
}
