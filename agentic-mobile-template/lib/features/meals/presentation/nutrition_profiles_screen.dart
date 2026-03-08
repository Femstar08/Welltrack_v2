import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'nutrition_profiles_provider.dart';

// Nutrition profile definitions
const _profiles = [
  _NutritionProfile(
    key: 'cardiovascular',
    title: 'Cardiovascular & Blood Flow',
    subtitle: 'Nitric oxide boosters for heart health and circulation',
    icon: Icons.favorite_outline,
    color: Color(0xFFE53935),
    foods: [
      'Beetroot',
      'Spinach',
      'Rocket',
      'Kale',
      'Watermelon',
      'Pomegranate',
      'Dark chocolate 85%+',
      'Garlic',
    ],
    reduces: 'Added sugar, refined carbs',
  ),
  _NutritionProfile(
    key: 'hormonal',
    title: 'Hormonal Support',
    subtitle: 'Foods that support natural testosterone and hormone balance',
    icon: Icons.balance_outlined,
    color: Color(0xFF5E35B1),
    foods: [
      'Whole eggs',
      'Salmon',
      'Mackerel',
      'Sardines',
      'Pumpkin seeds',
      'Chickpeas',
      'Red meat',
      'Broccoli',
      'Cauliflower',
      'Almonds',
      'Avocado',
    ],
    reduces: 'Excess soy, heavily processed foods',
  ),
];

const _cuisines = [
  _Cuisine(key: 'balanced', label: 'Balanced', description: 'Diverse whole foods from all cuisines'),
  _Cuisine(key: 'nigerian', label: 'Nigerian', description: 'Egusi, jollof, suya, plantain, ofe onugbu'),
  _Cuisine(key: 'british', label: 'British', description: 'Oats, roast vegetables, lean meats, pies'),
  _Cuisine(key: 'mediterranean', label: 'Mediterranean', description: 'Olive oil, fish, legumes, whole grains'),
  _Cuisine(key: 'asian', label: 'Asian', description: 'Rice, tofu, fish, ginger, bok choy, miso'),
];

class NutritionProfilesScreen extends ConsumerWidget {
  const NutritionProfilesScreen({required this.profileId, super.key});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nutritionProfilesProvider(profileId));
    final notifier = ref.read(nutritionProfilesProvider(profileId).notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Profiles'),
        actions: [
          TextButton(
            onPressed: state.isSaving
                ? null
                : () async {
                    final ok = await notifier.save();
                    if (context.mounted) {
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nutrition profiles saved'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        Navigator.of(context).pop();
                      } else if (state.error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(state.error!)),
                        );
                      }
                    }
                  },
            child: state.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header description
                Text(
                  'FOOD PREFERENCE PROFILES',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enable profiles to bias AI meal generation toward specific '
                  'food groups. Profiles stack — you can enable both.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Profile cards
                ..._profiles.map((profile) {
                  final isEnabled =
                      state.enabledProfiles.contains(profile.key);
                  return _ProfileCard(
                    profile: profile,
                    isEnabled: isEnabled,
                    onToggle: () => notifier.toggleProfile(profile.key),
                  );
                }),

                const SizedBox(height: 8),

                // Disclaimer
                Card(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'These are preferences, not hard constraints. '
                            'AI will prioritise these foods while still meeting '
                            'your macro targets.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Cuisine Preference section
                Text(
                  'CUISINE PREFERENCE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the culinary style AI will lean toward when '
                  'generating your meal plans.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  child: RadioGroup<String>(
                    groupValue: state.cuisinePreference,
                    onChanged: (String? v) {
                      if (v != null) notifier.setCuisinePreference(v);
                    },
                    child: Column(
                      children: _cuisines.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final cuisine = entry.value;
                        final isSelected =
                            state.cuisinePreference == cuisine.key;
                        return Column(
                          children: [
                            RadioListTile<String>(
                              value: cuisine.key,
                              title: Text(
                                cuisine.label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                cuisine.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              activeColor: theme.colorScheme.primary,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                            if (idx < _cuisines.length - 1)
                              const Divider(height: 1, indent: 12, endIndent: 12),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isEnabled,
    required this.onToggle,
  });

  final _NutritionProfile profile;
  final bool isEnabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isEnabled
            ? BorderSide(color: profile.color, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: profile.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(profile.icon, color: profile.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        profile.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: (_) => onToggle(),
                  activeThumbColor: profile.color,
                ),
              ],
            ),

            // Food chips — shown when enabled
            if (isEnabled) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Prioritises:',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: profile.foods
                    .map(
                      (food) => Chip(
                        label: Text(food),
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          color: profile.color,
                        ),
                        backgroundColor: profile.color.withValues(alpha: 0.08),
                        side: BorderSide(color: profile.color.withValues(alpha: 0.3)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'Reduces: ${profile.reduces}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NutritionProfile {
  const _NutritionProfile({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.foods,
    required this.reduces,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> foods;
  final String reduces;
}

class _Cuisine {
  const _Cuisine({
    required this.key,
    required this.label,
    required this.description,
  });

  final String key;
  final String label;
  final String description;
}
