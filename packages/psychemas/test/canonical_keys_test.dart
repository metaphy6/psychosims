import 'dart:convert';
import 'package:psychemas/psychemas.dart';
import 'package:test/test.dart';

void main() {
  test('canonical keys safely roundtrip quotes slashes controls and Unicode',
      () {
    final map = {'quote"key': 1, 'back\\slash': 2, 'line\nkey': 3, 'café': 4};
    expect(jsonDecode(CanonicalJson.encodeString(map)), map);
  });
  test('escaped key cannot inject a second field or collide', () {
    final injection = {'a":1,"b': 2};
    final ordinary = {'a': 1, 'b': 2};
    expect(CanonicalJson.encodeString(injection),
        isNot(CanonicalJson.encodeString(ordinary)));
    expect(CanonicalJson.encodeString({'b': 2, 'a': 1}), '{"a":1,"b":2}');
  });
}
