/// Local, offline case lifecycle state machine.
///
/// This is the single-owner precursor to the server-arbitrated lifecycle in
/// C-8 (PATIENT-LIFECYCLE.md). The same states and transitions are enforced
/// locally so the shape does not change when Phase 3.6 adds ownership
/// arbitration.
enum CaseLifecycle {
  /// Case has been accepted but treatment has not yet started.
  open,

  /// Active treatment; at least one turn has resolved.
  inTreatment,

  /// Crisis branch: temporarily frozen (derangement referral / asylum).
  crisis,

  /// Successful cure; terminal positive state.
  cured,

  /// Player abandoned the case; terminal negative state.
  abandoned,

  /// Unrecoverable hard failure; terminal negative state.
  hardFailed,

  /// Case retired from the live pool (offline archive).
  archived,
}

extension CaseLifecycleJson on CaseLifecycle {
  String toJson() => name;
  static CaseLifecycle fromJson(String value) =>
      CaseLifecycle.values.byName(value);
}
