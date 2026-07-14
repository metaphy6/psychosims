import 'canonical_json.dart';

/// A field node in the study-training tree.
///
/// Field keys are drawn from the fictional-taxonomy registry (0.12) and never
/// overlap with real clinical specialties.
class FieldNode {
  final String fieldKey;
  final String parentFieldKey;
  final int studyCost;
  final int subspecialtyCost;

  const FieldNode({
    required this.fieldKey,
    this.parentFieldKey = '',
    required this.studyCost,
    required this.subspecialtyCost,
  });

  Map<String, Object?> toJson() => {
        'field_key': fieldKey,
        'parent_field_key': parentFieldKey,
        'study_cost': studyCost,
        'subspecialty_cost': subspecialtyCost,
      };

  factory FieldNode.fromJson(Map<String, Object?> json) {
    return FieldNode(
      fieldKey: json['field_key']! as String,
      parentFieldKey: json['parent_field_key']! as String,
      studyCost: json['study_cost']! as int,
      subspecialtyCost: json['subspecialty_cost']! as int,
    );
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());

  @override
  bool operator ==(Object other) =>
      other is FieldNode &&
      other.fieldKey == fieldKey &&
      other.parentFieldKey == parentFieldKey &&
      other.studyCost == studyCost &&
      other.subspecialtyCost == subspecialtyCost;

  @override
  int get hashCode =>
      Object.hash(fieldKey, parentFieldKey, studyCost, subspecialtyCost);
}

/// Read-only catalogue of field-training nodes.
class FieldTrainingTree {
  final Map<String, FieldNode> _byFieldKey;

  const FieldTrainingTree._(this._byFieldKey);

  factory FieldTrainingTree(Iterable<FieldNode> nodes) {
    final map = <String, FieldNode>{};
    for (final node in nodes) {
      map[node.fieldKey] = node;
    }
    return FieldTrainingTree._(map);
  }

  static const empty = FieldTrainingTree._({});

  FieldNode? lookup(String fieldKey) => _byFieldKey[fieldKey];

  List<FieldNode> get all => _byFieldKey.values.toList();

  /// True when [fieldKey] is unlocked given [unlockedFields] and available
  /// currencies. A node with no parent is foundational and always unlockable
  /// if affordable; others require the parent field first.
  bool canUnlock({
    required String fieldKey,
    required Set<String> unlockedFields,
    required int availableStudy,
    required int availableSubspecialty,
  }) {
    final node = _byFieldKey[fieldKey];
    if (node == null) return false;
    if (node.parentFieldKey.isNotEmpty &&
        !unlockedFields.contains(node.parentFieldKey)) {
      return false;
    }
    return availableStudy >= node.studyCost &&
        availableSubspecialty >= node.subspecialtyCost;
  }

  Map<String, Object?> toJson() => {
        'nodes': all.map((n) => n.toJson()).toList(),
      };

  factory FieldTrainingTree.fromJson(Map<String, Object?> json) {
    final nodes = (json['nodes']! as List<dynamic>)
        .cast<Map<String, Object?>>()
        .map(FieldNode.fromJson);
    return FieldTrainingTree(nodes);
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());
}
