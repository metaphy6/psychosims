import 'package:test/test.dart';

import '../tool/local_http_harness.dart';

Map<String, String> fixture() => {
      'PSY_W3_API_URL': 'http://127.0.0.1:45678',
      'PSY_W3_ID_TOKEN': 'public-local-w3-fixture',
      'PSY_W3_NONCE': 'public-local-w3-nonce',
      'PSY_W3_CASE_ID': 'siege.brumosis',
      'PSY_W3_MANIFEST_PATH':
          '/workspace/content/manifests/siege_brumosis.json',
      'PSY_W3_EXPECT_CERTIFIED': '1',
    };

void main() {
  test('returns only a frozen snapshot of the six allowed values', () {
    final input = fixture()..['UNRELATED_SECRET'] = 'not-for-the-harness';
    final result = loadLocalHttpHarnessEnvironment(environment: input);
    expect(result, fixture());
    input['PSY_W3_CASE_ID'] = 'changed';
    expect(result['PSY_W3_CASE_ID'], 'siege.brumosis');
    expect(() => result['PSY_W3_CASE_ID'] = 'changed', throwsUnsupportedError);
  });

  test('requires every variable, including explicit certification mode', () {
    for (final key in fixture().keys) {
      final input = fixture()..remove(key);
      expect(() => loadLocalHttpHarnessEnvironment(environment: input),
          throwsFormatException,
          reason: key);
    }
  });

  test('rejects empty, excessive, padded and control-character values', () {
    for (final key in fixture().keys) {
      for (final value in ['', ' ', ' padded ', 'line\nbreak', 'a' * 4097]) {
        final input = fixture()..[key] = value;
        expect(() => loadLocalHttpHarnessEnvironment(environment: input),
            throwsFormatException,
            reason: key);
      }
    }
  });

  test('accepts only plain loopback HTTP origins with valid ports', () {
    for (final origin in [
      'http://127.0.0.1:1',
      'http://localhost:65535/',
      'http://[::1]:45678',
    ]) {
      final input = fixture()..['PSY_W3_API_URL'] = origin;
      expect(
          loadLocalHttpHarnessEnvironment(environment: input)['PSY_W3_API_URL'],
          origin);
    }
    for (final origin in [
      'https://127.0.0.1:45678',
      'http://external.example:45678',
      'http://127.0.0.2:45678',
      'http://127.1:45678',
      'http://localhost.external.example:45678',
      'http://user@127.0.0.1:45678',
      'http://127.0.0.1:45678?token=secret',
      'http://127.0.0.1:45678?',
      'http://127.0.0.1:45678#fragment',
      'http://127.0.0.1:45678/path',
      'http://127.0.0.1:0',
      'http://127.0.0.1:65536',
      'http://127.0.0.1:invalid',
    ]) {
      final input = fixture()..['PSY_W3_API_URL'] = origin;
      expect(() => loadLocalHttpHarnessEnvironment(environment: input),
          throwsFormatException,
          reason: origin);
    }
  });

  test('requires literal mode zero or one', () {
    for (final mode in ['0', '1']) {
      expect(
          loadLocalHttpHarnessEnvironment(
              environment: fixture()
                ..['PSY_W3_EXPECT_CERTIFIED'] =
                    mode)['PSY_W3_EXPECT_CERTIFIED'],
          mode);
    }
    for (final mode in ['true', 'false', '2', '01', '0.0']) {
      expect(
          () => loadLocalHttpHarnessEnvironment(
              environment: fixture()..['PSY_W3_EXPECT_CERTIFIED'] = mode),
          throwsFormatException);
    }
  });

  test(
      'refuses nonpublic credentials and never includes their values in errors',
      () {
    for (final key in ['PSY_W3_ID_TOKEN', 'PSY_W3_NONCE']) {
      const private = 'private-credential-sentinel';
      final input = fixture()..[key] = private;
      expect(
          () => loadLocalHttpHarnessEnvironment(environment: input),
          throwsA(isA<FormatException>().having((error) => error.toString(),
              'sanitized', isNot(contains(private)))));
    }
  });
}
