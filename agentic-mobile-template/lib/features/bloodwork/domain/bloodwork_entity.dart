// lib/features/bloodwork/domain/bloodwork_entity.dart

/// Represents a single lab result row from wt_bloodwork_results.
///
/// [isOutOfRange] is a GENERATED ALWAYS column in Postgres — it is
/// read-only and must never be included in INSERT / UPDATE payloads.
class BloodworkEntity {
  const BloodworkEntity({
    this.id,
    required this.profileId,
    required this.testName,
    required this.valueNum,
    required this.unit,
    this.referenceRangeLow,
    this.referenceRangeHigh,
    this.isOutOfRange = false,
    required this.testDate,
    this.notes,
    this.isSensitive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory BloodworkEntity.fromJson(Map<String, dynamic> json) {
    return BloodworkEntity(
      id: json['id'] as String?,
      profileId: json['profile_id'] as String,
      testName: json['test_name'] as String,
      valueNum: (json['value_num'] as num).toDouble(),
      unit: json['unit'] as String,
      referenceRangeLow: json['reference_range_low'] != null
          ? (json['reference_range_low'] as num).toDouble()
          : null,
      referenceRangeHigh: json['reference_range_high'] != null
          ? (json['reference_range_high'] as num).toDouble()
          : null,
      // Computed column — Supabase returns it on SELECT
      isOutOfRange: json['is_out_of_range'] as bool? ?? false,
      testDate: DateTime.parse(json['test_date'] as String),
      notes: json['notes'] as String?,
      isSensitive: json['is_sensitive'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// UUID primary key (null before first save).
  final String? id;
  final String profileId;
  final String testName;

  /// The numeric lab value (e.g. 15.3).
  final double valueNum;

  /// Unit string matching the test definition (e.g. "nmol/L").
  final String unit;

  /// Lower bound of the normal reference range (inclusive).  Null means
  /// no lower limit is defined (e.g. "HDL > 1.0" has no meaningful low).
  final double? referenceRangeLow;

  /// Upper bound of the normal reference range (inclusive).  Null means
  /// no upper limit is defined (e.g. "Testosterone > 8.64" with no cap
  /// for health purposes).
  final double? referenceRangeHigh;

  /// Read-only computed column — true when value is outside the reference
  /// range.  Managed entirely by Postgres; excluded from write payloads.
  final bool isOutOfRange;

  final DateTime testDate;
  final String? notes;

  /// Marks the row for export exclusion and AI context stripping.
  final bool isSensitive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ─── Convenience helpers ────────────────────────────────────────────────

  /// Returns true when the value is within 10 % of either range boundary
  /// but still inside the range — used for amber "borderline" colouring.
  bool get isBorderline {
    if (isOutOfRange) return false;

    if (referenceRangeLow != null) {
      final rangeSize = (referenceRangeHigh ?? referenceRangeLow!) -
          referenceRangeLow!;
      final threshold = rangeSize.abs() * 0.10;
      if ((valueNum - referenceRangeLow!) < threshold) return true;
    }

    if (referenceRangeHigh != null) {
      final rangeSize = referenceRangeHigh! -
          (referenceRangeLow ?? referenceRangeHigh!);
      final threshold = rangeSize.abs() * 0.10;
      if ((referenceRangeHigh! - valueNum) < threshold) return true;
    }

    return false;
  }

  // ─── Serialisation ──────────────────────────────────────────────────────

  /// Full map for INSERT / UPDATE — deliberately omits [isOutOfRange]
  /// because it is a GENERATED ALWAYS column that Postgres manages.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'profile_id': profileId,
      'test_name': testName,
      'value_num': valueNum,
      'unit': unit,
      if (referenceRangeLow != null) 'reference_range_low': referenceRangeLow,
      if (referenceRangeHigh != null)
        'reference_range_high': referenceRangeHigh,
      'test_date': testDate.toIso8601String().substring(0, 10),
      if (notes != null) 'notes': notes,
      'is_sensitive': isSensitive,
    };
  }

  BloodworkEntity copyWith({
    String? id,
    String? profileId,
    String? testName,
    double? valueNum,
    String? unit,
    double? referenceRangeLow,
    double? referenceRangeHigh,
    bool? isOutOfRange,
    DateTime? testDate,
    String? notes,
    bool? isSensitive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BloodworkEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      testName: testName ?? this.testName,
      valueNum: valueNum ?? this.valueNum,
      unit: unit ?? this.unit,
      referenceRangeLow: referenceRangeLow ?? this.referenceRangeLow,
      referenceRangeHigh: referenceRangeHigh ?? this.referenceRangeHigh,
      isOutOfRange: isOutOfRange ?? this.isOutOfRange,
      testDate: testDate ?? this.testDate,
      notes: notes ?? this.notes,
      isSensitive: isSensitive ?? this.isSensitive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
