import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/freemium/data/freemium_repository.dart';
import 'package:welltrack/features/freemium/presentation/paywall_screen.dart';
import 'package:welltrack/shared/core/constants/feature_flags.dart';

/// Widget that gates Pro-only features behind a paywall
///
/// Shows the child widget if the user has Pro access,
/// otherwise shows an upgrade prompt
class FreemiumGate extends ConsumerWidget {
  final Widget child;
  final String featureName;
  final String? description;
  final bool showUpgradeButton;

  const FreemiumGate({
    super.key,
    required this.child,
    required this.featureName,
    this.description,
    this.showUpgradeButton = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureAvailableAsync = ref.watch(
      featureAvailableProvider(featureName),
    );

    return featureAvailableAsync.when(
      data: (isAvailable) {
        if (isAvailable) {
          return child;
        } else {
          return _buildUpgradePrompt(context);
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error checking feature availability: $error'),
      ),
    );
  }

  Widget _buildUpgradePrompt(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.workspace_premium,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              FeatureFlags.getFeatureDisplayName(featureName),
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description ?? FeatureFlags.getFeatureDescription(featureName),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (showUpgradeButton)
              ElevatedButton.icon(
                onPressed: () => _navigateToPaywall(context),
                icon: const Icon(Icons.upgrade),
                label: const Text('Upgrade to Pro'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToPaywall(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaywallScreen(
          featureName: FeatureFlags.getFeatureDisplayName(featureName),
          description: description ?? FeatureFlags.getFeatureDescription(featureName),
        ),
      ),
    );
  }
}

/// Inline variant that shows a compact upgrade prompt
class FreemiumGateInline extends ConsumerWidget {
  final Widget child;
  final String featureName;
  final VoidCallback? onUpgrade;

  const FreemiumGateInline({
    super.key,
    required this.child,
    required this.featureName,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureAvailableAsync = ref.watch(
      featureAvailableProvider(featureName),
    );

    return featureAvailableAsync.when(
      data: (isAvailable) {
        if (isAvailable) {
          return child;
        } else {
          return _buildInlinePrompt(context);
        }
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildInlinePrompt(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pro Feature',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  FeatureFlags.getFeatureDisplayName(featureName),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onUpgrade ?? () => _navigateToPaywall(context),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  void _navigateToPaywall(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaywallScreen(
          featureName: FeatureFlags.getFeatureDisplayName(featureName),
          description: FeatureFlags.getFeatureDescription(featureName),
        ),
      ),
    );
  }
}

/// Button that checks feature availability before executing action
class FreemiumGatedButton extends ConsumerWidget {
  final String featureName;
  final VoidCallback onPressed;
  final Widget child;
  final ButtonStyle? style;

  const FreemiumGatedButton({
    super.key,
    required this.featureName,
    required this.onPressed,
    required this.child,
    this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureAvailableAsync = ref.watch(
      featureAvailableProvider(featureName),
    );

    return featureAvailableAsync.when(
      data: (isAvailable) {
        return ElevatedButton(
          onPressed: isAvailable ? onPressed : () => _showPaywall(context),
          style: style,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isAvailable) ...[
                const Icon(Icons.lock, size: 16),
                const SizedBox(width: 8),
              ],
              child,
            ],
          ),
        );
      },
      loading: () => ElevatedButton(
        onPressed: null,
        style: style,
        child: child,
      ),
      error: (error, stack) => ElevatedButton(
        onPressed: null,
        style: style,
        child: child,
      ),
    );
  }

  void _showPaywall(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaywallScreen(
          featureName: FeatureFlags.getFeatureDisplayName(featureName),
          description: FeatureFlags.getFeatureDescription(featureName),
        ),
      ),
    );
  }
}
