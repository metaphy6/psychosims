import 'ruleset_profile.dart';

/// Pure, deterministic per-turn seed derivation.
///
/// Mixes only stable inputs (case id, turn index, ordered action, root session
/// seed) using fixed-width wrapping arithmetic and a stable string hash. Never
/// uses [Clock.nowMillis] and never uses [String.hashCode] (Dart randomizes the
/// latter per isolate), so a replay at any time, on any isolate, on any
/// architecture reproduces the identical stream.
int deriveTurnSeed({
  required String caseId,
  required int turnIndex,
  required String actionName,
  required int rootSeed,
  required RulesetProfile profile,
}) {
  // Stable string hash: process UTF-16 code units deterministically.
  var caseHash = _foldString(caseId);
  var actionHash = _foldString(actionName);

  var seed = rootSeed & _mask64;
  seed = _mix(seed, caseHash);
  seed = _mix(seed, turnIndex & _mask64);
  seed = _mix(seed, actionHash);
  seed = _mix(seed, profile.splitMixGamma);
  return seed;
}

const int _mask64 = 0xFFFFFFFFFFFFFFFF;

int _mix(int value, int delta) {
  // MurmurHash-style avalanche in 64-bit wrapping arithmetic.
  var v = (value + delta) & _mask64;
  v ^= (v >> 33);
  v = (v * 0xff51afd7ed558ccd) & _mask64;
  v ^= (v >> 33);
  v = (v * 0xc4ceb9fe1a85ec53) & _mask64;
  v ^= (v >> 33);
  return v;
}

int _foldString(String value) {
  var h = 0xcbf29ce484222325; // FNV-1a 64-bit offset basis.
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    h ^= unit;
    h = (h * 0x100000001b3) & _mask64;
  }
  return h;
}
