import 'dart:convert';
import 'dart:typed_data';

import 'package:psychemas/psychemas.dart';

import 'card_balance.dart';
import 'clock.dart';
import 'ruleset_profile.dart';
import 'sim_state.dart';
import 'solvability_oracle.dart';
import 'turn_input.dart';
import 'turn_output.dart';
import 'turn_resolver.dart';

/// Explicit build budgets. A failure proves nothing about paths outside them.
class OutcomeCompileLimits {
  const OutcomeCompileLimits(
      {required this.maxActions,
      required this.maxDeltas,
      required this.maxTransitions,
      required this.maxReceiptBytes,
      required this.maxProofBytes});
  final int maxActions;
  final int maxDeltas;
  final int maxTransitions;
  final int maxReceiptBytes;
  final int maxProofBytes;

  void _validate() {
    if (maxActions < 1 ||
        maxActions > 120 ||
        maxDeltas < 1 ||
        maxDeltas > 1024 ||
        maxTransitions < 1 ||
        maxTransitions > 100000 ||
        maxReceiptBytes < 1 ||
        maxReceiptBytes > SignedEnvelope.maxReceiptBytes ||
        maxProofBytes < 1 ||
        maxProofBytes > 262144) {
      throw const OutcomeCompileException('invalid_limits');
    }
  }

  Map<String, Object?> toJson() => {
        'max_actions': maxActions,
        'max_deltas': maxDeltas,
        'max_transitions': maxTransitions,
        'max_receipt_bytes': maxReceiptBytes,
        'max_proof_bytes': maxProofBytes
      };
}

/// Structured failure codes contain no manifest prose or client-supplied text.
class OutcomeCompileException implements Exception {
  const OutcomeCompileException(this.kind);
  final String kind;
  @override
  String toString() => 'OutcomeCompileException($kind)';
}

/// Immutable output of a trusted, model-free content build. This is not a token,
/// signature, client certificate or proof of any additional gameplay path.
class TrustedOutcomeProof {
  TrustedOutcomeProof._(
      Map<String, Object?> document,
      this.finalState,
      List<InteractionPattern> actions,
      List<StructuredDelta> deltas,
      this.maxIdentifierReceiptBytes,
      this.maxIdentifierEnvelopeBytes)
      : _document = _freeze(document) as Map<String, Object?>,
        canonicalBytes = List<int>.unmodifiable(CanonicalJson.encode(document)),
        actions = List<InteractionPattern>.unmodifiable(actions),
        deltas = List<StructuredDelta>.unmodifiable(deltas);
  final Map<String, Object?> _document;
  final List<int> canonicalBytes;
  final List<InteractionPattern> actions;
  final List<StructuredDelta> deltas;
  final SimState finalState;

  /// Conservative size with all four receipt identifiers at their wire limit.
  /// Compiler metadata is excluded from this real SessionReceipt serialization.
  final int maxIdentifierReceiptBytes;

  /// Base64 envelope size including 64 signature bytes and a 256-byte key ID.
  /// This is a sizing calculation only; the compiler never signs a receipt.
  final int maxIdentifierEnvelopeBytes;
  Map<String, Object?> toJson() => _document;

  static Object? _freeze(Object? value) {
    if (value is Map<String, Object?>) {
      return Map<String, Object?>.unmodifiable(
          value.map((k, v) => MapEntry(k, _freeze(v))));
    }
    if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
    return value;
  }
}

/// Certifies only fresh turn-zero starts from checksum-verified content using
/// the explicitly supplied effective balance. Medication and history begin
/// empty; arbitrary SimState inputs are deliberately not representable.
class TrustedOutcomeCompiler {
  const TrustedOutcomeCompiler({required this.balance, required this.limits});
  static const compilerVersion = 'psycore-outcome-v1';
  static const proofSchemaVersion = '1.0.0';
  final CardBalance balance;
  final OutcomeCompileLimits limits;
  static final _identifier = RegExp(r'^[A-Za-z0-9_.:-]{1,128}$');
  static const _initialAxes = {
    'trust',
    'agitation',
    'resistance',
    'trauma',
    'freeze_turns',
    'session_progress'
  };

  TrustedOutcomeProof compile(
      {required Uint8List rawManifest,
      required SessionStartState start,
      required String catalogVersion,
      Iterable<RegExp> forbiddenPatterns = const []}) {
    limits._validate();
    final manifest =
        ManifestLoader(forbiddenPatterns: forbiddenPatterns.toList())
            .load(rawManifest);
    if (!RulesetProfile.supports(manifest.rulesetVersion)) {
      throw const OutcomeCompileException('unsupported_ruleset');
    }
    if (!_identifier.hasMatch(manifest.id) ||
        !_identifier.hasMatch(catalogVersion) ||
        !_identifier.hasMatch(manifest.rulesetVersion) ||
        start.rootSeed < 0 ||
        start.rootSeed > 2147483647) {
      throw const OutcomeCompileException('invalid_identity_or_seed');
    }
    if (balance.activeCardSlots < 1 ||
        balance.activeCardSlots > 6 ||
        balance.toJson().values.any((v) => v < 0 || v > 100) ||
        balance.successProgressThreshold == 0) {
      throw const OutcomeCompileException('unsupported_balance');
    }
    final axes = manifest.initialState;
    if (axes.keys.any((k) => !_initialAxes.contains(k)) ||
        axes.values.any((v) => v < 0 || v > 100) ||
        CanonicalJson.encodeString(axes) !=
            CanonicalJson.encodeString(start.initialAxes)) {
      throw const OutcomeCompileException('unsupported_start_axes');
    }
    if ((axes['session_progress'] ?? 0) != 0 ||
        (axes['agitation'] ?? 0) >= balance.walkoutThreshold) {
      throw const OutcomeCompileException('nonfresh_or_terminal_start');
    }
    final equipped = start.loadout.cardIds;
    final owned = start.library.ownedCardIds;
    final available = manifest.resolvedCards.map((c) => c.id).toSet();
    if (equipped.isEmpty ||
        start.loadout.slotCap < 1 ||
        start.loadout.slotCap > 6 ||
        equipped.length > start.loadout.slotCap ||
        equipped.length > balance.activeCardSlots ||
        equipped.toSet().length != equipped.length ||
        owned.length > 64 ||
        owned.any((id) => !_identifier.hasMatch(id)) ||
        equipped.any((id) => !available.contains(id) || !owned.contains(id))) {
      throw const OutcomeCompileException('invalid_inventory');
    }
    // Snapshot caller collections before either search or replay can use them.
    final snapshot = SessionStartState(
        rootSeed: start.rootSeed,
        initialAxes: Map<String, int>.unmodifiable(axes),
        loadout: Loadout(
            cardIds: List<String>.unmodifiable(equipped),
            slotCap: start.loadout.slotCap),
        library: CardLibrary(ownedCardIds: Set<String>.unmodifiable(owned)),
        controllers: start.controllers);
    final initial =
        SimState.fromInitialState(snapshot.rootSeed, snapshot.initialAxes);
    final result = SolvabilityOracle(
            balance: balance,
            maxTurns: limits.maxActions,
            maxTransitions: limits.maxTransitions)
        .analyze(manifest,
            rootSeed: snapshot.rootSeed,
            startState: initial,
            loadout: snapshot.loadout,
            library: snapshot.library,
            controllers: snapshot.controllers);
    if (!result.solved ||
        result.actions.isEmpty ||
        result.actions.length > limits.maxActions) {
      throw const OutcomeCompileException('unproven_within_bounds');
    }
    final resolver =
        TurnResolver(const InjectedClock.replay(0), balance: balance);
    var state = initial;
    TurnOutput? output;
    final deltas = <StructuredDelta>[];
    for (final action in result.actions) {
      if (output?.isTerminal ?? false)
        throw const OutcomeCompileException('path_after_terminal');
      output = resolver.resolve(TurnInput(
          rulesetVersion: manifest.rulesetVersion,
          manifest: manifest,
          state: state,
          action: action,
          loadout: snapshot.loadout,
          library: snapshot.library,
          controllers: snapshot.controllers));
      deltas.addAll(output.deltas);
      if (deltas.length > limits.maxDeltas ||
          output.deltas.any((d) =>
              d.rulesetVersion != manifest.rulesetVersion ||
              d.deltaMillis < -1000 ||
              d.deltaMillis > 1000 ||
              !_identifier.hasMatch(d.reasonKey))) {
        throw const OutcomeCompileException('delta_bounds_exceeded');
      }
      state = output.nextState;
    }
    if (output == null ||
        !output.isTerminal ||
        output.outcome != SessionOutcome.succeed ||
        output.lifecycle != CaseLifecycle.cured ||
        state != result.finalState ||
        state.turn != result.actions.length) {
      throw const OutcomeCompileException('replay_not_cured');
    }
    final boundStart = <String, Object?>{
      ...snapshot.toJson(),
      'case_id': manifest.id,
      'manifest_checksum': manifest.contentChecksum
    };
    final longestId = 'x' * 128;
    final receiptBytes = SessionReceipt(
            id: longestId,
            rulesetVersion: manifest.rulesetVersion,
            patientId: longestId,
            idempotencyKey: longestId,
            correlationId: longestId,
            turnCount: state.turn,
            startState: boundStart,
            actions: result.actions,
            deltas: deltas)
        .toCanonicalBytes();
    if (receiptBytes.length > limits.maxReceiptBytes)
      throw const OutcomeCompileException('receipt_bytes_exceeded');
    final envelopeSize = CanonicalJson.encode({
      'canonical_receipt_bytes': base64Encode(receiptBytes),
      'signature': 'A' * 86 + '==',
      'suite_id': 'ed25519-v1',
      'signing_key_id': 'x' * 256
    }).length;
    final proof = TrustedOutcomeProof._({
      'proof_schema_version': proofSchemaVersion,
      'compiler_version': compilerVersion,
      'catalog_version': catalogVersion,
      'receipt_schema_version': SessionReceipt.currentSchemaVersion,
      'manifest': {
        'id': manifest.id,
        'content_checksum': manifest.contentChecksum,
        'schema_version': manifest.schemaVersion,
        'ruleset_version': manifest.rulesetVersion
      },
      'effective_balance': balance.toJson(),
      'start_state': boundStart,
      'actions': result.actions.map((a) => a.toJson()).toList(),
      'deltas': deltas.map((d) => d.toJson()).toList(),
      'turn_count': state.turn,
      'terminal': {
        'outcome': output.outcome.toJson(),
        'lifecycle': output.lifecycle.toJson(),
        'is_terminal': output.isTerminal,
        'state': state.toJson()
      },
      'search': {
        'limits': limits.toJson(),
        'explored_transitions': result.exploredTransitions
      },
      'wire_size_bounds': {
        'canonical_receipt_bytes': receiptBytes.length,
        'signed_envelope_bytes': envelopeSize,
        'receipt_identifier_max_bytes': 128,
        'signing_key_identifier_max_bytes': 256
      },
    }, state, result.actions, deltas, receiptBytes.length, envelopeSize);
    if (proof.canonicalBytes.length > limits.maxProofBytes)
      throw const OutcomeCompileException('proof_bytes_exceeded');
    return proof;
  }
}
