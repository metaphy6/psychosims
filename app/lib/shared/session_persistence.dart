import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart' as core;

/// A durable snapshot of an in-progress session.
///
/// Persisted at each turn boundary so a backgrounded, OS-killed, or crashed
/// session can resume into a consistent state with no lost or double-applied
/// turn (0.9 crash-recovery convention).
class SessionCheckpoint {
  const SessionCheckpoint({
    required this.correlationId,
    required this.manifestId,
    required this.state,
    required this.conversationWindow,
    required this.deltaLog,
    this.version = 2,
    this.manifestChecksum,
    this.rulesetVersion,
    this.startState,
    this.actions = const [],
    this.outputs = const [],
  });

  final String correlationId;
  final String manifestId;
  final core.SimState state;
  final List<core.ConversationTurn> conversationWindow;
  final List<StructuredDelta> deltaLog;
  final int version;
  final String? manifestChecksum;
  final String? rulesetVersion;
  final SessionStartState? startState;
  final List<InteractionPattern> actions;
  final List<core.TurnOutput> outputs;

  Map<String, Object?> toJson() => {
        'version': version,
        'manifest_checksum': manifestChecksum,
        'ruleset_version': rulesetVersion,
        'start_state': startState?.toJson(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'outputs': outputs.map((o) => o.toJson()).toList(),
        'correlation_id': correlationId,
        'manifest_id': manifestId,
        'state': state.toJson(),
        'delta_log': deltaLog.map((d) => d.toJson()).toList(),
      };

  factory SessionCheckpoint.fromJson(Map<String, Object?> json) {
    final version = json['version']! as int;
    if (version < 1 || version > 2) {
      throw const FormatException('Unsupported checkpoint');
    }
    return SessionCheckpoint(
      version: version,
      manifestChecksum: json['manifest_checksum'] as String?,
      rulesetVersion: json['ruleset_version'] as String?,
      startState: json['start_state'] == null
          ? null
          : SessionStartState.fromJson(
              json['start_state']! as Map<String, Object?>),
      actions: ((json['actions'] ?? const []) as List)
          .cast<String>()
          .map(InteractionPatternJson.fromJson)
          .toList(),
      outputs: ((json['outputs'] ?? const []) as List).map((value) {
        final output = (value as Map).cast<String, Object?>();
        return core.TurnOutput(
          nextState: core.SimState.fromJson(
              output['next_state']! as Map<String, Object?>),
          deltas: (output['deltas']! as List)
              .map((d) =>
                  StructuredDelta.fromJson((d as Map).cast<String, Object?>()))
              .toList(),
          requiredClueTokens:
              (output['required_clue_tokens']! as List).cast<String>(),
          outcome: SessionOutcomeJson.fromJson(output['outcome']! as String),
          isTerminal: output['is_terminal']! as bool,
          lifecycle: CaseLifecycleJson.fromJson(output['lifecycle']! as String),
        );
      }).toList(),
      correlationId: json['correlation_id']! as String,
      manifestId: json['manifest_id']! as String,
      state: core.SimState.fromJson(json['state']! as Map<String, Object?>),
      conversationWindow: const [],
      deltaLog: (json['delta_log']! as List<dynamic>)
          .cast<Map<String, Object?>>()
          .map(StructuredDelta.fromJson)
          .toList(),
    );
  }
}

/// Durable session checkpointing with no raw transcript persistence.
///
/// Only structured, replayable state is written. Dialogue is memory-only and
/// is deliberately omitted on save and ignored when loading legacy v1 data.
/// Resuming reconstructs the prompt from deterministic state and typed deltas.
class SessionPersistenceService {
  SessionPersistenceService({required this.directory});

  final Directory directory;

  static const String _checkpointFile = 'session_checkpoint.json';
  static final Map<String, Future<void>> _pendingByDirectory = {};

  File get _file => File(p.join(directory.path, _checkpointFile));

  // Navigation can replace the service instance while an operation is pending.
  // Share the queue by store path, and remove idle entries to avoid retaining
  // temporary stores. Each caller still receives its own operation's errors.
  Future<T> _serialized<T>(Future<T> Function() operation) {
    final key = p.normalize(directory.absolute.path);
    final previous = _pendingByDirectory[key] ?? Future<void>.value();
    final result = previous.then((_) => operation());
    final drained =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _pendingByDirectory[key] = drained;
    drained.then((_) {
      if (identical(_pendingByDirectory[key], drained)) {
        _pendingByDirectory.remove(key);
      }
    });
    return result;
  }

  /// Persists [checkpoint] atomically, in call order with load and clear.
  /// [canCommit] lets a retired session abandon a pending write before commit.
  Future<void> save(SessionCheckpoint checkpoint,
      {bool Function()? canCommit}) {
    final encoded = jsonEncode(checkpoint.toJson());
    return _serialized(() => _write(encoded, canCommit: canCommit));
  }

  Future<void> _write(String encoded, {bool Function()? canCommit}) async {
    if (canCommit != null && !canCommit()) return;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final temporary = await directory.createTemp('.session-checkpoint-');
    try {
      final file = File(p.join(temporary.path, _checkpointFile));
      await file.writeAsString(encoded, flush: true);
      if (canCommit != null && !canCommit()) return;
      await file.rename(_file.path);
    } finally {
      await temporary.delete(recursive: true);
    }
  }

  /// Loads the most recent checkpoint, or null if none exists or it is corrupt.
  Future<SessionCheckpoint?> load() => _serialized(_load);

  Future<SessionCheckpoint?> _load() async {
    if (!await _file.exists()) return null;
    try {
      if (await _file.length() > 5 * 1024 * 1024) return null;
      final text = await _file.readAsString();
      final json = jsonDecode(text) as Map<String, Object?>;
      final checkpoint = SessionCheckpoint.fromJson(json);
      if (json.containsKey('conversation_window')) {
        await _write(jsonEncode(checkpoint.toJson()));
      }
      return checkpoint;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// Clears any persisted checkpoint.
  Future<void> clear({bool Function()? canCommit}) => _serialized(() async {
        if (await _file.exists()) {
          if (canCommit != null && !canCommit()) return;
          await _file.delete();
        }
      });
}
