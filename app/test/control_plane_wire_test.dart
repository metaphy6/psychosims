import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter_test/flutter_test.dart';
import 'package:psychemas/psychemas.dart';

void main() {
  Map<String, Object?> permit() => {
        'id': 'session',
        'patient_id': 'patient',
        'ruleset_version': '0.1.0',
        'expires_at': '2027-01-01T00:00:00.000Z',
        'reward_status': 'conditional_certified',
        'certificate_id': 'a' * 64,
        'catalog_sha256': 'b' * 64,
        'start_state': {
          'loadout': {
            'card_ids': ['open_question'],
            'slot_cap': 5
          },
          'library': {
            'owned_card_ids': ['open_question']
          },
          'controllers': const TherapyControllerSettings().toJson(),
          'initial_axes': {'trust': 40, 'agitation': 45, 'resistance': 20},
          'root_seed': 1729
        }
      };
  Map<String, Object?> verdict() => {
        'id': 'session',
        'idempotency_key': 'rcp_session',
        'status': 'accepted',
        'reward_status': 'certified',
        'certificate_id': 'a' * 64,
        'profile_version': 2,
        'xp_awarded': 10,
        'study_points_awarded': 2,
        'cash_micros_awarded': 1000000
      };

  test('conditional permits bind both exact certificate hashes', () {
    final parsed = SessionAuthorization.fromJson(permit());
    expect(parsed.certificateId, 'a' * 64);
    expect(parsed.catalogSha256, 'b' * 64);
    expect(parsed.toJson(), permit());
    for (final invalid in [
      {...permit()}..remove('certificate_id'),
      {...permit()}..remove('catalog_sha256'),
      {...permit(), 'certificate_id': 'PRIVATE DIALOGUE'},
      {...permit(), 'catalog_sha256': 'B' * 64},
      {...permit(), 'reward_status': 'held_unproven'},
    ]) {
      expect(
          () => SessionAuthorization.fromJson(invalid), throwsFormatException);
    }
    final held = permit()
      ..remove('certificate_id')
      ..remove('catalog_sha256');
    held['reward_status'] = 'held_unproven';
    expect(SessionAuthorization.fromJson(held).certificateId, isNull);
  });

  test('certified verdict preserves authoritative bounded awards and reasons',
      () {
    final parsed = ReceiptVerdict.fromJson(verdict());
    expect(parsed.certificateId, 'a' * 64);
    expect(parsed.xpAwarded, 10);
    expect(parsed.studyPointsAwarded, 2);
    expect(parsed.cashMicrosAwarded, 1000000);
    expect(ReceiptVerdict.fromJson(parsed.toJson()).toJson(), parsed.toJson());
    final zero = verdict()
      ..remove('xp_awarded')
      ..remove('study_points_awarded')
      ..remove('cash_micros_awarded');
    expect(ReceiptVerdict.fromJson(zero).xpAwarded, 0);
    for (final reason in [
      'cooldown',
      'window_budget',
      'economy_disabled',
      'balance_limit',
      'already_cured'
    ]) {
      final item = ReceiptVerdict.fromJson({
        ...zero,
        'reward_status': 'certified_unrewarded',
        'reward_reason': reason
      });
      expect(item.rewardReason, reason);
      expect(item.cashMicrosAwarded, 0);
    }
    for (final invalid in [
      {...verdict()}..remove('certificate_id'),
      {...verdict()}..remove('profile_version'),
      {...verdict(), 'profile_version': 0},
      {...verdict(), 'xp_awarded': -1},
      {...verdict(), 'xp_awarded': 10001},
      {...verdict(), 'study_points_awarded': 1001},
      {...verdict(), 'cash_micros_awarded': 1000000001},
      {...verdict(), 'cash_micros_awarded': 1.5},
      {...verdict(), 'reward_status': 'held_unproven'},
      {
        ...verdict(),
        'reward_status': 'certified_unrewarded',
        'reward_reason': 'cooldown'
      },
      {...zero, 'reward_status': 'certified_unrewarded'},
      {
        ...zero,
        'reward_status': 'certified_unrewarded',
        'reward_reason': 'PRIVATE DIALOGUE'
      },
    ]) {
      expect(() => ReceiptVerdict.fromJson(invalid), throwsFormatException);
    }
    final held = {
      'id': 'old',
      'idempotency_key': 'old-idem',
      'status': 'accepted',
      'reward_status': 'held_unproven'
    };
    expect(ReceiptVerdict.fromJson(held).profileVersion, isNull);
    expect(ReceiptVerdict.fromJson(held).xpAwarded, 0);
  });

  test('shared Dart-Go envelope verifies exact signed bytes and hash',
      () async {
    final fixture = jsonDecode(
        await File('../test_fixtures/receipts/signed_ed25519_v1.json')
            .readAsString()) as Map<String, dynamic>;
    final envelope =
        SignedEnvelope.fromJson(fixture['envelope'] as Map<String, Object?>);
    expect(hashes.sha256.convert(envelope.canonicalReceiptBytes).toString(),
        fixture['wire_sha256']);
    final key = SimplePublicKey(base64Decode(fixture['public_key'] as String),
        type: KeyPairType.ed25519);
    expect(
        await Ed25519().verify(envelope.canonicalReceiptBytes,
            signature: Signature(envelope.signature, publicKey: key)),
        isTrue);
    expect(CanonicalJson.encode(fixture['receipt']),
        envelope.canonicalReceiptBytes);
    final altered = List<int>.of(envelope.canonicalReceiptBytes)..[1] = 32;
    expect(
        await Ed25519().verify(altered,
            signature: Signature(envelope.signature, publicKey: key)),
        isFalse);
  });
  test(
      'actual Go batch respects contiguous resolved cursor despite later acceptance',
      () async {
    final fixture = jsonDecode(
        await File('../server/internal/server/testdata/reconciliation.json')
            .readAsString()) as Map<String, dynamic>;
    final receipt =
        ReceiptVerdict.fromJson(fixture['receipt'] as Map<String, Object?>);
    expect(receipt.status, 'accepted');
    expect(receipt.profileVersion, 2);
    final batch =
        ReceiptBatch.fromJson(fixture['batch'] as Map<String, Object?>);
    expect(batch.contiguousCursor, 'rcp_fixture_v1');
    expect(batch.results[1].retryable, isTrue);
    expect(batch.results[2].status, 'accepted');
    final certified =
        ReceiptVerdict.fromJson(fixture['certified'] as Map<String, Object?>);
    expect(certified.toJson(), fixture['certified']);
    expect(certified.certificateId, 'c' * 64);
    expect(certified.profileVersion, 4);
    expect(certified.xpAwarded, 100);
    expect(certified.studyPointsAwarded, 3);
    expect(certified.cashMicrosAwarded, 2500000);
    final unrewarded = ReceiptVerdict.fromJson(
        fixture['certified_unrewarded'] as Map<String, Object?>);
    expect(unrewarded.toJson(), fixture['certified_unrewarded']);
    expect(unrewarded.profileVersion, 5);
    expect(unrewarded.rewardReason, 'window_budget');
    expect(unrewarded.xpAwarded, 0);
    expect(unrewarded.studyPointsAwarded, 0);
    expect(unrewarded.cashMicrosAwarded, 0);
  });
}
