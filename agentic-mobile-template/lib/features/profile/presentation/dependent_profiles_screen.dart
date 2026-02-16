import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/freemium/presentation/freemium_gate_widget.dart';
import 'package:welltrack/shared/core/constants/feature_flags.dart';

/// Stub screen for managing dependent profiles
///
/// This screen provides the UI structure for managing multiple profiles
/// under a single parent account. This is a Pro-only feature.
/// Full implementation will be added in Phase 12.
class DependentProfilesScreen extends ConsumerWidget {
  const DependentProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Profiles'),
      ),
      body: FreemiumGate(
        featureName: FeatureFlags.multipleProfiles,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Future implementation structure
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Card(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Multiple Profiles',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Manage wellness tracking for your entire family under one account. '
                        'Each profile has separate data, goals, and insights.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Current profiles section
              Text(
                'Your Profiles',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Main profile (always present)
              _buildProfileCard(
                context,
                name: 'Main Profile',
                relationship: 'Parent',
                isPrimary: true,
              ),
              const SizedBox(height: 32),

              // Add dependent button
              OutlinedButton.icon(
                onPressed: () => _showAddDependentDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Dependent Profile'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),

              // Features section
              Text(
                'Profile Features',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                context,
                Icons.person,
                'Individual Tracking',
                'Each profile has separate meal logs, workouts, and health metrics',
              ),
              _buildFeatureItem(
                context,
                Icons.insights,
                'Personalized Insights',
                'AI-powered recommendations tailored to each individual',
              ),
              _buildFeatureItem(
                context,
                Icons.lock,
                'Data Privacy',
                'All data is securely isolated per profile',
              ),
              _buildFeatureItem(
                context,
                Icons.family_restroom,
                'Family View',
                'Parents can monitor and manage dependent profiles',
              ),
              _buildFeatureItem(
                context,
                Icons.settings,
                'Age-Appropriate',
                'Customizable settings based on age and needs',
              ),
            ],
          ),
        ),

        // Coming soon overlay
        Positioned.fill(
          child: Container(
            color: theme.colorScheme.surface.withOpacity(0.95),
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(32),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.construction,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Coming in a Future Update',
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Multiple profile management is currently under development.\n\n'
                        'This feature will allow you to:\n'
                        '• Create up to 5 profiles (Pro)\n'
                        '• Track wellness for family members\n'
                        '• Set age-appropriate goals\n'
                        '• Monitor progress across profiles',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go Back'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _showNotifyDialog(context),
                        child: const Text('Notify me when available'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(
    BuildContext context, {
    required String name,
    required String relationship,
    bool isPrimary = false,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPrimary
              ? theme.colorScheme.primary
              : theme.colorScheme.secondary,
          child: Text(
            name[0].toUpperCase(),
            style: TextStyle(
              color: isPrimary
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(name),
        subtitle: Text(relationship),
        trailing: isPrimary
            ? Chip(
                label: const Text('Primary'),
                visualDensity: VisualDensity.compact,
              )
            : IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showProfileMenu(context, name),
              ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDependentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Dependent Profile'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This feature is coming soon!'),
            SizedBox(height: 16),
            Text(
              'You\'ll be able to add profiles for:\n'
              '• Children\n'
              '• Spouse/Partner\n'
              '• Other family members',
            ),
          ],
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

  void _showProfileMenu(BuildContext context, String profileName) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(context);
                _showComingSoon(context, 'Edit Profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.switch_account),
              title: const Text('Switch to Profile'),
              onTap: () {
                Navigator.pop(context);
                _showComingSoon(context, 'Switch Profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Profile Settings'),
              onTap: () {
                Navigator.pop(context);
                _showComingSoon(context, 'Profile Settings');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Profile', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showComingSoon(context, 'Delete Profile');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNotifyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Get Notified'),
        content: const Text(
          'We\'ll send you a notification when multiple profile support is available.\n\n'
          'Email notifications will be implemented in a future update.',
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

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming in a future update'),
      ),
    );
  }
}
