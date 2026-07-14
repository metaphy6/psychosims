import 'canonical_json.dart';
import 'card_library.dart';
import 'loadout.dart';
import 'therapy_controller.dart';

/// Immutable snapshot of everything that defines a session's starting
/// conditions.
///
/// Captures the equipped loadout, card ownership, controller settings, and
/// the initial [SimState] so a receipt can be replayed and a Phase 3.3
/// validator can reject plays that reference cards not present here.
class SessionStartState {
  final Loadout loadout;
  final CardLibrary library;
  final TherapyControllerSettings controllers;
  final Map<String, int> initialAxes;
  final int rootSeed;

  const SessionStartState({
    required this.loadout,
    required this.library,
    required this.controllers,
    required this.initialAxes,
    required this.rootSeed,
  });

  Map<String, Object?> toJson() => {
        'loadout': loadout.toJson(),
        'library': library.toJson(),
        'controllers': controllers.toJson(),
        'initial_axes': initialAxes,
        'root_seed': rootSeed,
      };

  factory SessionStartState.fromJson(Map<String, Object?> json) {
    return SessionStartState(
      loadout: Loadout.fromJson(json['loadout']! as Map<String, Object?>),
      library: CardLibrary.fromJson(json['library']! as Map<String, Object?>),
      controllers: TherapyControllerSettings.fromJson(
          json['controllers']! as Map<String, Object?>),
      initialAxes:
          (json['initial_axes']! as Map<String, dynamic>).cast<String, int>(),
      rootSeed: json['root_seed']! as int,
    );
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());

  @override
  bool operator ==(Object other) =>
      other is SessionStartState &&
      other.loadout == loadout &&
      other.library == library &&
      other.controllers == controllers &&
      _mapEquals(other.initialAxes, initialAxes) &&
      other.rootSeed == rootSeed;

  @override
  int get hashCode => Object.hash(
        loadout,
        library,
        controllers,
        Object.hashAll(initialAxes.entries),
        rootSeed,
      );

  static bool _mapEquals(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
