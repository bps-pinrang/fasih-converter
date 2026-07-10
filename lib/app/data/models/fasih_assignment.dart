class FasihAssignment {
  const FasihAssignment({
    required this.id,
    required this.surveyPeriodId,
    required this.regionId,
    this.wrappedDataKey,
    this.statusAlias,
  });

  final String id;
  final String surveyPeriodId;
  final String regionId;

  /// Base64-encoded AES key for GCM decryption. Null when region is unencrypted.
  final String? wrappedDataKey;
  final String? statusAlias;

  factory FasihAssignment.fromJson(Map<String, dynamic> json) {
    return FasihAssignment(
      id: json['id'] as String? ?? '',
      surveyPeriodId: json['survey_period_id'] as String? ?? '',
      regionId: json['region_id'] as String? ?? '',
      wrappedDataKey: json['wrappedDatakey'] as String?,
      statusAlias: json['assignmentStatusAlias'] as String?,
    );
  }
}
