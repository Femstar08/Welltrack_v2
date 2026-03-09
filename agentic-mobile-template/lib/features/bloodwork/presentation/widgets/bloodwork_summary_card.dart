// lib/features/bloodwork/presentation/widgets/bloodwork_summary_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../bloodwork_provider.dart';

/// Compact card displayed on the Insights Dashboard that summarises the user's
/// most recent bloodwork results.
///
/// States:
///  - Loading: CircularProgressIndicator
///  - No data: "No bloodwork data yet" placeholder
///  - All normal: green "All results normal" indicator
///  - Flags: count of out-of-range tests + most concerning test name in red
///
/// Tapping navigates to `/bloodwork` via GoRouter.
class BloodworkSummaryCard extends ConsumerWidget {
  const BloodworkSummaryCard({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bloodworkProvider(profileId));
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(30)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/bloodwork'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: state.isLoading && state.results.isEmpty
              ? const _LoadingBody()
              : state.latestByTest.isEmpty
                  ? const _EmptyBody()
                  : state.outOfRangeCount > 0
                      ? _FlaggedBody(
                          outOfRangeCount: state.outOfRangeCount,
                          latestByTest: state.latestByTest,
                          theme: theme,
                        )
                      : const _AllNormalBody(),
        ),
      ),
    );
  }
}

// ─── Loading ───────────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 48,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

// ─── Empty (no bloodwork logged) ───────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.science_outlined,
          size: 24,
          color: theme.colorScheme.onSurface.withAlpha(100),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'No bloodwork data yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(130),
            ),
          ),
        ),
        Icon(
          Icons.chevron_right,
          size: 20,
          color: theme.colorScheme.onSurface.withAlpha(80),
        ),
      ],
    );
  }
}

// ─── All normal ────────────────────────────────────────────────────────────────

class _AllNormalBody extends StatelessWidget {
  const _AllNormalBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline,
            size: 20,
            color: Color(0xFF22C55E),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bloodwork',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(130),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'All results normal',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF22C55E),
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right,
          size: 20,
          color: theme.colorScheme.onSurface.withAlpha(80),
        ),
      ],
    );
  }
}

// ─── Flagged ───────────────────────────────────────────────────────────────────

class _FlaggedBody extends StatelessWidget {
  const _FlaggedBody({
    required this.outOfRangeCount,
    required this.latestByTest,
    required this.theme,
  });

  final int outOfRangeCount;
  final Map<String, dynamic> latestByTest;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Find the most concerning test — out-of-range first, then borderline.
    final outOfRangeEntries = latestByTest.entries
        .where((e) => (e.value as dynamic).isOutOfRange == true)
        .toList();
    final concerningName = outOfRangeEntries.isNotEmpty
        ? (outOfRangeEntries.first.value as dynamic).testName as String
        : '';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bloodwork',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(130),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$outOfRangeCount result${outOfRangeCount > 1 ? 's' : ''} out of range',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.error,
                ),
              ),
              if (concerningName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'e.g. $concerningName',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ],
          ),
        ),
        Icon(
          Icons.chevron_right,
          size: 20,
          color: theme.colorScheme.onSurface.withAlpha(80),
        ),
      ],
    );
  }
}
