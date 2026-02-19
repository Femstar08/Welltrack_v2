import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/plan_tier.dart';

/// Paywall screen for upgrading to Pro
class PaywallScreen extends ConsumerWidget {

  const PaywallScreen({
    super.key,
    this.featureName,
    this.description,
  });
  final String? featureName;
  final String? description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade to Pro'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero section
            if (featureName != null) ...[
              Icon(
                Icons.lock,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                featureName!,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
            ] else ...[
              Icon(
                Icons.workspace_premium,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Unlock Your Full Potential',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Get unlimited access to all Pro features',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
            ],

            // Feature comparison
            _buildComparisonTable(context),
            const SizedBox(height: 32),

            // Pro benefits
            Text(
              'Pro Benefits',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...PlanTier.pro.benefits.map((benefit) => _buildBenefitItem(
              context,
              benefit,
            )),
            const SizedBox(height: 32),

            // Pricing
            _buildPricingCard(context),
            const SizedBox(height: 24),

            // CTA buttons
            ElevatedButton(
              onPressed: () => _handleUpgrade(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text(
                'Upgrade to Pro',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Maybe Later'),
            ),
            const SizedBox(height: 24),

            // Fine print
            Text(
              'Subscription automatically renews unless cancelled. Cancel anytime from your account settings.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header row
            Row(
              children: [
                const Expanded(flex: 2, child: SizedBox()),
                Expanded(
                  child: Text(
                    'Free',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Pro',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const Divider(),

            // Features
            _buildComparisonRow(context, 'AI Calls/Day', '3', 'Unlimited'),
            _buildComparisonRow(context, 'History', '7 days', '1 year'),
            _buildComparisonRow(context, 'Profiles', '1', '5'),
            _buildComparisonRow(context, 'Nutrients', 'Macros', 'Full'),
            _buildComparisonRow(context, 'Recovery Score', Icons.close, Icons.check),
            _buildComparisonRow(context, 'Goal Forecasting', Icons.close, Icons.check),
            _buildComparisonRow(context, 'Training Load', Icons.close, Icons.check),
            _buildComparisonRow(context, 'Adaptive Plans', Icons.close, Icons.check),
            _buildComparisonRow(context, 'Weekly AI Summaries', Icons.close, Icons.check),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(
    BuildContext context,
    String feature,
    dynamic freeValue,
    dynamic proValue,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: _buildValueCell(context, freeValue, false),
          ),
          Expanded(
            child: _buildValueCell(context, proValue, true),
          ),
        ],
      ),
    );
  }

  Widget _buildValueCell(BuildContext context, dynamic value, bool isPro) {
    final theme = Theme.of(context);

    if (value is IconData) {
      return Icon(
        value,
        size: 20,
        color: value == Icons.check
            ? (isPro ? theme.colorScheme.primary : Colors.grey)
            : Colors.grey.shade400,
      );
    }

    return Text(
      value.toString(),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: isPro ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        fontWeight: isPro ? FontWeight.bold : null,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildBenefitItem(BuildContext context, String benefit) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              benefit,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              '\$9.99',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'per month',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'BEST VALUE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleUpgrade(BuildContext context) {
    // Stub for payment integration (RevenueCat/Stripe)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: const Text(
          'Payment integration with RevenueCat/Stripe is ready to be implemented. '
          'This will handle subscription management, payments, and receipt validation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
