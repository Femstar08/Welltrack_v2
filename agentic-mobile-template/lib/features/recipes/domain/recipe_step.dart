class RecipeStep {

  const RecipeStep({
    required this.id,
    required this.stepNumber,
    required this.instruction,
    this.durationMinutes,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      id: json['id'] as String,
      stepNumber: json['step_number'] as int,
      instruction: json['instruction'] as String,
      durationMinutes: json['duration_minutes'] as int?,
    );
  }
  final String id;
  final int stepNumber;
  final String instruction;
  final int? durationMinutes;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'step_number': stepNumber,
      'instruction': instruction,
      'duration_minutes': durationMinutes,
    };
  }

  RecipeStep copyWith({
    String? instruction,
    int? durationMinutes,
  }) {
    return RecipeStep(
      id: id,
      stepNumber: stepNumber,
      instruction: instruction ?? this.instruction,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  bool get isTimed => durationMinutes != null && durationMinutes! > 0;
}
