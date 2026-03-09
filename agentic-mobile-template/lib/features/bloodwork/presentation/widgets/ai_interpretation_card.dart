// lib/features/bloodwork/presentation/widgets/ai_interpretation_card.dart

import 'package:flutter/material.dart';

/// Card that surfaces an AI-generated bloodwork interpretation.
///
/// Rules:
/// - Always shows the medical disclaimer in amber before the AI text.
/// - The "AI Suggestion" label is always visible so the user knows this is
///   not authoritative medical advice.
/// - Loading and error states are handled inline.
/// - All wording is suggestive, never prescriptive.
class AiInterpretationCard extends StatelessWidget {
  const AiInterpretationCard({
    super.key,
    required this.interpretation,
    required this.isLoading,
    this.error,
    this.onRetry,
  });

  /// The AI or deterministic fallback interpretation text.
  /// Null means no interpretation has been generated yet.
  final String? interpretation;

  /// True while an AI call is in flight.
  final bool isLoading;

  /// Non-null when the last AI call failed (distinct from consent errors,
  /// which are surfaced via a dialog upstream).
  final String? error;

  /// Called when the user taps "Retry" in an error state.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withAlpha(40),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Suggestion',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Medical disclaimer — NON-NEGOTIABLE ──────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7), // amber-100
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withAlpha(100), // amber-500
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Color(0xFFD97706), // amber-600
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is not medical advice. Consult your healthcare '
                      'provider before making any changes based on these '
                      'suggestions.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF92400E), // amber-800
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Content area ────────────────────────────────────────────────
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (error != null && interpretation == null)
              _ErrorState(errorMessage: error!, onRetry: onRetry)
            else if (interpretation != null)
              _InterpretationText(text: interpretation!)
            else
              // Should not normally be reached — provider guards this.
              Text(
                'Tap "Get AI Suggestion" to generate an interpretation.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(153),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Interpretation text ──────────────────────────────────────────────────────

class _InterpretationText extends StatelessWidget {
  const _InterpretationText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The text may contain multiple paragraphs separated by \n\n.
    final paragraphs = text
        .split('\n\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.length <= 1) {
      return Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < paragraphs.length; i++) ...[
          Text(
            paragraphs[i],
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          if (i < paragraphs.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.errorMessage, this.onRetry});

  final String errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          errorMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ],
    );
  }
}
