/// Entity representing a reminder/notification
class ReminderEntity {
  final String id;
  final String profileId;
  final String module; // 'supplements', 'meals', 'workouts', 'custom'
  final String title;
  final String body;
  final DateTime remindAt;
  final String? repeatRule; // 'once', 'daily', 'weekly', 'monthly'
  final bool isActive;
  final DateTime? lastTriggeredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReminderEntity({
    required this.id,
    required this.profileId,
    required this.module,
    required this.title,
    required this.body,
    required this.remindAt,
    this.repeatRule,
    this.isActive = true,
    this.lastTriggeredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a copy with modified fields
  ReminderEntity copyWith({
    String? id,
    String? profileId,
    String? module,
    String? title,
    String? body,
    DateTime? remindAt,
    String? repeatRule,
    bool? isActive,
    DateTime? lastTriggeredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReminderEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      module: module ?? this.module,
      title: title ?? this.title,
      body: body ?? this.body,
      remindAt: remindAt ?? this.remindAt,
      repeatRule: repeatRule ?? this.repeatRule,
      isActive: isActive ?? this.isActive,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Creates from JSON (Supabase response)
  factory ReminderEntity.fromJson(Map<String, dynamic> json) {
    return ReminderEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      module: json['module'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      remindAt: DateTime.parse(json['remind_at'] as String),
      repeatRule: json['repeat_rule'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      lastTriggeredAt: json['last_triggered_at'] != null
          ? DateTime.parse(json['last_triggered_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converts to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'module': module,
      'title': title,
      'body': body,
      'remind_at': remindAt.toIso8601String(),
      'repeat_rule': repeatRule,
      'is_active': isActive,
      'last_triggered_at': lastTriggeredAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Calculates next reminder time based on repeat rule
  DateTime? getNextReminderTime() {
    if (repeatRule == null || repeatRule == 'once') {
      return null;
    }

    final now = DateTime.now();
    DateTime nextTime = remindAt;

    switch (repeatRule) {
      case 'daily':
        while (nextTime.isBefore(now)) {
          nextTime = nextTime.add(const Duration(days: 1));
        }
        break;
      case 'weekly':
        while (nextTime.isBefore(now)) {
          nextTime = nextTime.add(const Duration(days: 7));
        }
        break;
      case 'monthly':
        while (nextTime.isBefore(now)) {
          nextTime = DateTime(
            nextTime.year,
            nextTime.month + 1,
            nextTime.day,
            nextTime.hour,
            nextTime.minute,
          );
        }
        break;
      default:
        return null;
    }

    return nextTime;
  }

  @override
  String toString() {
    return 'ReminderEntity(id: $id, module: $module, title: $title, remindAt: $remindAt, repeatRule: $repeatRule, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ReminderEntity &&
        other.id == id &&
        other.profileId == profileId &&
        other.module == module &&
        other.title == title &&
        other.body == body &&
        other.remindAt == remindAt &&
        other.repeatRule == repeatRule &&
        other.isActive == isActive &&
        other.lastTriggeredAt == lastTriggeredAt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      profileId,
      module,
      title,
      body,
      remindAt,
      repeatRule,
      isActive,
      lastTriggeredAt,
      createdAt,
      updatedAt,
    );
  }
}
