/// AI Orchestrator request/response models
/// Dart equivalents of supabase/functions/_shared/types.ts

/// Request sent to the ai-orchestrate edge function
class AiOrchestrateRequest {
  final String userId;
  final String profileId;
  final String? message;
  final String? workflowType;
  final Map<String, dynamic>? contextOverride;

  const AiOrchestrateRequest({
    required this.userId,
    required this.profileId,
    this.message,
    this.workflowType,
    this.contextOverride,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'profile_id': profileId,
        if (message != null) 'message': message,
        if (workflowType != null) 'workflow_type': workflowType,
        if (contextOverride != null) 'context_override': contextOverride,
      };
}

/// Response from the ai-orchestrate edge function
class AiOrchestrateResponse {
  final String assistantMessage;
  final List<AiSuggestedAction> suggestedActions;
  final List<AiDbWrite> dbWrites;
  final AiForecastUpdate? updatedForecast;
  final List<AiSafetyFlag> safetyFlags;
  final AiUsageInfo usage;

  const AiOrchestrateResponse({
    required this.assistantMessage,
    required this.suggestedActions,
    required this.dbWrites,
    this.updatedForecast,
    required this.safetyFlags,
    required this.usage,
  });

  factory AiOrchestrateResponse.fromJson(Map<String, dynamic> json) {
    return AiOrchestrateResponse(
      assistantMessage: json['assistant_message'] as String? ?? '',
      suggestedActions: (json['suggested_actions'] as List<dynamic>?)
              ?.map((e) =>
                  AiSuggestedAction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      dbWrites: (json['db_writes'] as List<dynamic>?)
              ?.map((e) => AiDbWrite.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      updatedForecast: json['updated_forecast'] != null
          ? AiForecastUpdate.fromJson(
              json['updated_forecast'] as Map<String, dynamic>)
          : null,
      safetyFlags: (json['safety_flags'] as List<dynamic>?)
              ?.map(
                  (e) => AiSafetyFlag.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      usage: AiUsageInfo.fromJson(
          json['usage'] as Map<String, dynamic>? ?? {}),
    );
  }

  /// Whether any safety flag blocks the response
  bool get isBlocked => safetyFlags.any((f) => f.blocked);
}

/// An action the AI suggests the user can take
class AiSuggestedAction {
  final String actionType;
  final String label;
  final Map<String, dynamic> payload;

  const AiSuggestedAction({
    required this.actionType,
    required this.label,
    required this.payload,
  });

  factory AiSuggestedAction.fromJson(Map<String, dynamic> json) {
    return AiSuggestedAction(
      actionType: json['action_type'] as String? ?? '',
      label: json['label'] as String? ?? '',
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// A database write the AI wants to execute
class AiDbWrite {
  final String table;
  final String operation;
  final Map<String, dynamic> data;
  final bool dryRun;

  const AiDbWrite({
    required this.table,
    required this.operation,
    required this.data,
    required this.dryRun,
  });

  factory AiDbWrite.fromJson(Map<String, dynamic> json) {
    return AiDbWrite(
      table: json['table'] as String? ?? '',
      operation: json['operation'] as String? ?? 'insert',
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      dryRun: json['dry_run'] as bool? ?? true,
    );
  }
}

/// A forecast update from the AI
class AiForecastUpdate {
  final String goalId;
  final String newExpectedDate;
  final double confidence;
  final String explanation;

  const AiForecastUpdate({
    required this.goalId,
    required this.newExpectedDate,
    required this.confidence,
    required this.explanation,
  });

  factory AiForecastUpdate.fromJson(Map<String, dynamic> json) {
    return AiForecastUpdate(
      goalId: json['goal_id'] as String? ?? '',
      newExpectedDate: json['new_expected_date'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

/// A safety flag from the AI validation layer
class AiSafetyFlag {
  final String type;
  final String message;
  final bool blocked;

  const AiSafetyFlag({
    required this.type,
    required this.message,
    required this.blocked,
  });

  factory AiSafetyFlag.fromJson(Map<String, dynamic> json) {
    return AiSafetyFlag(
      type: json['type'] as String? ?? '',
      message: json['message'] as String? ?? '',
      blocked: json['blocked'] as bool? ?? false,
    );
  }
}

/// AI usage metering info returned with every response
class AiUsageInfo {
  final int callsUsed;
  final int callsLimit;
  final int tokensUsed;
  final int tokensLimit;

  const AiUsageInfo({
    required this.callsUsed,
    required this.callsLimit,
    required this.tokensUsed,
    required this.tokensLimit,
  });

  factory AiUsageInfo.fromJson(Map<String, dynamic> json) {
    return AiUsageInfo(
      callsUsed: json['calls_used'] as int? ?? 0,
      callsLimit: json['calls_limit'] as int? ?? 0,
      tokensUsed: json['tokens_used'] as int? ?? 0,
      tokensLimit: json['tokens_limit'] as int? ?? 0,
    );
  }

  /// Whether the user is close to their limit (>80% calls used)
  bool get isNearLimit =>
      callsLimit > 0 && callsUsed / callsLimit > 0.8;

  /// Whether the user has exceeded their limit
  bool get isExhausted => callsLimit > 0 && callsUsed >= callsLimit;

  /// Remaining calls
  int get callsRemaining =>
      callsLimit > callsUsed ? callsLimit - callsUsed : 0;
}
