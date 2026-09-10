import 'dart:io';

/// Test/tool-only configuration for the disposable local Go/PostgreSQL harness.
/// Kept outside lib/ so neither production configuration nor certified core
/// artifacts acquire a dependency on test credentials or environment variables.
Map<String, String> loadLocalHttpHarnessEnvironment({
  Map<String, String>? environment,
}) {
  final source = environment ?? Platform.environment;
  const limits = {
    'PSY_W3_API_URL': 256,
    'PSY_W3_ID_TOKEN': 128,
    'PSY_W3_NONCE': 128,
    'PSY_W3_CASE_ID': 128,
    'PSY_W3_MANIFEST_PATH': 4096,
    'PSY_W3_EXPECT_CERTIFIED': 1,
  };
  final result = <String, String>{};
  for (final entry in limits.entries) {
    final value = source[entry.key];
    if (value == null ||
        value.isEmpty ||
        value.length > entry.value ||
        value.trim() != value ||
        value.runes.any((rune) => rune < 32 || rune == 127)) {
      throw FormatException('Invalid local HTTP harness value: ${entry.key}');
    }
    result[entry.key] = value;
  }
  if (result['PSY_W3_ID_TOKEN'] != 'public-local-w3-fixture' ||
      result['PSY_W3_NONCE'] != 'public-local-w3-nonce') {
    throw const FormatException('Local HTTP harness requires public fixtures');
  }
  if (!const {'0', '1'}.contains(result['PSY_W3_EXPECT_CERTIFIED'])) {
    throw const FormatException('Local HTTP harness mode must be zero or one');
  }
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$')
      .hasMatch(result['PSY_W3_CASE_ID']!)) {
    throw const FormatException('Invalid local HTTP harness case identifier');
  }
  // Match the raw origin as well as Uri fields: parsing must not normalize
  // shorthand IPs, encoded hosts, credentials or an unexpected route into trust.
  final raw = result['PSY_W3_API_URL']!;
  final allowedOrigin = RegExp(
      r'^http://(?:127\.0\.0\.1|localhost|\[::1\])(?::[1-9][0-9]{0,4})?/?$');
  if (!allowedOrigin.hasMatch(raw)) {
    throw const FormatException(
        'Local HTTP harness requires a loopback origin');
  }
  final origin = Uri.tryParse(raw);
  if (origin == null ||
      origin.scheme != 'http' ||
      !origin.hasAuthority ||
      origin.userInfo.isNotEmpty ||
      origin.hasQuery ||
      origin.hasFragment ||
      (origin.path.isNotEmpty && origin.path != '/') ||
      origin.port < 1 ||
      origin.port > 65535) {
    throw const FormatException('Invalid local HTTP harness origin');
  }
  return Map<String, String>.unmodifiable(result);
}
