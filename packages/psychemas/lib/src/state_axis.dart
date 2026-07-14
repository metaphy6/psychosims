/// A typed, enumerable state variable that a [StructuredDelta] can mutate.
///
/// Replaces the PoC free-text `axis` string so deltas are type-checked end to
/// end and receipts remain machine-checkable.
enum StateAxis {
  trust,
  agitation,
  activeDefense,
  trauma,
  freezeTurns,
  sessionProgress,
  medicationTolerance,
  medicationDependency,
}

extension StateAxisJson on StateAxis {
  String toJson() => name;
  static StateAxis fromJson(String value) => StateAxis.values.byName(value);
}
