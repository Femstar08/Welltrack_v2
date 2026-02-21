import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/goal_entity.dart';
import 'goals_provider.dart';

class GoalSetupScreen extends ConsumerStatefulWidget {

  const GoalSetupScreen({
    super.key,
    required this.profileId,
    this.existingGoal,
  });
  final String profileId;
  final GoalEntity? existingGoal;

  @override
  ConsumerState<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends ConsumerState<GoalSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedMetricType;
  late TextEditingController _currentValueController;
  late TextEditingController _targetValueController;
  late TextEditingController _unitController;
  late TextEditingController _descriptionController;
  DateTime? _deadline;
  int _priority = 2;
  bool _isLoading = false;

  bool get _isEditing => widget.existingGoal != null;

  static const _metricTypes = [
    ('weight', 'Weight'),
    ('vo2max', 'VO2 Max'),
    ('steps', 'Daily Steps'),
    ('sleep', 'Sleep Duration'),
    ('hr', 'Resting Heart Rate'),
    ('hrv', 'Heart Rate Variability'),
    ('calories', 'Calories'),
    ('distance', 'Distance'),
    ('active_minutes', 'Active Minutes'),
    ('body_fat', 'Body Fat'),
    ('blood_pressure', 'Blood Pressure'),
    ('spo2', 'SpO2'),
    ('stress', 'Stress Score'),
  ];

  static const _priorityOptions = [
    (1, 'Low'),
    (2, 'Medium'),
    (3, 'High'),
    (4, 'Critical'),
    (5, 'Urgent'),
  ];

  @override
  void initState() {
    super.initState();
    final goal = widget.existingGoal;
    _selectedMetricType = goal?.metricType ?? 'weight';
    _currentValueController = TextEditingController(
      text: goal != null ? goal.currentValue.toString() : '',
    );
    _targetValueController = TextEditingController(
      text: goal != null ? goal.targetValue.toString() : '',
    );
    _unitController = TextEditingController(
      text: goal?.unit ?? GoalEntity.defaultUnitForMetricType('weight'),
    );
    _descriptionController = TextEditingController(
      text: goal?.goalDescription ?? '',
    );
    _deadline = goal?.deadline;
    _priority = goal?.priority ?? 2;
  }

  @override
  void dispose() {
    _currentValueController.dispose();
    _targetValueController.dispose();
    _unitController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onMetricTypeChanged(String? value) {
    if (value == null) return;
    setState(() {
      _selectedMetricType = value;
      _unitController.text = GoalEntity.defaultUnitForMetricType(value);
    });
  }

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentValue = double.parse(_currentValueController.text.trim());
      final targetValue = double.parse(_targetValueController.text.trim());
      final description = _descriptionController.text.trim();
      final unit = _unitController.text.trim();

      if (_isEditing) {
        await ref.read(goalsProvider(widget.profileId).notifier).updateGoal(
          widget.existingGoal!.id,
          {
            'metric_type': _selectedMetricType,
            'goal_description': description.isEmpty ? null : description,
            'target_value': targetValue,
            'current_value': currentValue,
            'unit': unit,
            'deadline': _deadline?.toIso8601String().split('T').first,
            'priority': _priority,
          },
        );
      } else {
        await ref.read(goalsProvider(widget.profileId).notifier).createGoal(
          metricType: _selectedMetricType,
          description: description.isEmpty ? null : description,
          targetValue: targetValue,
          currentValue: currentValue,
          unit: unit,
          deadline: _deadline,
          priority: _priority,
        );
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save goal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Goal' : 'Create Goal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Metric type dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedMetricType,
              decoration: const InputDecoration(
                labelText: 'Metric',
                border: OutlineInputBorder(),
              ),
              items: _metricTypes
                  .map((e) => DropdownMenuItem(
                        value: e.$1,
                        child: Text(e.$2),
                      ))
                  .toList(),
              onChanged: _onMetricTypeChanged,
              validator: (v) => v == null ? 'Select a metric' : null,
            ),
            const SizedBox(height: 16),

            // Current value
            TextFormField(
              controller: _currentValueController,
              decoration: InputDecoration(
                labelText: 'Current Value',
                hintText: 'Where are you now?',
                border: const OutlineInputBorder(),
                suffixText: _unitController.text,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter your current value';
                }
                if (double.tryParse(v.trim()) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Target value
            TextFormField(
              controller: _targetValueController,
              decoration: InputDecoration(
                labelText: 'Target Value',
                border: const OutlineInputBorder(),
                suffixText: _unitController.text,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter a target value';
                }
                if (double.tryParse(v.trim()) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Unit
            TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'Unit',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Description (optional)
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g., Reach race weight',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Deadline date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Deadline'),
              subtitle: Text(
                _deadline != null
                    ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}'
                    : 'No deadline set',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDeadline,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: theme.colorScheme.outline),
              ),
            ),
            const SizedBox(height: 16),

            // Priority
            DropdownButtonFormField<int>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: _priorityOptions
                  .map((e) => DropdownMenuItem(
                        value: e.$1,
                        child: Text(e.$2),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _priority = v);
              },
            ),
            const SizedBox(height: 32),

            // Save button
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Update Goal' : 'Create Goal'),
            ),
          ],
        ),
      ),
    );
  }
}
