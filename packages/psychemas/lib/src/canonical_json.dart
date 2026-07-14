import 'dart:convert';

/// One shared canonical serializer for every `packages/` schema.
///
/// Guarantees:
/// - deterministic key sorting (lexicographic)
/// - a single `snake_case` convention for map keys
/// - stable number / string / bool / null encoding
/// - byte-identical output for the same input graph
///
/// All schema `toJson()` methods must return a graph of nested Maps/Lists
/// using snake_case keys. This encoder sorts every map and writes JSON
/// without extra whitespace so the bytes are canonical.
class CanonicalJson {
  const CanonicalJson._();

  /// Encodes [value] to canonical UTF-8 bytes.
  ///
  /// [value] must be a JSON-serializable graph of:
  /// - String
  /// - int
  /// - double (allowed only in schema boundaries, not in core economy paths)
  /// - bool
  /// - null
  /// - List<Object?>
  /// - Map<String, Object?>
  static List<int> encode(Object? value) => utf8.encode(encodeString(value));

  /// Encodes [value] to a canonical JSON string.
  static String encodeString(Object? value) => _encode(value);

  static String _encode(Object? value) {
    if (value == null) return 'null';
    if (value is String) return jsonEncode(value);
    if (value is int) return value.toString();
    if (value is double) {
      // Stable double encoding: never scientific notation for finite values
      // that have a short decimal form. JSON numbers are written literally.
      if (value.isNaN || value.isInfinite) {
        throw ArgumentError('Canonical JSON rejects non-finite doubles');
      }
      final s = value.toStringAsFixed(12);
      // Strip trailing zeros and possible trailing dot.
      var trimmed = s;
      if (trimmed.contains('.')) {
        trimmed = trimmed.replaceAll(RegExp(r'0+$'), '');
        if (trimmed.endsWith('.')) {
          trimmed = trimmed.substring(0, trimmed.length - 1);
        }
      }
      return trimmed;
    }
    if (value is bool) return value ? 'true' : 'false';
    if (value is List) {
      final buffer = StringBuffer()..write('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) buffer.write(',');
        buffer.write(_encode(value[i]));
      }
      buffer.write(']');
      return buffer.toString();
    }
    if (value is Map<String, Object?>) {
      final keys = value.keys.toList(growable: false)..sort();
      final buffer = StringBuffer()..write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) buffer.write(',');
        buffer.write('"${keys[i]}":${_encode(value[keys[i]])}');
      }
      buffer.write('}');
      return buffer.toString();
    }
    throw ArgumentError(
      'Canonical JSON cannot encode ${value.runtimeType}: $value',
    );
  }

  /// Decodes canonical UTF-8 bytes back to a JSON graph.
  ///
  /// This is a thin wrapper around [jsonDecode] and is provided so all
  /// deserialization uses the same entry point.
  static Object? decode(List<int> bytes) => jsonDecode(utf8.decode(bytes));

  /// Decodes a canonical JSON string back to a JSON graph.
  static Object? decodeString(String source) => jsonDecode(source);
}

/// Converts a camelCase identifier to snake_case.
///
/// Used by schema serializers to keep keys in the single snake_case
/// convention enforced by [CanonicalJson].
String toSnakeCase(String input) {
  return input
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (m) => '${m.group(1)}_${m.group(2)!.toLowerCase()}',
      )
      .toLowerCase();
}
