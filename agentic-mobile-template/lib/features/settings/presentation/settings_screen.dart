import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/core/theme/theme_provider.dart';
import '../../../shared/core/router/app_router.dart' show activeProfileIdProvider;
import 'rest_timer_settings.dart';
import '../../../features/workouts/presentation/rest_timer_provider.dart';
import '../../../features/profile/data/profile_repository.dart';
import '../../../features/health/presentation/health_connections_provider.dart';

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
    final profileId = ref.watch(activeProfileIdProvider) ?? '';

    // Listen for successful connects so we can show a SnackBar when the deep
    // link callback completes and the state flips from connecting → connected.
    if (profileId.isNotEmpty) {
      ref.listen<HealthConnectionsState>(
        healthConnectionsProvider(profileId),
        (prev, next) {
          if (!mounted) return;

          // Garmin just connected
          if (!(prev?.garminConnected ?? false) && next.garminConnected) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Garmin connected! Syncing last 14 days of data…',
                ),
              ),
            );
          }

          // Strava just connected
          if (!(prev?.stravaConnected ?? false) && next.stravaConnected) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Strava connected! Syncing last 14 days of data…',
                ),
              ),
            );
          }
        },
      );
    }

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
                _buildProviderTile(
                  provider: 'garmin',
                  icon: Icons.watch_outlined,
                  label: 'Garmin',
                ),
                const Divider(height: 1),
                _buildProviderTile(
                  provider: 'strava',
                  icon: Icons.directions_bike_outlined,
                  label: 'Strava',
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

  // ---------------------------------------------------------------------------
  // Health connections helpers
  // ---------------------------------------------------------------------------

  /// Builds a connect/disconnect tile for [provider] ('garmin' or 'strava').
  Widget _buildProviderTile({
    required String provider,
    required IconData icon,
    required String label,
  }) {
    final profileId = ref.watch(activeProfileIdProvider) ?? '';
    if (profileId.isEmpty) {
      return ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: const Text('Sign in to connect'),
      );
    }

    final connState = ref.watch(healthConnectionsProvider(profileId));
    final isGarmin = provider == 'garmin';
    final isConnected =
        isGarmin ? connState.garminConnected : connState.stravaConnected;
    final lastSync =
        isGarmin ? connState.garminLastSync : connState.stravaLastSync;

    final theme = Theme.of(context);

    // Loading skeleton while initial fetch is in progress
    if (connState.isLoading) {
      return ListTile(
        leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        title: Text(label),
        subtitle: const Text('Checking connection…'),
        trailing: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (isConnected) {
      return ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(label),
        subtitle: Text(
          lastSync != null
              ? 'Last synced ${_formatLastSync(lastSync)}'
              : 'Connected',
        ),
        trailing: connState.isConnecting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.sync, size: 20),
                    tooltip: 'Sync Now',
                    onPressed: () => _triggerSync(provider),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => _confirmDisconnect(provider, label),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
      );
    }

    // Not connected state
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(label),
      subtitle: const Text('Not connected'),
      trailing: connState.isConnecting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : ElevatedButton(
              onPressed: () => isGarmin ? _connectGarmin() : _connectStrava(),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('Connect'),
            ),
    );
  }

  /// Opens the Garmin OAuth flow in the browser.
  Future<void> _connectGarmin() async {
    final profileId = ref.read(activeProfileIdProvider) ?? '';
    if (profileId.isEmpty) return;

    // Step 1: obtain a request token from the Edge Function
    final authUrl = await ref
        .read(healthConnectionsProvider(profileId).notifier)
        .initiateGarminOAuth();

    if (authUrl == null) {
      // Error is already stored in state — show it
      _showConnectionError('garmin');
      return;
    }

    // Step 2: open Garmin Connect in the browser
    final uri = Uri.parse(authUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open browser. Please try again.'),
          ),
        );
      }
    }
    // The OAuth callback deep link is handled in app.dart → _handleOAuthDeepLink
  }

  /// Opens the Strava OAuth flow in the browser.
  Future<void> _connectStrava() async {
    final authUrl = buildStravaAuthorizationUrl();
    final uri = Uri.parse(authUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open browser. Please try again.'),
          ),
        );
      }
    }
    // The OAuth callback deep link is handled in app.dart → _handleOAuthDeepLink
  }

  /// Shows a confirmation dialog then disconnects the given provider.
  Future<void> _confirmDisconnect(String provider, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Disconnect $label?'),
        content: Text(
          'This will remove the $label connection. '
          'Your existing data will be kept, but no new data will be synced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final profileId = ref.read(activeProfileIdProvider) ?? '';
    if (profileId.isEmpty) return;

    if (provider == 'garmin') {
      await ref
          .read(healthConnectionsProvider(profileId).notifier)
          .disconnectGarmin();
    } else {
      await ref
          .read(healthConnectionsProvider(profileId).notifier)
          .disconnectStrava();
    }

    if (!mounted) return;

    final connState = ref.read(healthConnectionsProvider(profileId));
    if (connState.error != null) {
      _showConnectionError(provider);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disconnected from ${_capitalise(provider)}'),
        ),
      );
    }
  }

  /// Triggers a manual backfill for the given provider.
  Future<void> _triggerSync(String provider) async {
    final profileId = ref.read(activeProfileIdProvider) ?? '';
    if (profileId.isEmpty) return;

    final triggered = await ref
        .read(healthConnectionsProvider(profileId).notifier)
        .triggerManualSync(provider);

    if (!mounted) return;

    if (triggered) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Syncing ${_capitalise(provider)} data…'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already synced recently. Try again in 24 hours.'),
        ),
      );
    }
  }

  /// Shows a SnackBar with the current error from the provider state.
  void _showConnectionError(String provider) {
    final profileId = ref.read(activeProfileIdProvider) ?? '';
    if (profileId.isEmpty || !mounted) return;
    final err = ref.read(healthConnectionsProvider(profileId)).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? 'Something went wrong. Please try again.'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  /// Returns a human-readable relative time string for a sync timestamp.
  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final diff = now.difference(lastSync);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h ${h == 1 ? 'hour' : 'hours'} ago';
    }
    final d = diff.inDays;
    return '$d ${d == 1 ? 'day' : 'days'} ago';
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

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
