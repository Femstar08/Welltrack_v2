// lib/features/habits/presentation/kegel_timer_screen.dart
//
// US-003 — Kegel protocol with guided timer.
//
// Two logical views inside a single screen:
//   1. Protocol selection  — shown when currentPhase == idle
//   2. Active timer        — shown during squeeze / relax / rest phases
//   3. Completion          — shown when currentPhase == complete
//
// Navigation: launched via GoRouter at /habits/kegel-timer.
// Auto-pops back to the habits screen after a short delay on completion.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/kegel_protocol.dart';
import 'kegel_timer_provider.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class KegelTimerScreen extends ConsumerStatefulWidget {
  const KegelTimerScreen({super.key});

  @override
  ConsumerState<KegelTimerScreen> createState() => _KegelTimerScreenState();
}

class _KegelTimerScreenState extends ConsumerState<KegelTimerScreen> {
  @override
  void initState() {
    super.initState();
    // Reset the provider state every time the screen opens so the user always
    // starts from protocol selection (the provider is global / singleton).
    Future.microtask(() {
      if (mounted) {
        final notifier = ref.read(kegelTimerProvider.notifier);
        notifier.cancel();
      }
    });
  }

  @override
  void dispose() {
    // If the user backs out mid-session, cancel the timer cleanly.
    ref.read(kegelTimerProvider.notifier).cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kegelTimerProvider);

    // Auto-pop after completion.
    ref.listen<KegelTimerState>(kegelTimerProvider, (prev, next) {
      if (next.currentPhase == KegelPhase.complete &&
          prev?.currentPhase != KegelPhase.complete) {
        Future.delayed(const Duration(seconds: 3), () {
          // Guard with mounted to avoid using a stale BuildContext.
          if (!mounted) return;
          // ignore: use_build_context_synchronously
          context.pop();
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kegel Timer'),
        centerTitle: false,
        leading: BackButton(
          onPressed: () {
            ref.read(kegelTimerProvider.notifier).cancel();
            context.pop();
          },
        ),
      ),
      body: switch (state.currentPhase) {
        KegelPhase.idle => _ProtocolSelectionView(
            selectedProtocol: state.selectedProtocol,
          ),
        KegelPhase.complete => _CompletionView(state: state),
        _ => _ActiveTimerView(state: state),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Protocol selection view
// ---------------------------------------------------------------------------

class _ProtocolSelectionView extends ConsumerWidget {
  const _ProtocolSelectionView({required this.selectedProtocol});

  final KegelProtocol? selectedProtocol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(kegelTimerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Text(
          'Choose a protocol',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select the workout style that matches your current goal.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        ...KegelProtocol.presets.map((protocol) {
          final isSelected = selectedProtocol?.id == protocol.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ProtocolCard(
              protocol: protocol,
              isSelected: isSelected,
              onTap: () => notifier.selectProtocol(protocol),
            ),
          );
        }),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: selectedProtocol != null
                ? () => notifier.start()
                : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(
              'Start session',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Protocol card
// ---------------------------------------------------------------------------

class _ProtocolCard extends StatelessWidget {
  const _ProtocolCard({
    required this.protocol,
    required this.isSelected,
    required this.onTap,
  });

  final KegelProtocol protocol;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Semantics(
      label: 'Select ${protocol.name} protocol',
      button: true,
      selected: isSelected,
      child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.08)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accent : theme.colorScheme.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 14),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    protocol.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    protocol.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _Chip(
                        '${protocol.sets} sets',
                        Icons.repeat,
                      ),
                      _Chip(
                        '${protocol.repsPerSet} reps',
                        Icons.fitness_center,
                      ),
                      _Chip(
                        protocol.estimatedDurationLabel,
                        Icons.timer_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.icon);

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active timer view
// ---------------------------------------------------------------------------

class _ActiveTimerView extends ConsumerWidget {
  const _ActiveTimerView({required this.state});

  final KegelTimerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(kegelTimerProvider.notifier);

    final (phaseLabel, phaseColor) = _phaseDisplay(state.currentPhase, theme);

    return Column(
      children: [
        const Spacer(flex: 1),

        // ── Circular progress + countdown ──────────────────────────────────
        Center(
          child: SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background track
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      phaseColor.withValues(alpha: 0.15),
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Animated fill
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: state.phaseProgress,
                    ),
                    duration: const Duration(milliseconds: 400),
                    builder: (_, value, __) => CircularProgressIndicator(
                      value: value,
                      strokeWidth: 12,
                      valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                ),
                // Centre content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      phaseLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: phaseColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${state.remainingSeconds}',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'seconds',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        // ── Set / rep counter ──────────────────────────────────────────────
        Text(
          state.setRepLabel,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        const Spacer(flex: 1),

        // ── Controls ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
          child: Row(
            children: [
              // Cancel
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => notifier.cancel(),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Pause / Resume
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: state.isRunning
                      ? () => notifier.pause()
                      : () => notifier.resume(),
                  icon: Icon(
                    state.isRunning
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                  ),
                  label: Text(state.isRunning ? 'Pause' : 'Resume'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  (String, Color) _phaseDisplay(KegelPhase phase, ThemeData theme) {
    switch (phase) {
      case KegelPhase.squeeze:
        return ('SQUEEZE', const Color(0xFF42A5F5));
      case KegelPhase.relax:
        return ('RELAX', const Color(0xFF66BB6A));
      case KegelPhase.rest:
        return ('REST', const Color(0xFFFFCA28));
      default:
        return ('', theme.colorScheme.primary);
    }
  }
}

// ---------------------------------------------------------------------------
// Completion view
// ---------------------------------------------------------------------------

class _CompletionView extends StatelessWidget {
  const _CompletionView({required this.state});

  final KegelTimerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final protocol = state.selectedProtocol;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 80,
              color: Color(0xFF66BB6A),
            ),
            const SizedBox(height: 20),
            Text(
              'Great work!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (protocol != null)
              Text(
                '${protocol.name} complete',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 28),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatItem(
                  label: 'Total time',
                  value: state.formattedElapsed,
                  icon: Icons.timer_outlined,
                ),
                const SizedBox(width: 32),
                _StatItem(
                  label: 'Sets',
                  value: '${protocol?.sets ?? state.currentSet}',
                  icon: Icons.repeat_rounded,
                ),
              ],
            ),

            const SizedBox(height: 32),
            Text(
              'Today\'s kegels logged automatically.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Returning to habits in a moment...',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 28),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
