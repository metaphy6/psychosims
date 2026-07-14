import 'package:psychemas/psychemas.dart';

/// Immutable patient simulation state.
///
/// The deterministic core owns this state. It carries only bounded integers so
/// that outcomes replay byte-identically across platforms (0.8 determinism
/// contract). No floats, no wall-clock, no ambient randomness here.
class SimState {
  final int seed;
  final int turn;
  final Map<String, int> axes;

  const SimState({required this.seed, this.turn = 0, required this.axes});

  SimState copyWith({int? turn, Map<String, int>? axes}) {
    return SimState(
      seed: seed,
      turn: turn ?? this.turn,
      axes: axes ?? Map.unmodifiable(this.axes),
    );
  }

  /// Returns a deterministic snapshot suitable for serialization/receipts.
  Map<String, Object?> toJson() => {
        'seed': seed,
        'turn': turn,
        'axes': Map<String, int>.from(axes),
      };

  factory SimState.fromJson(Map<String, Object?> json) {
    return SimState(
      seed: json['seed']! as int,
      turn: json['turn']! as int,
      axes: (json['axes']! as Map<String, dynamic>).cast<String, int>(),
    );
  }

  /// Encodes this state to canonical UTF-8 bytes.
  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());
}
