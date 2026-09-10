import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psychosims/shared/api_client.dart';
import 'package:psychosims/shared/auth_service.dart';
import 'package:psychosims/shared/online_session_service.dart';
import 'auth_service_test.dart' show TestSecrets, pair;

void main() {
  test('outboxes and checkpoints remain isolated across API origins', () async {
    final dir =
        await Directory('/tmp/agent-runs').createTemp('w3-origin-test-');
    addTearDown(() => dir.delete(recursive: true));
    final config = loadConfig(environment: 'test');
    final secrets = TestSecrets();
    OnlineSessionService service(String origin) {
      final api = ApiClient(baseUrl: origin, network: config.network);
      addTearDown(api.close);
      return OnlineSessionService(
          auth: AuthService(api: api, storage: secrets),
          directory: dir,
          network: config.network);
    }

    final a = service('http://127.0.0.1:8101');
    final b = service('http://127.0.0.1:8102');
    await a.outbox('same-account').savePendingStart({
      'request_id': 'origin-a',
      'case_id': 'case',
      'card_ids': ['open_question']
    });
    expect(await b.outbox('same-account').pendingStart, isNull);
    expect(
        a.outbox('same-account').scope, isNot(b.outbox('same-account').scope));
  });

  for (final certified in [false, true]) {
    test(
        'authorized start signs once, persists through restart, reconciles certified=$certified result',
        () async {
      final dir =
          await Directory('/tmp/agent-runs').createTemp('w3-online-test-');
      addTearDown(() => dir.delete(recursive: true));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final manifest = PatientManifest.fromJson(jsonDecode(
              await File('../content/manifests/poc_sample.json').readAsString())
          as Map<String, Object?>);
      final state = SessionStartState(
              loadout: const Loadout(cardIds: ['open_question'], slotCap: 6),
              library: const CardLibrary(ownedCardIds: {'open_question'}),
              controllers: const TherapyControllerSettings(),
              initialAxes: manifest.initialState,
              rootSeed: 42)
          .toJson();
      state['manifest_checksum'] = manifest.contentChecksum;
      state['case_id'] = manifest.id;
      List<int>? public;
      var starts = 0, receipts = 0;
      server.listen((request) async {
        final text = await utf8.decoder.bind(request).join();
        final body = text.isEmpty
            ? <String, Object?>{}
            : jsonDecode(text) as Map<String, Object?>;
        expect(request.headers.value('authorization'), 'Bearer access');
        Map<String, Object?> response;
        switch (request.uri.path) {
          case '/v1/device-keys':
            public = base64Decode(body['public_key'] as String);
            response = {
              ...body,
              'id': 'key',
              'account_id': 'account-1',
              'created_at': DateTime.now().toUtc().toIso8601String()
            };
          case '/v1/sessions':
            starts++;
            response = {
              'id': 'authorized-session',
              'patient_id': 'patient_instance_1',
              'ruleset_version': manifest.rulesetVersion,
              'start_state': starts == 1
                  ? {
                      ...state,
                      'manifest_checksum':
                          'sha256:${List.filled(64, '0').join()}'
                    }
                  : state,
              'expires_at': DateTime.now()
                  .toUtc()
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
              'reward_status':
                  certified ? 'conditional_certified' : 'held_unproven',
              if (certified) 'certificate_id': 'c' * 64,
              if (certified) 'catalog_sha256': 'd' * 64
            };
          case '/v1/receipts/batch':
            receipts++;
            final envelope = SignedEnvelope.fromJson(
                (body['envelopes'] as List).single as Map<String, Object?>);
            expect(
                await Ed25519().verify(envelope.canonicalReceiptBytes,
                    signature: Signature(envelope.signature,
                        publicKey: SimplePublicKey(public!,
                            type: KeyPairType.ed25519))),
                isTrue);
            final receipt = SessionReceipt.fromJson(
                jsonDecode(utf8.decode(envelope.canonicalReceiptBytes))
                    as Map<String, Object?>);
            expect(receipt.startState, state);
            response = {
              'results': [
                {
                  'id': receipt.id,
                  'idempotency_key': receipt.idempotencyKey,
                  'status': 'accepted',
                  'profile_version': 2,
                  'reward_status': certified ? 'certified' : 'held_unproven',
                  if (certified) 'certificate_id': 'c' * 64,
                  if (certified) 'xp_awarded': 100,
                  if (certified) 'study_points_awarded': 3,
                  if (certified) 'cash_micros_awarded': 2500000,
                  'retryable': false
                }
              ],
              'cursor': receipt.idempotencyKey,
              'queue_depth_hint': 0
            };
          default:
            response = {
              'profile': {'account_id': 'account-1', 'version': 2, 'xp': 0},
              'etag': '"2"'
            };
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
        await request.response.close();
      });
      final config = loadConfig(environment: 'test');
      final api = ApiClient(
          baseUrl: 'http://127.0.0.1:${server.port}', network: config.network);
      addTearDown(api.close);
      final auth = AuthService(api: api, storage: TestSecrets());
      await auth.installPairForVerifiedExchange(pair('access', 'refresh'));
      final online = OnlineSessionService(
          auth: auth, directory: dir, network: config.network);
      await expectLater(
          online.start(manifest: manifest, cardIds: ['open_question']),
          throwsA(isA<ApiException>()));
      final context =
          await online.start(manifest: manifest, cardIds: ['open_question']);
      final receipt = SessionReceipt(
          id: context.authorization.id,
          rulesetVersion: manifest.rulesetVersion,
          patientId: context.authorization.patientId,
          idempotencyKey: 'rcp_${context.authorization.id}',
          correlationId: 'correlation',
          turnCount: 1,
          startState: context.authorization.startState,
          actions: const [InteractionPattern.openQuestion],
          deltas: const []);
      await online.enqueue(context, receipt);
      final restarted = OnlineSessionService(
          auth: auth, directory: dir, network: config.network);
      final restored =
          await restarted.start(manifest: manifest, cardIds: ['open_question']);
      expect(restored.authorization.id, context.authorization.id);
      expect(restored.authorization.toJson(), context.authorization.toJson());
      expect(restored.authorization.certificateId, certified ? 'c' * 64 : null);
      expect(restored.authorization.catalogSha256, certified ? 'd' * 64 : null);
      expect(starts, 2);
      await restarted.sync();
      expect(receipts, 1);
      expect(restarted.status.value.pending, 0);
      expect(restarted.status.value.verdicts.single.rewardStatus,
          certified ? 'certified' : 'held_unproven');
      await expectLater(
          restarted.enqueue(
              context,
              SessionReceipt(
                  id: 'local-practice',
                  rulesetVersion: manifest.rulesetVersion,
                  patientId: context.authorization.patientId,
                  idempotencyKey: 'bad',
                  correlationId: 'c',
                  turnCount: 0,
                  startState: {},
                  actions: [],
                  deltas: [])),
          throwsStateError);
    });
  }
  for (final status in [403, 404, 503]) {
    test('start rejection $status retires only a definitive denied request',
        () async {
      final dir =
          await Directory('/tmp/agent-runs').createTemp('w3-start-recovery-');
      addTearDown(() => dir.delete(recursive: true));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requestIds = <String?>[];
      server.listen((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, Object?>;
        if (request.uri.path.endsWith('device-keys')) {
          request.response.write(jsonEncode({
            ...body,
            'id': 'key',
            'account_id': 'account-1',
            'created_at': DateTime.now().toUtc().toIso8601String()
          }));
        } else {
          requestIds.add(request.headers.value('Psy-Idempotency-Key'));
          request.response.statusCode = status;
          request.response
              .write(jsonEncode({'kind': status == 503 ? 'server' : 'user'}));
        }
        await request.response.close();
      });
      final network =
          loadConfig(environment: 'test').network.copyWith(maxRetries: 0);
      final api = ApiClient(
          baseUrl: 'http://127.0.0.1:${server.port}', network: network);
      addTearDown(api.close);
      final auth = AuthService(api: api, storage: TestSecrets());
      await auth.installPairForVerifiedExchange(pair('access', 'refresh'));
      final manifest = PatientManifest.fromJson(jsonDecode(
              await File('../content/manifests/poc_sample.json').readAsString())
          as Map<String, Object?>);
      final online =
          OnlineSessionService(auth: auth, directory: dir, network: network);
      await expectLater(
          online.start(manifest: manifest, cardIds: ['open_question']),
          throwsA(isA<ApiException>()));
      final restarted =
          OnlineSessionService(auth: auth, directory: dir, network: network);
      if (status == 503) {
        expect(await restarted.outbox('account-1').pendingStart, isNotNull);
        await expectLater(
            restarted.start(manifest: manifest, cardIds: ['validate']),
            throwsStateError);
        await expectLater(
            restarted.start(manifest: manifest, cardIds: ['open_question']),
            throwsA(isA<ApiException>()));
        expect(requestIds[1], requestIds[0]);
      } else {
        expect(await restarted.outbox('account-1').pendingStart, isNull);
        await expectLater(
            restarted.start(manifest: manifest, cardIds: ['validate']),
            throwsA(isA<ApiException>()));
        expect(requestIds[1], isNot(requestIds[0]));
      }
    });
  }
}
