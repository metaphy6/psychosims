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
    this.version = 1,
  });

  final String correlationId;
  final String manifestId;
  final core.SimState state;
  final List<core.ConversationTurn> conversationWindow;
  final List<StructuredDelta> deltaLog;
  final int version;

  Map<String, Object?> toJson() => {
        'version': version,
        'correlation_id': correlationId,
        'manifest_id': manifestId,
        'state': state.toJson(),
        'conversation_window': conversationWindow
            .map((t) => {'role': t.role, 'text': t.text})
            .toList(),
        'delta_log': deltaLog.map((d) => d.toJson()).toList(),
      };

  factory SessionCheckpoint.fromJson(Map<String, Object?> json) {
    return SessionCheckpoint(
      version: json['version']! as int,
      correlationId: json['correlation_id']! as String,
      manifestId: json['manifest_id']! as String,
      state: core.SimState.fromJson(json['state']! as Map<String, Object?>),
      conversationWindow: (json['conversation_window']! as List<dynamic>)
          .cast<Map<String, Object?>>()
          .map((m) => core.ConversationTurn(
                role: m['role']! as String,
                text: m['text']! as String,
              ))
          .toList(),
      deltaLog: (json['delta_log']! as List<dynamic>)
          .cast<Map<String, Object?>>()
          .map(StructuredDelta.fromJson)
          .toList(),
    );
  }
}

/// Durable session checkpointing with no raw transcript persistence.
///
/// Only structured, replayable state is written. The conversation window is
/// stored as stable role/text pairs (not as model I/O transcripts), keeping
/// the 0.6 "no durable raw transcript" rule intact.
class SessionPersistenceService {
  SessionPersistenceService({required this.directory});

  final Directory directory;

  static const String _checkpointFile = 'session_checkpoint.json';

  File get _file => File(p.join(directory.path, _checkpointFile));

  /// Persists [checkpoint] atomically: write to a temp file, then rename.
  Future<void> save(SessionCheckpoint checkpoint) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final tempPath = '${_file.path}.tmp';
    final encoded = jsonEncode(checkpoint.toJson());
    await File(tempPath).writeAsString(encoded, flush: true);
    await File(tempPath).rename(_file.path);
  }

  /// Loads the most recent checkpoint, or null if none exists or it is corrupt.
  Future<SessionCheckpoint?> load() async {
    if (!await _file.exists()) return null;
    try {
      final text = await _file.readAsString();
      final json = jsonDecode(text) as Map<String, Object?>;
      return SessionCheckpoint.fromJson(json);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Clears any persisted checkpoint.
  Future<void> clear() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }
}
