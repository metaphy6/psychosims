// Explicit local integration entry point, launched by the postgres+flutter Go
// test harness. No provider tokens are printed, and no cloud origin is accepted.
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psycore/psycore.dart' as core;
import 'package:psychosims/shared/api_client.dart';
import 'package:psychosims/shared/auth_service.dart';
import 'package:psychosims/shared/career_persistence.dart';
import 'package:psychosims/shared/online_session_service.dart';
import '../../config/tool/local_http_harness.dart';
import '../test/auth_service_test.dart' show TestSecrets;

void main() {
  test(
      'Dart app signs and reconciles an authorized session through Go and PostgreSQL',
      () async {
    final harnessEnvironment = loadLocalHttpHarnessEnvironment();
    String requiredEnvironment(String key) {
      final value = harnessEnvironment[key];
      if (value == null || value.isEmpty) {
        throw StateError('Local harness must supply $key');
      }
      return value;
    }

    final certificationMode = requiredEnvironment('PSY_W3_EXPECT_CERTIFIED');
    expect(certificationMode, isIn(['0', '1']));
    final expectsCertified = certificationMode == '1';
    final origin = Uri.parse(requiredEnvironment('PSY_W3_API_URL'));
    expect(origin.scheme, 'http');
    expect(['127.0.0.1', '::1', 'localhost'], contains(origin.host));
    final production = loadConfig(environment: 'prod');
    // Only transport is adapted for the disposable local integration server.
    final config = production.copyWith(
        network: production.network.copyWith(allowInsecureLoopback: true));
    final api = ApiClient(
        baseUrl: origin.toString(),
        network: config.network.copyWith(maxRetries: 0));
    addTearDown(api.close);
    final secrets = TestSecrets();
    final auth = AuthService(api: api, storage: secrets);
    await auth.signIn(
        provider: 'google',
        idToken: requiredEnvironment('PSY_W3_ID_TOKEN'),
        nonce: requiredEnvironment('PSY_W3_NONCE'));
    final dir =
        await Directory('/tmp/agent-runs').createTemp('w3-http-postgres-');
    addTearDown(() => dir.delete(recursive: true));
    final online = OnlineSessionService(
        auth: auth, directory: dir, network: config.network);
    addTearDown(online.dispose);
    await online.sync();
    final profileBefore = online.status.value.profile;
    expect(profileBefore, isNotNull);
    final manifest = const ManifestLoader().load(Uint8List.fromList(
        await File(requiredEnvironment('PSY_W3_MANIFEST_PATH')).readAsBytes()));
    expect(manifest.id, requiredEnvironment('PSY_W3_CASE_ID'));
    final owned =
        (profileBefore!['owned_card_ids'] as List).cast<String>().toSet();
    final cards = manifest.resolvedCards
        .map((card) => card.id)
        .where(owned.contains)
        .take(config.balance.activeCardSlots)
        .toList();
    expect(cards, isNotEmpty);
    final context = await online.start(manifest: manifest, cardIds: cards);
    final permit = context.authorization;
    expect(permit.rewardStatus,
        expectsCertified ? 'conditional_certified' : 'held_unproven');
    if (expectsCertified) {
      expect(permit.certificateId, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(permit.catalogSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
    } else {
      expect(permit.certificateId, isNull);
      expect(permit.catalogSha256, isNull);
    }
    final start = SessionStartState.fromJson(permit.startState);
    if (expectsCertified) {
      expect(start.rootSeed, 1729);
      expect(start.loadout.slotCap, 5);
      expect(start.library.ownedCardIds, {'open_question'});
      expect(start.loadout.cardIds, ['open_question']);
    }
    final initial =
        core.SimState.fromInitialState(start.rootSeed, start.initialAxes);
    expect(initial.sessionProgress, 0);
    expect(start.initialAxes, manifest.initialState);
    expect(start.controllers, const TherapyControllerSettings());
    final balance = core.CardBalance.fromConfig(config.balance);
    final witness = core.SolvabilityOracle(
            balance: balance, maxTurns: config.network.maxReceiptActions)
        .analyze(manifest,
            rootSeed: start.rootSeed,
            startState: initial,
            loadout: start.loadout,
            library: start.library,
            controllers: start.controllers);
    expect(witness.solved, isTrue,
        reason: 'Real authorized start needs a winning core witness');
    expect(witness.actions, hasLength(100));
    final resolver = core.TurnResolver(const core.InjectedClock.replay(1000),
        balance: balance);
    var current = initial;
    final outputs = <core.TurnOutput>[];
    for (final action in witness.actions) {
      final output = resolver.resolve(core.TurnInput(
          rulesetVersion: manifest.rulesetVersion,
          manifest: manifest,
          state: current,
          action: action,
          loadout: start.loadout,
          library: start.library,
          controllers: start.controllers));
      outputs.add(output);
      current = output.nextState;
    }
    expect(outputs.last.outcome, SessionOutcome.succeed);
    expect(outputs.last.isTerminal, isTrue);
    final receipt = SessionReceipt(
        id: context.authorization.id,
        rulesetVersion: manifest.rulesetVersion,
        patientId: context.authorization.patientId,
        idempotencyKey: 'rcp_${context.authorization.id}',
        correlationId: 'psy_http_fixture',
        turnCount: witness.actions.length,
        startState: context.authorization.startState,
        actions: witness.actions,
        deltas: outputs.expand((output) => output.deltas).toList());
    if (expectsCertified) expect(receipt.deltas, hasLength(160));
    stdout.writeln('FULL_SESSION_EVIDENCE ${jsonEncode({
          'manifest_id': manifest.id,
          'manifest_checksum': manifest.contentChecksum,
          'root_seed': start.rootSeed,
          'controllers': start.controllers.toJson(),
          'balance': balance.toJson(),
          'actions': receipt.actions.length,
          'deltas': receipt.deltas.length,
          'canonical_bytes': receipt.toCanonicalBytes().length,
          'outcome': outputs.last.outcome.toJson(),
          'reward_status': context.authorization.rewardStatus,
        })}');
    await online.enqueue(context, receipt);
    expect(online.status.value.pending, 1);
    expect(receipt.ledgerEvents, isEmpty);
    final pair = (await auth.currentSession())!;
    final queued = (await online.outbox(pair.accountId).readAfter(null)).single;
    expect(queued.envelope.canonicalReceiptBytes, receipt.toCanonicalBytes());
    expect(await File(online.outbox(pair.accountId).scope).readAsString(),
        isNot(contains('correlation_id')));
    final restarted = OnlineSessionService(
        auth: AuthService(api: api, storage: secrets),
        directory: dir,
        network: config.network);
    addTearDown(restarted.dispose);
    final restored =
        (await restarted.outbox(pair.accountId).readAfter(null)).single;
    expect(restored.envelope.canonicalReceiptBytes,
        queued.envelope.canonicalReceiptBytes);
    expect(restored.envelope.signature, queued.envelope.signature);
    await restarted.sync();
    final state = restarted.status.value;
    expect(state.errorKind, isNull);
    expect(state.pending, 0);
    final originalVerdict = state.verdicts.single;
    expect(originalVerdict.status, 'accepted');
    expect(originalVerdict.rewardStatus,
        expectsCertified ? 'certified' : 'held_unproven');
    expect(originalVerdict.certificateId, permit.certificateId);
    expect(originalVerdict.rewardReason, isNull);
    expect(originalVerdict.xpAwarded, expectsCertified ? 100 : 0);
    expect(originalVerdict.studyPointsAwarded, expectsCertified ? 3 : 0);
    expect(originalVerdict.cashMicrosAwarded, expectsCertified ? 2500000 : 0);
    expect(originalVerdict.profileVersion, isPositive);
    for (final entry in {
      'xp': originalVerdict.xpAwarded,
      'study_points': originalVerdict.studyPointsAwarded,
      'cash_micros': originalVerdict.cashMicrosAwarded
    }.entries) {
      expect(profileBefore[entry.key], 0);
      expect(state.profile![entry.key], entry.value);
    }
    expect(state.profile!['version'],
        greaterThanOrEqualTo(profileBefore['version'] as int));
    // A reconnect and both HTTP replay paths must retain the original result,
    // including its profile version, without minting a second award.
    final reconnected = OnlineSessionService(
        auth: AuthService(api: api, storage: secrets),
        directory: dir,
        network: config.network);
    addTearDown(reconnected.dispose);
    await reconnected.sync();
    expect(reconnected.status.value.verdicts.single.toJson(),
        originalVerdict.toJson());
    final singleReplay = await auth.authenticated('POST', '/v1/receipts',
        accountId: pair.accountId,
        idempotencyKey: receipt.idempotencyKey,
        body: restored.envelope.toJson());
    expect(ReceiptVerdict.fromJson(singleReplay.body).toJson(),
        originalVerdict.toJson());
    final batchReplay = await auth.authenticated('POST', '/v1/receipts/batch',
        accountId: pair.accountId,
        idempotencyKey: 'receipt_replay_batch',
        body: {
          'envelopes': [restored.envelope.toJson()]
        });
    final replayedBatch = ReceiptBatch.fromJson(batchReplay.body);
    expect(replayedBatch.results.single.toJson(), originalVerdict.toJson());
    expect(replayedBatch.contiguousCursor, receipt.idempotencyKey);
    await reconnected.sync();
    expect(reconnected.status.value.verdicts, hasLength(1));
    expect(reconnected.status.value.profile, state.profile);
    expect(await CareerPersistenceService(directory: dir).load(), isNull);
    stdout.writeln(
        'RECONCILIATION_EVIDENCE ${jsonEncode(originalVerdict.toJson())}');
    await auth.logout();
    expect(await auth.currentSession(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
