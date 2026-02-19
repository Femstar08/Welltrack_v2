import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_models.dart';

/// Global AI usage state — updated after every AI call
/// so UI can show remaining quota.
final aiUsageProvider = StateProvider<AiUsageInfo?>((ref) => null);

/// Generic one-shot AI call state
enum AiCallStatus { idle, loading, success, error }

class AiCallState<T> {

  const AiCallState._({
    required this.status,
    this.data,
    this.errorMessage,
  });

  const AiCallState.idle() : this._(status: AiCallStatus.idle);
  const AiCallState.loading() : this._(status: AiCallStatus.loading);
  const AiCallState.success(T data)
      : this._(status: AiCallStatus.success, data: data);
  const AiCallState.error(String message)
      : this._(status: AiCallStatus.error, errorMessage: message);
  final AiCallStatus status;
  final T? data;
  final String? errorMessage;

  bool get isLoading => status == AiCallStatus.loading;
  bool get isError => status == AiCallStatus.error;
  bool get isSuccess => status == AiCallStatus.success;
}
