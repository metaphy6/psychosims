import 'canonical_json.dart';
import 'card.dart';

/// Context-fit band for a card play (§16).
///
/// Owned by C-11; the cut-points that map state to a fit are C-4 numbers.
enum ContextFit {
  /// Card signature matches current state: narrow favourable band.
  aligned,

  /// Partial match: wider, less favourable band.
  partial,

  /// Signature mismatched: wide unfavourable band.
  mismatched,
}

extension ContextFitJson on ContextFit {
  String toJson() => name;
  static ContextFit fromJson(String value) => ContextFit.values.byName(value);
}

/// A single structured, deterministic state change.
///
/// Carries the [rulesetVersion] that produced it so an outcome remains
/// replayable against the exact rules that created it (local precursor to the
/// Phase 3.3 receipt shape). Each delta records the card that produced it so
/// receipts are machine-checkable (2.1).
class StructuredDelta {
  final String rulesetVersion;
  final String axis;
  final int deltaMillis;
  final String reasonKey;

  /// Card that produced this delta.
  final CardType cardType;

  /// Signature of the card that produced this delta.
  final CardSignature cardSignature;

  /// Computed context-fit band for the play that produced this delta.
  final ContextFit contextFit;

  const StructuredDelta({
    required this.rulesetVersion,
    required this.axis,
    required this.deltaMillis,
    required this.reasonKey,
    required this.cardType,
    required this.cardSignature,
    required this.contextFit,
  });

  Map<String, Object?> toJson() => {
        'ruleset_version': rulesetVersion,
        'axis': axis,
        'delta_millis': deltaMillis,
        'reason_key': reasonKey,
        'card_type': cardType.toJson(),
        'card_signature': cardSignature.toJson(),
        'context_fit': contextFit.toJson(),
      };

  factory StructuredDelta.fromJson(Map<String, Object?> json) {
    return StructuredDelta(
      rulesetVersion: json['ruleset_version']! as String,
      axis: json['axis']! as String,
      deltaMillis: (json['delta_millis'] ?? json['deltaMillis'])! as int,
      reasonKey: (json['reason_key'] ?? json['reasonKey'])! as String,
      cardType: CardTypeJson.fromJson(json['card_type']! as String),
      cardSignature:
          CardSignatureJson.fromJson(json['card_signature']! as String),
      contextFit: ContextFitJson.fromJson(json['context_fit']! as String),
    );
  }

  /// Encodes this delta to canonical UTF-8 bytes.
  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());

  @override
  bool operator ==(Object other) =>
      other is StructuredDelta &&
      other.rulesetVersion == rulesetVersion &&
      other.axis == axis &&
      other.deltaMillis == deltaMillis &&
      other.reasonKey == reasonKey &&
      other.cardType == cardType &&
      other.cardSignature == cardSignature &&
      other.contextFit == contextFit;

  @override
  int get hashCode => Object.hash(rulesetVersion, axis, deltaMillis, reasonKey,
      cardType, cardSignature, contextFit);
}
