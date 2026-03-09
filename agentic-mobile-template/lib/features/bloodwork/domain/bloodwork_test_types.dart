// lib/features/bloodwork/domain/bloodwork_test_types.dart

/// Category grouping for display tabs on the bloodwork screen.
enum BloodworkCategory {
  hormones('Hormones'),
  metabolic('Metabolic'),
  cardiovascular('Cardiovascular'),
  vitamins('Vitamins & Thyroid');

  const BloodworkCategory(this.displayName);

  final String displayName;
}

/// Immutable definition of a recognised lab test including its reference range
/// and the unit it is measured in.  These are used to pre-fill the add-result
/// bottom sheet and to gate out-of-range colour coding.
class BloodworkTestType {
  const BloodworkTestType({
    required this.name,
    required this.unit,
    this.referenceLow,
    this.referenceHigh,
    required this.category,
    this.rangeNote,
  });

  /// Display name that also becomes the [testName] stored in Supabase.
  final String name;

  /// Unit string (e.g. "nmol/L", "mmol/L", "mmHg", "mmol/mol").
  final String unit;

  /// Lower bound of the normal reference range.  Null = no lower bound
  /// (e.g. HDL — higher is better with no dangerous floor).
  final double? referenceLow;

  /// Upper bound of the normal reference range.  Null = no upper bound.
  final double? referenceHigh;

  final BloodworkCategory category;

  /// Optional human-readable note shown in the UI (e.g. "> 1.0 preferred").
  final String? rangeNote;

  // ─── Pre-loaded catalogue ──────────────────────────────────────────────

  /// Full list of supported test definitions.  Custom test names not in this
  /// list can still be entered as free-text.
  static const List<BloodworkTestType> catalogue = [
    // ── Hormones ────────────────────────────────────────────
    BloodworkTestType(
      name: 'Testosterone',
      unit: 'nmol/L',
      referenceLow: 8.64,
      referenceHigh: 29.0,
      category: BloodworkCategory.hormones,
    ),
    BloodworkTestType(
      name: 'SHBG',
      unit: 'nmol/L',
      referenceLow: 18.0,
      referenceHigh: 54.0,
      category: BloodworkCategory.hormones,
    ),
    BloodworkTestType(
      name: 'Oestradiol',
      unit: 'pmol/L',
      referenceLow: 41.0,
      referenceHigh: 159.0,
      category: BloodworkCategory.hormones,
    ),

    // ── Metabolic ────────────────────────────────────────────
    BloodworkTestType(
      name: 'Glucose fasting',
      unit: 'mmol/L',
      referenceLow: 3.9,
      referenceHigh: 5.6,
      category: BloodworkCategory.metabolic,
    ),
    BloodworkTestType(
      name: 'HbA1c',
      unit: 'mmol/mol',
      referenceLow: 20.0,
      referenceHigh: 42.0,
      category: BloodworkCategory.metabolic,
    ),

    // ── Cardiovascular ────────────────────────────────────────
    BloodworkTestType(
      name: 'Total Cholesterol',
      unit: 'mmol/L',
      referenceLow: null,
      referenceHigh: 5.0,
      category: BloodworkCategory.cardiovascular,
      rangeNote: '< 5.0 preferred',
    ),
    BloodworkTestType(
      name: 'HDL',
      unit: 'mmol/L',
      referenceLow: 1.0,
      referenceHigh: null,
      category: BloodworkCategory.cardiovascular,
      rangeNote: '> 1.0 preferred',
    ),
    BloodworkTestType(
      name: 'LDL',
      unit: 'mmol/L',
      referenceLow: null,
      referenceHigh: 3.0,
      category: BloodworkCategory.cardiovascular,
      rangeNote: '< 3.0 preferred',
    ),
    BloodworkTestType(
      name: 'BP Systolic',
      unit: 'mmHg',
      referenceLow: 90.0,
      referenceHigh: 120.0,
      category: BloodworkCategory.cardiovascular,
    ),
    BloodworkTestType(
      name: 'BP Diastolic',
      unit: 'mmHg',
      referenceLow: 60.0,
      referenceHigh: 80.0,
      category: BloodworkCategory.cardiovascular,
    ),

    // ── Vitamins & Thyroid ────────────────────────────────────
    BloodworkTestType(
      name: 'TSH',
      unit: 'mIU/L',
      referenceLow: 0.27,
      referenceHigh: 4.20,
      category: BloodworkCategory.vitamins,
    ),
    BloodworkTestType(
      name: 'Vitamin D',
      unit: 'nmol/L',
      referenceLow: 50.0,
      referenceHigh: 175.0,
      category: BloodworkCategory.vitamins,
    ),
  ];

  /// Returns tests grouped by category in a stable display order.
  static Map<BloodworkCategory, List<BloodworkTestType>> get byCategory {
    final result = <BloodworkCategory, List<BloodworkTestType>>{};
    for (final category in BloodworkCategory.values) {
      result[category] =
          catalogue.where((t) => t.category == category).toList();
    }
    return result;
  }

  /// Looks up a test definition by its name.  Returns null for custom tests.
  static BloodworkTestType? findByName(String name) {
    try {
      return catalogue.firstWhere(
        (t) => t.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
