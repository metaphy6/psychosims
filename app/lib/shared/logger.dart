import 'dart:convert';
import 'dart:developer' as developer;

/// Cross-stack logger emitting the canonical log-line schema defined in
/// `docs/code/LOGGING.md`.
///
/// The logger is intentionally small and dependency-free. The rendering mode
/// (text vs JSON) and minimum level are supplied by the config authority;
/// until config is available it defaults to dev text and [LogLevel.info].
enum LogLevel {
  debug('debug', '🔍'),
  info('info', 'ℹ️'),
  success('success', '✅'),
  warn('warn', '⚠️'),
  error('error', '❌'),
  fatal('fatal', '🛑');

  const LogLevel(this.name, this.emoji);
  final String name;
  final String emoji;

  bool operator >=(LogLevel other) => index >= other.index;
}

enum ErrorKind { user, system, external, offline }

class PsyLog {
  PsyLog({
    this.minLevel = LogLevel.info,
    this.jsonMode = false,
    this.correlationId = 'none',
  });

  final LogLevel minLevel;
  final bool jsonMode;
  final String correlationId;

  void log(
    LogLevel level,
    String scope,
    String event, {
    Map<String, Object?> kv = const {},
    ErrorKind? errorKind,
    String? message,
  }) {
    if (level.index < minLevel.index) return;

    final timestamp = DateTime.now().toUtc().toIso8601String();
    final safeScope = scope.toLowerCase();
    final safeEvent = event.toLowerCase();

    if (jsonMode) {
      final payload = <String, Object?>{
        'ts': timestamp,
        'level': level.name,
        'scope': safeScope,
        'event': safeEvent,
        'correlation_id': correlationId,
        if (kv.isNotEmpty) 'kv': kv,
        if (errorKind != null) 'error_kind': errorKind.name,
      };
      _emit(jsonEncode(payload));
    } else {
      final sb = StringBuffer()
        ..write('${level.emoji} ${level.name.toUpperCase().padRight(7)} ')
        ..write('[$timestamp] ')
        ..write('[$safeScope] ')
        ..write(safeEvent.padRight(24))
        ..write(' corr=$correlationId');
      if (kv.isNotEmpty) {
        sb.write(
            ' | ${kv.entries.map((e) => '${e.key}=${e.value}').join(' ')}');
      }
      if (errorKind != null) sb.write(' | error_kind=${errorKind.name}');
      if (message != null) sb.write(' | $message');
      _emit(sb.toString());
    }
  }

  void debug(String scope, String event,
          {Map<String, Object?> kv = const {}, String? message}) =>
      log(LogLevel.debug, scope, event, kv: kv, message: message);
  void info(String scope, String event,
          {Map<String, Object?> kv = const {}, String? message}) =>
      log(LogLevel.info, scope, event, kv: kv, message: message);
  void success(String scope, String event,
          {Map<String, Object?> kv = const {}, String? message}) =>
      log(LogLevel.success, scope, event, kv: kv, message: message);
  void warn(String scope, String event,
          {Map<String, Object?> kv = const {}, String? message}) =>
      log(LogLevel.warn, scope, event, kv: kv, message: message);
  void error(String scope, String event,
          {Map<String, Object?> kv = const {},
          ErrorKind? errorKind,
          String? message}) =>
      log(LogLevel.error, scope, event,
          kv: kv, errorKind: errorKind ?? ErrorKind.system, message: message);
  void fatal(String scope, String event,
          {Map<String, Object?> kv = const {},
          ErrorKind? errorKind,
          String? message}) =>
      log(LogLevel.fatal, scope, event,
          kv: kv, errorKind: errorKind ?? ErrorKind.system, message: message);

  void _emit(String line) {
    // Use developer.log in debug builds to keep output inspectable;
    // in release/JSON mode we still avoid raw `print`.
    developer.log(line);
  }
}
