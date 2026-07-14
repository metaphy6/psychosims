import 'canonical_json.dart';

/// Focus slider: Childhood ↔ Workspace (§11).
///
/// Typed enum so the deterministic core consumes a token, never free text.
enum FocusAxis {
  childhood,
  balanced,
  workspace,
}

extension FocusAxisJson on FocusAxis {
  String toJson() => name;
  static FocusAxis fromJson(String value) => FocusAxis.values.byName(value);
}

/// Emotional delivery slider: Warm ↔ Objective (§11).
///
/// Typed enum so the deterministic core consumes a token, never free text.
enum EmotionalDelivery {
  warm,
  balanced,
  objective,
}

extension EmotionalDeliveryJson on EmotionalDelivery {
  String toJson() => name;
  static EmotionalDelivery fromJson(String value) =>
      EmotionalDelivery.values.byName(value);
}

/// Pre-session controller settings that feed the deterministic core.
///
/// These are the §11 sliders: Childhood↔Workspace and Warm↔Objective. They
/// are typed core inputs (never free text) and are captured in the session
/// start-state so the Phase 3.3 validator can bound-check them.
class TherapyControllerSettings {
  final FocusAxis focus;
  final EmotionalDelivery emotionalDelivery;

  const TherapyControllerSettings({
    this.focus = FocusAxis.balanced,
    this.emotionalDelivery = EmotionalDelivery.balanced,
  });

  Map<String, Object?> toJson() => {
        'focus': focus.toJson(),
        'emotional_delivery': emotionalDelivery.toJson(),
      };

  factory TherapyControllerSettings.fromJson(Map<String, Object?> json) {
    return TherapyControllerSettings(
      focus: FocusAxisJson.fromJson(json['focus']! as String),
      emotionalDelivery:
          EmotionalDeliveryJson.fromJson(json['emotional_delivery']! as String),
    );
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());

  @override
  bool operator ==(Object other) =>
      other is TherapyControllerSettings &&
      other.focus == focus &&
      other.emotionalDelivery == emotionalDelivery;

  @override
  int get hashCode => Object.hash(focus, emotionalDelivery);
}
