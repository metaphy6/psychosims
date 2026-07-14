/// Active recovery or operational mode for a clinic profile (§14, §23).
enum RecoveryMode {
  /// Normal operations.
  normal,

  /// Discount Practice: high-volume, low-fee, reduced-XP recovery path.
  discountPractice,

  /// Academic Sabbatical: clinic closed, study points restore reputation.
  academicSabbatical,
}

extension RecoveryModeJson on RecoveryMode {
  String toJson() => name;

  static RecoveryMode fromJson(String value) =>
      RecoveryMode.values.byName(value);
}
