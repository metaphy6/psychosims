import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:psychemas/psychemas.dart';
import 'package:psychosims/shared/career_persistence.dart';

void main() {
  group('CareerPersistenceService', () {
    late Directory dir;
    late CareerPersistenceService service;

    setUp(() async {
      dir = Directory(p.join(
        Directory.systemTemp.path,
        'psychosims_cerer_persistence_test_${DateTime.now().microsecondsSinceEpoch}',
      ));
      await dir.create(recursive: true);
      service = CareerPersistenceService(directory: dir);
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    CareerSave sampleSave() {
      return const CareerSave(
        profile: CareerProfile(
          profileId: 'profile-1',
          rulesetVersion: '0.5.0',
          snapshotBalancesMicros: {'cash': 12345000000},
          snapshotTimestampSeconds: 1000,
          eventTail: [
            LedgerEvent(
              kind: 'session_fee',
              idempotencyKey: 'ik-1',
              timestampSeconds: 100,
              currency: CurrencyType.cash,
              amountMicros: 5000000,
              reasonKey: 'reason.session_fee',
            ),
          ],
          unlockedFields: ['general_psychiatry'],
          isOnboarding: false,
        ),
        clinic: ClinicAsset(
          officeId: 'office-1',
          tier: 2,
          isOwned: true,
          monthlyRentMicros: 0,
        ),
        ownedCases: {
          'case-1': CaseHistoryEnvelope(
            carryOverDeltas: [
              const StructuredDelta(
                rulesetVersion: '0.5.0',
                axis: StateAxis.trust,
                deltaMillis: 5,
                reasonKey: 'reason.carry_over',
                cardType: CardType.disclosing,
                cardSignature: CardSignature.buffer,
                contextFit: ContextFit.aligned,
              ),
            ],
            inheritedMedication: MedicationState.empty(),
            derangements: [DerangementMutation.somaticFixation],
            collectedClues: ['clue-1'],
            priorSessionCount: 1,
          ),
        },
        receiptQueue: [
          SessionReceipt(
            id: 'receipt-1',
            rulesetVersion: '0.5.0',
            patientId: 'patient-1',
            idempotencyKey: 'receipt-ik-1',
            correlationId: 'corr-1',
            turnCount: 3,
            startState: {},
            actions: [InteractionPattern.openQuestion],
            deltas: [],
          ),
        ],
      );
    }

    test('round-trips a career save', () async {
      final save = sampleSave();
      await service.save(save);
      final loaded = await service.load();

      expect(loaded, isNotNull);
      expect(loaded!.profile.profileId, 'profile-1');
      expect(loaded.profile.rulesetVersion, '0.5.0');
      expect(loaded.profile.snapshotBalancesMicros['cash'], 12345000000);
      expect(loaded.clinic!.officeId, 'office-1');
      expect(loaded.clinic!.tier, 2);
      expect(loaded.ownedCases['case-1']!.priorSessionCount, 1);
      expect(loaded.ownedCases['case-1']!.collectedClues.first, 'clue-1');
      expect(loaded.receiptQueue.first.id, 'receipt-1');
    });

    test('returns null when no save exists', () async {
      expect(await service.load(), isNull);
    });

    test('loadOrCreate returns blank when no save exists', () async {
      final loaded = await service.loadOrCreate('new-id', '0.5.0');
      expect(loaded.profile.profileId, 'new-id');
      expect(loaded.profile.rulesetVersion, '0.5.0');
      expect(loaded.clinic, isNull);
      expect(loaded.ownedCases, isEmpty);
    });

    test('falls back to backup when main save is corrupt', () async {
      final save = sampleSave();
      await service.save(save);

      // Corrupt the main file; backup should still be valid.
      await File(p.join(dir.path, 'career_save.json'))
          .writeAsString('not-json');

      final loaded = await service.load();
      expect(loaded, isNotNull);
      expect(loaded!.profile.profileId, 'profile-1');
    });

    test('atomic write interruption at every offset leaves loadable backup',
        () async {
      final save = sampleSave();
      await service.save(save);

      final mainFile = File(p.join(dir.path, 'career_save.json'));
      final validBytes = await mainFile.readAsBytes();

      for (var cutAt = 0; cutAt < validBytes.length; cutAt++) {
        await mainFile.writeAsBytes(validBytes.sublist(0, cutAt), flush: true);
        final loaded = await service.load();
        expect(loaded, isNotNull,
            reason: 'load failed after truncating main to $cutAt bytes');
        expect(loaded!.profile.profileId, 'profile-1',
            reason: 'wrong profile after truncating main to $cutAt bytes');
      }
    });

    test('loads a v1 golden save', () async {
      // A hand-constructed v1 save with a known checksum. This is the golden
      // old-schema corpus entry: schema version 1 must migrate to current.
      const goldenEnvelope = <String, Object?>{
        'schema_version': 1,
        'ruleset_version': '0.5.0',
        'save': {
          'profile': {
            'profile_id': 'golden-profile',
            'ruleset_version': '0.5.0',
            'snapshot_balances_micros': <String, int>{},
            'snapshot_timestamp_seconds': 0,
            'event_tail': <Map<String, Object?>>[],
            'unlocked_fields': <String>[],
            'is_onboarding': true,
          },
          'clinic': null,
          'owned_cases': <String, Map<String, Object?>>{},
          'receipt_queue': <Map<String, Object?>>[],
        },
      };

      final temp = File(p.join(dir.path, 'golden.json'));
      await _writeEnvelope(temp, goldenEnvelope);

      final imported = await service.importSave(temp);
      expect(imported.profile.profileId, 'golden-profile');
    });

    test('rejects import with unsupported future schema', () async {
      final envelope = <String, Object?>{
        'schema_version': 999,
        'ruleset_version': '0.5.0',
        'save': sampleSave().toJson(),
      };
      final temp = File(p.join(dir.path, 'future.json'));
      await _writeEnvelope(temp, envelope);

      expect(
        () => service.importSave(temp),
        throwsA(isA<UnsupportedSchemaException>()),
      );
    });

    test('rejects import with bad checksum', () async {
      final envelope = <String, Object?>{
        'schema_version': 1,
        'ruleset_version': '0.5.0',
        'save': sampleSave().toJson(),
        'checksum': 'deadbeef',
      };
      final temp = File(p.join(dir.path, 'bad-checksum.json'));
      await temp.writeAsBytes(
        utf8.encode(CanonicalJson.encodeString(envelope)),
        flush: true,
      );

      expect(
        () => service.importSave(temp),
        throwsA(isA<CorruptSaveException>()),
      );
    });

    test('rejects oversized import', () async {
      final huge = List<String>.filled(
        CareerPersistenceService.maxImportBytes + 1,
        'x',
      );
      final temp = File(p.join(dir.path, 'huge.json'));
      await temp.writeAsString(huge.join(), flush: true);

      expect(
        () => service.importSave(temp),
        throwsA(isA<ImportBudgetException>()),
      );
    });

    test('rejects save containing a transcript key', () async {
      final save = sampleSave();
      await service.save(save);

      final mainFile = File(p.join(dir.path, 'career_save.json'));
      final text = await mainFile.readAsString();
      final json = jsonDecode(text) as Map<String, Object?>;

      // Inject a forbidden transcript key into the loaded envelope.
      json['transcript'] = 'raw model output';
      await mainFile.writeAsString(
        CanonicalJson.encodeString(json),
        flush: true,
      );

      expect(
        () => service.load(),
        throwsA(isA<TranscriptPersistenceException>()),
      );
    });

    test('receipt queue appends and drains idempotently', () async {
      const receipt = SessionReceipt(
        id: 'r1',
        rulesetVersion: '0.5.0',
        patientId: 'p1',
        idempotencyKey: 'ik-r1',
        correlationId: 'c1',
        turnCount: 1,
        startState: {},
        actions: [InteractionPattern.validate],
        deltas: [],
      );

      await service.appendReceipt(receipt);
      await service.appendReceipt(receipt); // duplicate append

      final drained = await service.drainReceiptQueue();
      expect(drained.length, 1);
      expect(drained.first.idempotencyKey, 'ik-r1');
      expect(await service.drainReceiptQueue(), isEmpty);
    });

    test('export and import round-trip', () async {
      final save = sampleSave();
      await service.save(save);

      final exportFile = File(p.join(dir.path, 'exported.json'));
      await service.exportSave(exportFile);
      final imported = await service.importSave(exportFile);

      expect(imported.profile.profileId, 'profile-1');
      expect(imported.clinic!.tier, 2);
      expect(imported.ownedCases['case-1']!.priorSessionCount, 1);
    });

    test('appended receipts survive a crash before next full save', () async {
      final save = sampleSave();
      await service.save(save);

      const appended = SessionReceipt(
        id: 'r2',
        rulesetVersion: '0.5.0',
        patientId: 'p2',
        idempotencyKey: 'ik-r2',
        correlationId: 'c2',
        turnCount: 2,
        startState: {},
        actions: [InteractionPattern.validate],
        deltas: [],
      );
      await service.appendReceipt(appended);
      // No save() called: simulate crash / kill.

      final loaded = await service.load();
      expect(loaded!.receiptQueue.length, 2);
      expect(
        loaded.receiptQueue.map((r) => r.idempotencyKey),
        contains('ik-r2'),
      );
    });
  });
}

Future<void> _writeEnvelope(File file, Map<String, Object?> payload) async {
  final envelope = Map<String, Object?>.of(payload);
  // Compute a valid checksum for the payload so only the unsupported schema
  // version triggers failure.
  final canonical = CanonicalJson.encodeString(payload);
  final checksum = sha256.convert(utf8.encode(canonical)).toString();
  envelope['checksum'] = checksum;
  await file.writeAsBytes(
    utf8.encode(CanonicalJson.encodeString(envelope)),
    flush: true,
  );
}
