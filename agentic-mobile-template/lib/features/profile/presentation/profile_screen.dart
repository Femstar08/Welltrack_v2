import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/profile/domain/profile_entity.dart';
import 'package:welltrack/features/profile/presentation/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  bool _isLoading = false;

  // Edit controllers
  final _displayNameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _fitnessGoalsController = TextEditingController();
  final _dietaryRestrictionsController = TextEditingController();
  final _allergiesController = TextEditingController();

  DateTime? _editDateOfBirth;
  String? _editGender;
  String? _editActivityLevel;

  final List<String> _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];
  final List<String> _activityLevels = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Very Active',
    'Extremely Active'
  ];

  @override
  void dispose() {
    _displayNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _fitnessGoalsController.dispose();
    _dietaryRestrictionsController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  void _startEditing(ProfileEntity profile) {
    setState(() {
      _isEditing = true;
      _displayNameController.text = profile.displayName;
      _heightController.text = profile.heightCm?.toString() ?? '';
      _weightController.text = profile.weightKg?.toString() ?? '';
      _fitnessGoalsController.text = profile.fitnessGoals ?? '';
      _dietaryRestrictionsController.text = profile.dietaryRestrictions ?? '';
      _allergiesController.text = profile.allergies ?? '';
      _editDateOfBirth = profile.dateOfBirth;
      _editGender = profile.gender;
      _editActivityLevel = profile.activityLevel;
    });
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);
  }

  Future<void> _saveChanges(ProfileEntity profile) async {
    setState(() => _isLoading = true);

    try {
      final updates = <String, dynamic>{};

      if (_displayNameController.text.trim() != profile.displayName) {
        updates['display_name'] = _displayNameController.text.trim();
      }
      if (_editDateOfBirth != profile.dateOfBirth) {
        updates['date_of_birth'] = _editDateOfBirth?.toIso8601String();
      }
      if (_editGender != profile.gender) {
        updates['gender'] = _editGender;
      }

      final heightCm = _heightController.text.isNotEmpty
          ? double.tryParse(_heightController.text)
          : null;
      if (heightCm != profile.heightCm) {
        updates['height_cm'] = heightCm;
      }

      final weightKg = _weightController.text.isNotEmpty
          ? double.tryParse(_weightController.text)
          : null;
      if (weightKg != profile.weightKg) {
        updates['weight_kg'] = weightKg;
      }

      if (_editActivityLevel != profile.activityLevel) {
        updates['activity_level'] = _editActivityLevel;
      }

      final fitnessGoals = _fitnessGoalsController.text.trim();
      if (fitnessGoals != (profile.fitnessGoals ?? '')) {
        updates['fitness_goals'] = fitnessGoals.isNotEmpty ? fitnessGoals : null;
      }

      final dietaryRestrictions = _dietaryRestrictionsController.text.trim();
      if (dietaryRestrictions != (profile.dietaryRestrictions ?? '')) {
        updates['dietary_restrictions'] =
            dietaryRestrictions.isNotEmpty ? dietaryRestrictions : null;
      }

      final allergies = _allergiesController.text.trim();
      if (allergies != (profile.allergies ?? '')) {
        updates['allergies'] = allergies.isNotEmpty ? allergies : null;
      }

      if (updates.isNotEmpty) {
        await ref
            .read(activeProfileProvider.notifier)
            .updateProfile(profile.id, updates);
      }

      setState(() => _isEditing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(activeProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                profileAsync.whenData((profile) {
                  if (profile != null) {
                    _startEditing(profile);
                  }
                });
              },
            ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Text('No profile found'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: profile.avatarUrl != null
                      ? ClipOval(
                          child: Image.network(
                            profile.avatarUrl!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          profile.initials,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.displayName,
                  style: theme.textTheme.headlineSmall,
                ),
                if (profile.age != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${profile.age} years old',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                if (_isEditing)
                  _buildEditForm(profile)
                else
                  _buildProfileView(profile),
                if (_isEditing) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _cancelEditing,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isLoading ? null : () => _saveChanges(profile),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: ${error.toString()}'),
        ),
      ),
    );
  }

  Widget _buildProfileView(ProfileEntity profile) {
    return Card(
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.person_outline,
            label: 'Display Name',
            value: profile.displayName,
          ),
          const Divider(height: 1),
          _buildInfoTile(
            icon: Icons.calendar_today_outlined,
            label: 'Date of Birth',
            value: profile.dateOfBirth != null
                ? '${profile.dateOfBirth!.day}/${profile.dateOfBirth!.month}/${profile.dateOfBirth!.year}'
                : 'Not set',
          ),
          const Divider(height: 1),
          _buildInfoTile(
            icon: Icons.wc_outlined,
            label: 'Gender',
            value: profile.gender ?? 'Not set',
          ),
          const Divider(height: 1),
          _buildInfoTile(
            icon: Icons.height_outlined,
            label: 'Height',
            value: profile.heightCm != null ? '${profile.heightCm} cm' : 'Not set',
          ),
          const Divider(height: 1),
          _buildInfoTile(
            icon: Icons.monitor_weight_outlined,
            label: 'Weight',
            value: profile.weightKg != null ? '${profile.weightKg} kg' : 'Not set',
          ),
          const Divider(height: 1),
          _buildInfoTile(
            icon: Icons.directions_run_outlined,
            label: 'Activity Level',
            value: profile.activityLevel ?? 'Not set',
          ),
          const Divider(height: 1),
          _buildInfoTile(
            icon: Icons.fitness_center_outlined,
            label: 'Fitness Goals',
            value: profile.fitnessGoals ?? 'Not set',
          ),
          const Divider(height: 1),
          _buildInfoTile(
            icon: Icons.restaurant_outlined,
            label: 'Dietary Restrictions',
            value: profile.dietaryRestrictions ?? 'None',
          ),
          const Divider(height: 1),
          _buildInfoTile(
            icon: Icons.warning_amber_outlined,
            label: 'Allergies',
            value: profile.allergies ?? 'None',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyLarge,
      ),
    );
  }

  Widget _buildEditForm(ProfileEntity profile) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _displayNameController,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: const Icon(Icons.calendar_today_outlined),
          title: const Text('Date of Birth'),
          subtitle: Text(
            _editDateOfBirth != null
                ? '${_editDateOfBirth!.day}/${_editDateOfBirth!.month}/${_editDateOfBirth!.year}'
                : 'Not set',
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _editDateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() => _editDateOfBirth = picked);
            }
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Gender',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _genderOptions.map((option) {
            return ChoiceChip(
              label: Text(option),
              selected: _editGender == option,
              onSelected: (selected) {
                setState(() => _editGender = selected ? option : null);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _heightController,
                decoration: const InputDecoration(
                  labelText: 'Height (cm)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.height_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monitor_weight_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _editActivityLevel,
          decoration: const InputDecoration(
            labelText: 'Activity Level',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.directions_run_outlined),
          ),
          items: _activityLevels.map((level) {
            return DropdownMenuItem(
              value: level,
              child: Text(level),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _editActivityLevel = value);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _fitnessGoalsController,
          decoration: const InputDecoration(
            labelText: 'Fitness Goals',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.fitness_center_outlined),
          ),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _dietaryRestrictionsController,
          decoration: const InputDecoration(
            labelText: 'Dietary Restrictions',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.restaurant_outlined),
          ),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _allergiesController,
          decoration: const InputDecoration(
            labelText: 'Allergies',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.warning_amber_outlined),
          ),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}
