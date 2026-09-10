import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'auth_service_test.dart' show TestSecrets;
import 'package:psychemas/psychemas.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psychosims/shared/api_client.dart';
import 'package:psychosims/shared/durable_queue_persistence.dart';
import 'package:psychosims/shared/signed_receipt_queue.dart';
import 'package:psychosims/shared/device_key_store.dart';

Future<QueueEntry> entry(String id, {String patient = 'p'}) async => QueueEntry(
    id: id,
    enqueuedAt: DateTime.utc(2026),
    envelope: await MemoryDeviceKeyStore().signReceipt(SessionReceipt(
        id: 'session-$id',
        rulesetVersion: '0.1.0',
        patientId: patient,
        idempotencyKey: id,
        correlationId: 'corr',
        turnCount: 0,
        startState: {},
        actions: [],
        deltas: [])));
void main() {
  late Directory dir;
  late TestSecrets secrets;
  test('profile ETag is withheld until the cache catches up with receipts',
      () async {
    final dir = await Directory('/tmp/agent-runs').createTemp('w3-etag-test-');
    addTearDown(() => dir.delete(recursive: true));
    final store = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'account');
    await store.cacheProfile({'account_id': 'account', 'version': 1}, '"1"');
    final entry = QueueEntry(
        id: 'rcp_etag',
        enqueuedAt: DateTime.now().toUtc(),
        envelope: await MemoryDeviceKeyStore().signReceipt(const SessionReceipt(
            id: 'etag',
            rulesetVersion: '0.1.0',
            patientId: 'patient',
            idempotencyKey: 'rcp_etag',
            correlationId: 'correlation',
            turnCount: 0,
            startState: {},
            actions: [],
            deltas: [])));
    await store.append(entry);
    await store.resolve(
        entry.id,
        ReceiptVerdict(
            id: 'etag',
            idempotencyKey: entry.id,
            status: 'accepted',
            profileVersion: 2,
            rewardStatus: 'held_unproven'));
    expect(await store.profileEtag, isNull);
    await store.cacheProfile({'account_id': 'account', 'version': 2}, '"2"');
    expect(await store.profileEtag, '"2"');
  });

  test(
      'disk snapshot is encrypted and authentication rejects modified ciphertext',
      () async {
    final store = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    await store
        .cacheProfile({'account_id': 'a', 'version': 1, 'xp': 123456789}, 'v1');
    await store.append(await entry('private-structured-id'));
    final file = File(store.scope);
    final text = await file.readAsString();
    expect(text.contains('private-structured-id'), isFalse);
    expect(text.contains('123456789'), isFalse);
    final blob = jsonDecode(text) as Map<String, Object?>;
    final cipher = base64Decode(blob['ciphertext'] as String);
    cipher[0] ^= 1;
    blob['ciphertext'] = base64Encode(cipher);
    await file.writeAsString(jsonEncode(blob));
    await expectLater(store.readAfter(null), throwsA(anything));
  });
  test(
      'secure storage failure never creates plaintext and lost keys fail closed',
      () async {
    final store = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    secrets.failNextWrite = true;
    await expectLater(store.append(await entry('private')), throwsStateError);
    expect(await File(store.scope).exists(), isFalse);
    await store.append(await entry('private'));
    secrets.values.clear();
    await expectLater(store.readAfter(null), throwsStateError);
    expect(secrets.values, isEmpty);
  });
  test('unknown transcript fields never enter durable signed receipt bytes',
      () async {
    final store = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    final original = await entry('private');
    for (final nested in [false, true]) {
      final json =
          jsonDecode(utf8.decode(original.envelope.canonicalReceiptBytes))
              as Map<String, Object?>;
      (nested
          ? json['start_state'] as Map<String, Object?>
          : json)['dialogue'] = 'PRIVATE RAW DIALOGUE';
      final malicious = QueueEntry(
          id: original.id,
          enqueuedAt: original.enqueuedAt,
          envelope: SignedEnvelope(
              canonicalReceiptBytes: CanonicalJson.encode(json),
              signature: original.envelope.signature,
              suiteId: original.envelope.suiteId,
              signingKeyId: original.envelope.signingKeyId));
      await expectLater(store.append(malicious), throwsFormatException);
    }
    expect(await store.readAfter(null), isEmpty);
  });

  setUp(() async {
    secrets = TestSecrets();
    dir = await Directory('/tmp/agent-runs').createTemp('w3-queue-test-');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  test(
      'account partition survives restart and concurrent instances without lost writes',
      () async {
    final a = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    final b = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    final entries =
        await Future.wait(List.generate(12, (i) => entry('idem-$i')));
    await Future.wait([
      for (var i = 0; i < entries.length; i++)
        (i.isEven ? a : b).append(entries[i])
    ]);
    expect(await a.readAfter(null), hasLength(12));
    expect(
        await DurableQueuePersistence(
                storage: secrets, directory: dir, accountId: 'b')
            .readAfter(null),
        isEmpty);
    expect(
        await DurableQueuePersistence(
                storage: secrets, directory: dir, accountId: 'a')
            .readAfter(null),
        hasLength(12));
  });
  test(
      'deduplicates exact bytes, rejects conflicts and preserves queue on budget overflow',
      () async {
    final queue = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a', maxEntries: 1);
    final first = await entry('one');
    await queue.append(first);
    await queue.append(first);
    await expectLater(
        queue.append(await entry('one', patient: 'changed')), throwsStateError);
    await expectLater(queue.append(await entry('two')), throwsStateError);
    expect((await queue.readAfter(null)).single.id, 'one');
  });
  test(
      'permanent rejection persisted with cursor; transient failure stops ordered drain',
      () async {
    final persistence = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    for (final id in ['one', 'two', 'three']) {
      await persistence.append(await entry(id));
    }
    final queue = SignedReceiptQueue(
        deviceKeyStore: MemoryDeviceKeyStore(), persistence: persistence);
    var calls = 0;
    await queue.reconcile((envelope) async {
      calls++;
      final receipt = SessionReceipt.fromJson(
          jsonDecode(utf8.decode(envelope.canonicalReceiptBytes))
              as Map<String, Object?>);
      if (calls == 2) {
        throw const ApiException(statusCode: 503, kind: 'unavailable');
      }
      return ReceiptVerdict(
          id: receipt.id,
          idempotencyKey: receipt.idempotencyKey,
          status: 'rejected',
          rewardStatus: 'held_unproven',
          code: 'expired_permit');
    });
    expect(calls, 2);
    final restored = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    expect(await restored.cursor, 'one');
    expect((await restored.verdicts).single.code, 'expired_permit');
    expect((await restored.readAfter(await restored.cursor)).map((e) => e.id),
        ['two', 'three']);
  });
  test('batch reconciliation never acknowledges past a transient item',
      () async {
    final persistence = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    for (final id in ['one', 'two', 'three']) {
      await persistence.append(await entry(id));
    }
    final queue = SignedReceiptQueue(
        deviceKeyStore: MemoryDeviceKeyStore(), persistence: persistence);
    await queue.reconcileBatch((envelopes) async => ReceiptBatch.fromJson({
          'results': [
            {
              'id': 'session-one',
              'idempotency_key': 'one',
              'status': 'accepted',
              'reward_status': 'held_unproven'
            },
            {
              'id': 'session-two',
              'idempotency_key': 'two',
              'status': 'retryable',
              'retryable': true
            },
            {
              'id': 'session-three',
              'idempotency_key': 'three',
              'status': 'accepted',
              'reward_status': 'held_unproven'
            },
          ],
          'queue_depth_hint': 1,
          'cursor': 'one',
        }));
    expect(await persistence.cursor, 'one');
    expect(
        (await persistence.readAfter(await persistence.cursor))
            .map((e) => e.id),
        ['two', 'three']);
  });
  test('profile cache rejects stale versions and another account', () async {
    final persistence = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    await persistence.cacheProfile({'account_id': 'a', 'version': 3}, '3');
    await expectLater(
        persistence.cacheProfile({'account_id': 'a', 'version': 2}, '2'),
        throwsStateError);
    await expectLater(
        persistence.cacheProfile({'account_id': 'b', 'version': 4}, '4'),
        throwsStateError);
    expect((await persistence.cachedProfile)!['version'], 3);
  });
  test(
      'recognized structured receipt fields reject raw dialogue before persistence',
      () async {
    final store = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    final original = await entry('privacy');
    for (final field in ['correlation_id', 'patient_id', 'ruleset_version']) {
      final json =
          jsonDecode(utf8.decode(original.envelope.canonicalReceiptBytes))
              as Map<String, Object?>;
      json[field] = 'PRIVATE RAW DIALOGUE';
      final malicious = QueueEntry(
          id: original.id,
          enqueuedAt: original.enqueuedAt,
          envelope: SignedEnvelope(
              canonicalReceiptBytes: CanonicalJson.encode(json),
              signature: original.envelope.signature,
              suiteId: original.envelope.suiteId,
              signingKeyId: original.envelope.signingKeyId));
      await expectLater(store.append(malicious), throwsFormatException);
    }
    expect(await File(store.scope).exists(), isFalse);
  });
  test('profile cache projects typed fields and never persists raw transcript',
      () async {
    final store = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    await store.cacheProfile({
      'account_id': 'a',
      'version': 1,
      'xp': 0,
      'owned_card_ids': ['open_question'],
      'raw_transcript': 'PRIVATE RAW DIALOGUE'
    }, '1');
    final restarted = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    expect(await restarted.cachedProfile, {
      'account_id': 'a',
      'version': 1,
      'xp': 0,
      'owned_card_ids': ['open_question']
    });
    await expectLater(
        store.cacheProfile({
          'account_id': 'a',
          'version': 2,
          'owned_card_ids': ['PRIVATE RAW DIALOGUE']
        }, '2'),
        throwsFormatException);
  });
  test('pending start rejects unknown fields before persistence', () async {
    final store = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    await expectLater(
        store.savePendingStart({
          'request_id': 'request',
          'case_id': 'case',
          'card_ids': ['open_question'],
          'raw_transcript': 'PRIVATE RAW DIALOGUE'
        }),
        throwsFormatException);
    expect(await store.pendingStart, isNull);
  });
  test('start axes and pending authorization reject recognized free text',
      () async {
    final fixture = jsonDecode(
        await File('../test_fixtures/receipts/signed_ed25519_v1.json')
            .readAsString()) as Map<String, Object?>;
    final envelope =
        SignedEnvelope.fromJson(fixture['envelope'] as Map<String, Object?>);
    final original = jsonDecode(utf8.decode(envelope.canonicalReceiptBytes))
        as Map<String, Object?>;
    final store = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    for (final mutate in <void Function(Map<String, Object?>)>[
      (start) => (start['initial_axes']
          as Map<String, Object?>)['PRIVATE RAW DIALOGUE'] = 1,
      (start) => (start['initial_axes'] as Map<String, Object?>)['trust'] = 101,
      (start) => (start['loadout'] as Map<String, Object?>)['card_ids'] = [
            'PRIVATE RAW DIALOGUE'
          ],
      (start) => start['manifest_checksum'] = 'PRIVATE RAW DIALOGUE',
    ]) {
      final json = jsonDecode(jsonEncode(original)) as Map<String, Object?>;
      mutate(json['start_state'] as Map<String, Object?>);
      await expectLater(
          store.append(QueueEntry(
              id: json['idempotency_key'] as String,
              enqueuedAt: DateTime.now().toUtc(),
              envelope: SignedEnvelope(
                  canonicalReceiptBytes: CanonicalJson.encode(json),
                  signature: envelope.signature,
                  suiteId: envelope.suiteId,
                  signingKeyId: envelope.signingKeyId))),
          throwsFormatException);
    }
    await expectLater(
        store.savePendingStart({
          'request_id': 'request',
          'case_id': 'case',
          'card_ids': ['open_question'],
          'authorization': {
            'id': 'session',
            'patient_id': 'patient',
            'ruleset_version': '0.1.0',
            'start_state': original['start_state'],
            'expires_at': DateTime.now().toUtc().toIso8601String(),
            'reward_status': 'held_unproven',
            'raw_transcript': 'PRIVATE RAW DIALOGUE'
          }
        }),
        throwsFormatException);
    expect(await File(store.scope).exists(), isFalse);
  });
  test(
      'restart projects legacy profile data and rejects imported raw receipt fields',
      () async {
    final store = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    await store.cacheProfile({'account_id': 'a', 'version': 1}, '1');
    final certified = await entry('certified');
    await store.append(certified);
    await store.resolve(
        certified.id,
        ReceiptVerdict(
            id: 'session-certified',
            idempotencyKey: certified.id,
            status: 'accepted',
            rewardStatus: 'certified',
            certificateId: 'a' * 64,
            profileVersion: 2,
            xpAwarded: 100,
            studyPointsAwarded: 3,
            cashMicrosAwarded: 2500000));
    await store.append(await entry('imported'));
    final cipher = AesGcm.with256bits();
    final key = SecretKey(base64Decode(secrets.values.values.single));
    final aad = utf8.encode('psychosims.outbox.v1:${store.scope}:a');
    Future<Map<String, Object?>> readState() async {
      final blob = jsonDecode(await File(store.scope).readAsString())
          as Map<String, Object?>;
      final plain = await cipher.decrypt(
          SecretBox(base64Decode(blob['ciphertext'] as String),
              nonce: base64Decode(blob['nonce'] as String),
              mac: Mac(base64Decode(blob['mac'] as String))),
          secretKey: key,
          aad: aad);
      return jsonDecode(utf8.decode(plain)) as Map<String, Object?>;
    }

    Future<void> importState(Map<String, Object?> state) async {
      final sealed = await cipher.encrypt(utf8.encode(jsonEncode(state)),
          secretKey: key, aad: aad);
      await File(store.scope).writeAsString(jsonEncode({
        'version': 1,
        'algorithm': 'aes-256-gcm',
        'nonce': base64Encode(sealed.nonce),
        'mac': base64Encode(sealed.mac.bytes),
        'ciphertext': base64Encode(sealed.cipherText)
      }));
    }

    var state = await readState();
    ((state['verdicts'] as List).single
        as Map<String, Object?>)['raw_transcript'] = 'PRIVATE RAW DIALOGUE';
    (state['profile'] as Map<String, Object?>)['raw_transcript'] =
        'PRIVATE RAW DIALOGUE';
    await importState(state);
    final restarted = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    expect((await restarted.cachedProfile)!.containsKey('raw_transcript'),
        isFalse);
    state = await readState();
    expect(jsonEncode(state).contains('PRIVATE RAW DIALOGUE'), isFalse);
    final savedVerdict = (await restarted.verdicts).single;
    expect(savedVerdict.certificateId, 'a' * 64);
    expect(savedVerdict.xpAwarded, 100);
    expect(savedVerdict.studyPointsAwarded, 3);
    expect(savedVerdict.cashMicrosAwarded, 2500000);
    await restarted.cacheProfile({'account_id': 'a', 'version': 3}, '3');
    expect((await restarted.verdicts).single.profileVersion, 2);
    await restarted.append(certified);
    expect(await restarted.verdicts, hasLength(1));
    final clean = await readState();
    for (final invalid in [
      {'certificate_id': 'PRIVATE RAW DIALOGUE'},
      {'xp_awarded': 10001}
    ]) {
      final changed = jsonDecode(jsonEncode(clean)) as Map<String, Object?>;
      ((changed['verdicts'] as List).single as Map<String, Object?>)
          .addAll(invalid);
      await importState(changed);
      await expectLater(restarted.verdicts, throwsFormatException);
    }
    await importState(clean);
    state = await readState();
    final queued = QueueEntry.fromJson(
        (state['entries'] as List).single as Map<String, Object?>);
    final receipt =
        jsonDecode(utf8.decode(queued.envelope.canonicalReceiptBytes))
            as Map<String, Object?>;
    receipt['correlation_id'] = 'PRIVATE RAW DIALOGUE';
    state['entries'] = [
      QueueEntry(
              id: queued.id,
              enqueuedAt: queued.enqueuedAt,
              envelope: SignedEnvelope(
                  canonicalReceiptBytes: CanonicalJson.encode(receipt),
                  signature: queued.envelope.signature,
                  suiteId: queued.envelope.suiteId,
                  signingKeyId: queued.envelope.signingKeyId))
          .toJson()
    ];
    await importState(state);
    await expectLater(restarted.readAfter(null), throwsFormatException);
  });
  test(
      'full100turn receipts fit while121actions1025deltas and oversize fail closed',
      () async {
    final store = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a');
    SessionReceipt receipt(String id, int actions, {int deltas = 0}) =>
        SessionReceipt(
            id: id,
            rulesetVersion: '0.1.0',
            patientId: 'patient',
            idempotencyKey: id,
            correlationId: 'corr',
            turnCount: actions,
            startState: {},
            actions: List.filled(actions, InteractionPattern.openQuestion),
            deltas: List.filled(
                deltas,
                const StructuredDelta(
                    rulesetVersion: '0.1.0',
                    axis: StateAxis.trust,
                    deltaMillis: 1,
                    reasonKey: 'test',
                    cardType: CardType.disclosing,
                    cardSignature: CardSignature.breaker,
                    contextFit: ContextFit.aligned)));
    Future<void> enqueue(SessionReceipt receipt) async =>
        store.append(QueueEntry(
            id: receipt.idempotencyKey,
            enqueuedAt: DateTime.now().toUtc(),
            envelope: await MemoryDeviceKeyStore().signReceipt(receipt)));
    await enqueue(receipt('full100', 100));
    expect((await store.readAfter(null)).single.id, 'full100');
    await enqueue(receipt('limit120', 120));
    await expectLater(
        enqueue(receipt('over-actions', 121)), throwsFormatException);
    await expectLater(enqueue(receipt('over-deltas', 1, deltas: 1025)),
        throwsFormatException);
    expect(
        () => SignedEnvelope(
            canonicalReceiptBytes: List.filled(131073, 32),
            signature: List.filled(64, 0),
            suiteId: 'ed25519-v1',
            signingKeyId: 'key'),
        throwsFormatException);
    expect(await store.readAfter(null), hasLength(2));
  });
  test(
      'outbox honors configured action delta and byte limits on writes and restart',
      () async {
    final network = loadConfig(environment: 'test').network;
    final original = await entry('configured');
    final fixture =
        jsonDecode(utf8.decode(original.envelope.canonicalReceiptBytes))
            as Map<String, Object?>;
    fixture['turn_count'] = 2;
    fixture['actions'] = ['open_question', 'open_question'];
    final changed = QueueEntry(
        id: original.id,
        enqueuedAt: original.enqueuedAt,
        envelope: SignedEnvelope(
            canonicalReceiptBytes: CanonicalJson.encode(fixture),
            signature: original.envelope.signature,
            suiteId: original.envelope.suiteId,
            signingKeyId: original.envelope.signingKeyId));
    final store = DurableQueuePersistence(
        storage: secrets, directory: dir, accountId: 'a', network: network);
    await store.append(changed);
    final limited = DurableQueuePersistence(
        storage: secrets,
        directory: dir,
        accountId: 'a',
        network: network.copyWith(maxReceiptActions: 1));
    await expectLater(limited.readAfter(null), throwsFormatException);
    final byteLimited = DurableQueuePersistence(
        storage: secrets,
        directory: dir,
        accountId: 'a',
        network: network.copyWith(
            maxCanonicalReceiptBytes:
                changed.envelope.canonicalReceiptBytes.length - 1));
    await expectLater(byteLimited.readAfter(null), throwsFormatException);
    final deltaReceipt = SessionReceipt(
        id: 'deltas',
        rulesetVersion: '0.1.0',
        patientId: 'patient',
        idempotencyKey: 'deltas',
        correlationId: 'corr',
        turnCount: 1,
        startState: {},
        actions: [InteractionPattern.openQuestion],
        deltas: List.filled(
            3,
            const StructuredDelta(
                rulesetVersion: '0.1.0',
                axis: StateAxis.trust,
                deltaMillis: 1,
                reasonKey: 'test',
                cardType: CardType.disclosing,
                cardSignature: CardSignature.breaker,
                contextFit: ContextFit.aligned)));
    final deltaStore = DurableQueuePersistence(
        storage: secrets,
        directory: dir,
        accountId: 'b',
        network: network.copyWith(maxReceiptDeltas: 2));
    await expectLater(
        deltaStore.append(QueueEntry(
            id: 'deltas',
            enqueuedAt: DateTime.now().toUtc(),
            envelope: await MemoryDeviceKeyStore().signReceipt(deltaReceipt))),
        throwsFormatException);
  });
}
