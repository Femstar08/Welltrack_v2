// lib/shared/core/utils/error_mapper.dart

import 'dart:io';

/// Maps raw exceptions and error objects into user-facing friendly messages.
///
/// Usage:
///   state = state.copyWith(error: ErrorMapper.mapError(e));
///
/// Always call [AppLogger.error] with the original exception BEFORE mapping,
/// so internal diagnostics retain full detail.
class ErrorMapper {
  ErrorMapper._();

  static String mapError(dynamic error) {
    // ── Network ─────────────────────────────────────────────────────────────
    if (error is SocketException) {
      return 'No internet connection. Please check your network.';
    }

    final message = error.toString().toLowerCase();

    if (message.contains('socketexception') ||
        message.contains('no internet') ||
        message.contains('network is unreachable') ||
        message.contains('failed host lookup')) {
      return 'No internet connection. Please check your network.';
    }

    // ── Timeout ──────────────────────────────────────────────────────────────
    if (message.contains('timeout') || message.contains('timed out')) {
      return 'Request timed out. Please try again.';
    }

    // ── Auth / session ────────────────────────────────────────────────────────
    if (message.contains('unauthorized') ||
        message.contains('status 401') ||
        message.contains('"code":401') ||
        message.contains('jwt expired') ||
        message.contains('invalid jwt') ||
        message.contains('session expired')) {
      return 'Your session has expired. Please sign in again.';
    }

    // ── Not found ─────────────────────────────────────────────────────────────
    if (message.contains('status 404') ||
        message.contains('"code":404') ||
        message.contains('not found')) {
      return 'The requested data was not found.';
    }

    // ── Rate limiting ─────────────────────────────────────────────────────────
    if (message.contains('status 429') ||
        message.contains('"code":429') ||
        message.contains('rate limit') ||
        message.contains('too many requests')) {
      return 'Too many requests. Please wait a moment and try again.';
    }

    // ── Server errors ─────────────────────────────────────────────────────────
    if (message.contains('status 500') ||
        message.contains('"code":500') ||
        message.contains('internal server error') ||
        message.contains('status 502') ||
        message.contains('status 503')) {
      return 'Server error. Please try again later.';
    }

    // ── Supabase / PostgREST ──────────────────────────────────────────────────
    if (message.contains('pgrst') || message.contains('postgrest')) {
      return 'Data error. Please try again.';
    }

    // ── Dart type errors (common during JSON parsing) ─────────────────────────
    if (message.contains('type') && message.contains('is not a')) {
      return 'Something went wrong. Please try again.';
    }

    // ── Null check failures ───────────────────────────────────────────────────
    if (message.contains('null check operator used on a null value')) {
      return 'Something went wrong. Please try again.';
    }

    // ── Generic fallback ──────────────────────────────────────────────────────
    return 'Something went wrong. Please try again.';
  }
}
