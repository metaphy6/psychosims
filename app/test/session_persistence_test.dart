import 'dart:async';
import 'dart:io';
import 'dart:convert';

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
        state: core.SimState(seed: 42, trustScore: 30),
        conversationWindow: [
          core.ConversationTurn(role: 'user', text: 'hello'),
        ],
        deltaLog: [
          StructuredDelta(
            rulesetVersion: '0.1.0',
            axis: StateAxis.trust,
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
      expect(loaded.state.trustScore, 30);
      expect(loaded.conversationWindow, isEmpty);
      expect(
          await File(p.join(dir.path, 'session_checkpoint.json'))
              .readAsString(),
          isNot(contains('hello')));
      expect(checkpoint.toJson(), isNot(contains('conversation_window')));
      expect(loaded.deltaLog.first.axis, StateAxis.trust);
    });

    test('loading legacy checkpoints removes durable transcript fields',
        () async {
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, 'session_checkpoint.json'));
      final payload = const SessionCheckpoint(
        correlationId: 'legacy',
        manifestId: 'case',
        state: core.SimState(seed: 1),
        conversationWindow: [],
        deltaLog: [],
        version: 1,
      ).toJson();
      payload['conversation_window'] = [
        {'role': 'assistant', 'text': 'sensitive old response'},
      ];
      await file.writeAsString(jsonEncode(payload));
      expect((await service.load())!.conversationWindow, isEmpty);
      expect(
          await file.readAsString(), isNot(contains('sensitive old response')));
    });

    test('returns null when no checkpoint exists', () async {
      final loaded = await service.load();
      expect(loaded, isNull);
    });

    SessionCheckpoint snapshot(String id) => SessionCheckpoint(
          correlationId: id,
          manifestId: 'case',
          state: const core.SimState(seed: 1),
          conversationWindow: const [],
          deltaLog: const [],
        );

    test('concurrent saves across service instances acknowledge in order',
        () async {
      final other = SessionPersistenceService(directory: dir);
      final acknowledged = <int>[];
      await Future.wait(List.generate(8, (index) async {
        await (index.isEven ? service : other).save(snapshot('session-$index'));
        acknowledged.add(index);
      }));
      expect(acknowledged, List.generate(8, (index) => index));
      expect((await service.load())!.correlationId, 'session-7');
      expect(await dir.list().length, 1);
    });

    test('load and clear observe preceding saves across service instances',
        () async {
      final other = SessionPersistenceService(directory: dir);
      final saved = service.save(snapshot('first'));
      final loaded = other.load();
      final cleared = service.clear();
      final afterClear = other.load();
      final replacement = other.save(snapshot('replacement'));
      await saved;
      expect((await loaded)?.correlationId, 'first');
      await cleared;
      expect(await afterClear, isNull);
      await replacement;
      expect((await service.load())!.correlationId, 'replacement');
    });

    test('retirement during a write preserves the previous checkpoint',
        () async {
      await service.save(snapshot('previous'));
      var active = true;
      final pending =
          service.save(snapshot('retired'), canCommit: () => active);
      scheduleMicrotask(() => active = false);
      await pending;
      expect((await service.load())!.correlationId, 'previous');
      expect(await dir.list().length, 1);
    });

    test('failed operation reports its error and does not poison the queue',
        () async {
      await File(dir.path).writeAsString('not a directory');
      await expectLater(service.save(snapshot('failed')),
          throwsA(isA<FileSystemException>()));
      await File(dir.path).delete();
      await service.save(snapshot('recovered'));
      expect((await service.load())!.correlationId, 'recovered');
    });

    test('clears a checkpoint', () async {
      const checkpoint = SessionCheckpoint(
        correlationId: 'corr-2',
        manifestId: 'manifest-2',
        state: core.SimState(seed: 1),
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
        state: core.SimState(seed: 3),
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
