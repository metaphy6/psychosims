/// Immutable patient simulation state.
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
}
