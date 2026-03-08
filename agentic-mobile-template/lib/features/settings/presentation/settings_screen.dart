import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/core/theme/theme_provider.dart';
import '../../../shared/core/router/app_router.dart' show activeProfileIdProvider;
import 'rest_timer_settings.dart';
import '../../../features/workouts/presentation/rest_timer_provider.dart';
import '../../../features/profile/data/profile_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  PackageInfo? _packageInfo;
  bool _aiConsentVitality = false;
  bool _aiConsentBloodwork = false;
  bool _loadingConsent = true;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadConsentSettings();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _packageInfo = info);
  }

  Future<void> _loadConsentSettings() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null || profileId.isEmpty) {
      setState(() => _loadingConsent = false);
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('wt_profiles')
          .select('ai_consent_vitality, ai_consent_bloodwork')
          .eq('id', profileId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _aiConsentVitality = response['ai_consent_vitality'] as bool? ?? false;
          _aiConsentBloodwork = response['ai_consent_bloodwork'] as bool? ?? false;
          _loadingConsent = false;
        });
      } else if (mounted) {
        setState(() => _loadingConsent = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingConsent = false);
    }
  }

  Future<void> _setVitalityConsent(bool value) async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null || profileId.isEmpty) return;
    setState(() => _aiConsentVitality = value);
    try {
      await ref.read(profileRepositoryProvider).updateAiConsent(
        profileId,
        aiConsentVitality: value,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _aiConsentVitality = !value); // revert
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save setting: $e')),
        );
      }
    }
  }

  Future<void> _setBloodworkConsent(bool value) async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null || profileId.isEmpty) return;
    setState(() => _aiConsentBloodwork = value);
    try {
      await ref.read(profileRepositoryProvider).updateAiConsent(
        profileId,
        aiConsentBloodwork: value,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _aiConsentBloodwork = !value); // revert
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save setting: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Account Section
          _buildSectionHeader('Account'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(currentUser?.email ?? 'Not signed in'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password change coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Appearance Section
          _buildSectionHeader('Appearance'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Theme Mode'),
              trailing: DropdownButton<ThemeMode>(
                value: ref.watch(themeModeProvider),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  }
                },
              ),
            ),
          ),

          // Health Connections Section
          _buildSectionHeader('Health Connections'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.health_and_safety_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('Health Data'),
                  subtitle: const Text('Sleep, steps, and heart rate'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/health'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.watch_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('Garmin'),
                  subtitle: const Text('Coming in Phase 7'),
                  trailing: Chip(
                    label: const Text('Coming Soon'),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.directions_bike_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('Strava'),
                  subtitle: const Text('Coming in Phase 7'),
                  trailing: Chip(
                    label: const Text('Coming Soon'),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),

          // Nutrition Section
          _buildSectionHeader('Nutrition'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.track_changes_outlined),
                  title: const Text('Nutrition Targets'),
                  subtitle: const Text('Custom calorie & macro goals per day type'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/nutrition-targets'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restaurant_menu_outlined),
                  title: const Text('Ingredient Preferences'),
                  subtitle: const Text('Preferred and excluded ingredients'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/ingredient-preferences'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.eco_outlined),
                  title: const Text('Nutrition Profiles'),
                  subtitle: const Text(
                    'Cardiovascular, hormonal food preferences & cuisine',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/meals/nutrition-profiles'),
                ),
              ],
            ),
          ),

          // Reminders Section
          _buildSectionHeader('Reminders'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Manage Reminders'),
              subtitle: const Text('Meals, workouts, supplements, custom'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/reminders'),
            ),
          ),

          // Workout Section
          _buildSectionHeader('Workout'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.hourglass_bottom_outlined),
                  title: const Text('Default Rest Duration'),
                  subtitle: Builder(builder: (_) {
                    final secs = ref.watch(defaultRestTimerSecondsProvider);
                    return Text(
                      secs >= 60
                          ? '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')} min'
                          : '${secs}s',
                    );
                  }),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showRestTimerDurationPicker(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Rest Timer Alert'),
                  subtitle: Text(
                    switch (ref.watch(restTimerAlertModeProvider)) {
                      RestTimerAlertMode.vibrateOnly => 'Vibrate only',
                      RestTimerAlertMode.soundOnly => 'Sound only',
                      RestTimerAlertMode.both => 'Vibrate + Sound',
                      RestTimerAlertMode.silent => 'Silent',
                    },
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showRestTimerAlertPicker(context, ref),
                ),
              ],
            ),
          ),

          // AI Usage Section
          _buildSectionHeader('AI Usage'),
          const Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(Icons.auto_awesome_outlined),
              title: Text('AI Calls Remaining'),
              subtitle: Text('Freemium plan'),
              trailing: Text(
                '10 / 10',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // AI Data Sharing Section
          _buildSectionHeader('AI Data Sharing'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.favorite_border),
                  title: const Text('Share vitality data with AI'),
                  subtitle: const Text(
                    'Include morning wellness tracking in AI analysis for health correlations',
                  ),
                  value: _loadingConsent ? false : _aiConsentVitality,
                  onChanged: _loadingConsent ? null : _setVitalityConsent,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.biotech_outlined),
                  title: const Text('Share bloodwork data with AI'),
                  subtitle: const Text(
                    'Include lab results in AI analysis for health insights',
                  ),
                  value: _loadingConsent ? false : _aiConsentBloodwork,
                  onChanged: _loadingConsent ? null : _setBloodworkConsent,
                ),
              ],
            ),
          ),

          // Module Configuration Section
          _buildSectionHeader('Modules'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('Module Configuration'),
              subtitle: const Text('Enable or disable features'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Module configuration coming soon')),
                );
              },
            ),
          ),

          // About Section
          _buildSectionHeader('About'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('App Version'),
                  trailing: Text(
                    _packageInfo != null
                        ? 'v${_packageInfo!.version} (${_packageInfo!.buildNumber})'
                        : 'Loading...',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Terms of Service coming soon'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy Policy coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Sign Out Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
