import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/auth/presentation/auth_provider.dart';
import 'package:welltrack/features/auth/domain/auth_state.dart';
import 'package:welltrack/features/profile/presentation/profile_provider.dart';
import 'package:welltrack/features/reminders/data/notification_service.dart';
import 'package:welltrack/features/reminders/data/reminder_repository.dart';
import 'package:welltrack/features/reminders/domain/reminder_entity.dart';
import 'package:intl/intl.dart';

/// Provider for reminders list
final remindersProvider = FutureProvider.autoDispose<List<ReminderEntity>>((ref) async {
  final profileAsync = ref.watch(activeProfileProvider);
  final profileId = profileAsync.valueOrNull?.id;

  if (profileId == null) {
    return [];
  }

  final repository = ref.watch(reminderRepositoryProvider);
  return repository.getAllReminders(profileId);
});

/// Screen for managing reminders
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(context),
            tooltip: 'Help',
          ),
        ],
      ),
      body: remindersAsync.when(
        data: (reminders) => _buildRemindersList(context, ref, reminders),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading reminders: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(remindersProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddReminderDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRemindersList(BuildContext context, WidgetRef ref, List<ReminderEntity> reminders) {
    if (reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No reminders yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to create your first reminder',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    // Group reminders by module
    final groupedReminders = <String, List<ReminderEntity>>{};
    for (final reminder in reminders) {
      groupedReminders.putIfAbsent(reminder.module, () => []).add(reminder);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedReminders.length,
      itemBuilder: (context, index) {
        final module = groupedReminders.keys.elementAt(index);
        final moduleReminders = groupedReminders[module]!;

        return _buildModuleSection(context, ref, module, moduleReminders);
      },
    );
  }

  Widget _buildModuleSection(
    BuildContext context,
    WidgetRef ref,
    String module,
    List<ReminderEntity> reminders,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(_getModuleIcon(module), size: 20),
              const SizedBox(width: 8),
              Text(
                _getModuleDisplayName(module),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        ...reminders.map((reminder) => _buildReminderCard(context, ref, reminder)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildReminderCard(BuildContext context, WidgetRef ref, ReminderEntity reminder) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y h:mm a');

    return Dismissible(
      key: Key(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Reminder'),
            content: const Text('Are you sure you want to delete this reminder?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await ref.read(reminderRepositoryProvider).deleteReminder(reminder.id);
        await ref.read(notificationServiceProvider).cancelNotification(reminder.id);
        ref.refresh(remindersProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder deleted')),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(
            reminder.isActive ? Icons.notifications_active : Icons.notifications_off,
            color: reminder.isActive ? theme.colorScheme.primary : theme.colorScheme.outline,
          ),
          title: Text(reminder.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reminder.body),
              const SizedBox(height: 4),
              Text(
                '${dateFormat.format(reminder.remindAt)}${reminder.repeatRule != null && reminder.repeatRule != 'once' ? ' • ${reminder.repeatRule}' : ''}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          trailing: Switch(
            value: reminder.isActive,
            onChanged: (value) async {
              await ref.read(reminderRepositoryProvider).toggleActive(reminder.id, value);

              if (value) {
                // Schedule notification
                await ref.read(notificationServiceProvider).scheduleRepeatingNotification(reminder);
              } else {
                // Cancel notification
                await ref.read(notificationServiceProvider).cancelNotification(reminder.id);
              }

              ref.refresh(remindersProvider);
            },
          ),
          isThreeLine: true,
        ),
      ),
    );
  }

  void _showAddReminderDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const AddReminderForm(),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reminders Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Set reminders for:'),
              SizedBox(height: 8),
              Text('• Supplements and vitamins'),
              Text('• Meal prep and planning'),
              Text('• Workout sessions'),
              Text('• Custom wellness tasks'),
              SizedBox(height: 16),
              Text('Repeat Options:'),
              SizedBox(height: 8),
              Text('• Once - Single reminder'),
              Text('• Daily - Every day at the same time'),
              Text('• Weekly - Same day and time each week'),
              SizedBox(height: 16),
              Text('Swipe left to delete a reminder.'),
              Text('Toggle the switch to activate/deactivate.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  IconData _getModuleIcon(String module) {
    switch (module) {
      case 'supplements':
        return Icons.medication;
      case 'meals':
        return Icons.restaurant;
      case 'workouts':
        return Icons.fitness_center;
      default:
        return Icons.notifications;
    }
  }

  String _getModuleDisplayName(String module) {
    switch (module) {
      case 'supplements':
        return 'Supplements';
      case 'meals':
        return 'Meals';
      case 'workouts':
        return 'Workouts';
      default:
        return 'Custom';
    }
  }
}

/// Form for adding a new reminder
class AddReminderForm extends ConsumerStatefulWidget {
  const AddReminderForm({super.key});

  @override
  ConsumerState<AddReminderForm> createState() => _AddReminderFormState();
}

class _AddReminderFormState extends ConsumerState<AddReminderForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String _selectedModule = 'custom';
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedRepeat = 'once';

  final List<String> _modules = ['supplements', 'meals', 'workouts', 'custom'];
  final List<String> _repeatOptions = ['once', 'daily', 'weekly'];

  // Quick-add templates
  final Map<String, Map<String, String>> _templates = {
    'Supplement reminder': {
      'module': 'supplements',
      'title': 'Take supplements',
      'body': 'Time to take your daily supplements',
    },
    'Workout reminder': {
      'module': 'workouts',
      'title': 'Workout time',
      'body': 'Time for your scheduled workout',
    },
    'Meal prep reminder': {
      'module': 'meals',
      'title': 'Meal prep',
      'body': 'Time to prepare your meals',
    },
  };

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  void _applyTemplate(String templateName) {
    final template = _templates[templateName]!;
    setState(() {
      _selectedModule = template['module']!;
      _titleController.text = template['title']!;
      _bodyController.text = template['body']!;
    });
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    final profileAsync = ref.read(activeProfileProvider);
    final profileId = profileAsync.valueOrNull?.id;

    if (profileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No profile selected')),
      );
      return;
    }

    final remindAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final reminder = ReminderEntity(
      id: '',
      profileId: profileId,
      module: _selectedModule,
      title: _titleController.text,
      body: _bodyController.text,
      remindAt: remindAt,
      repeatRule: _selectedRepeat,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final saved = await ref.read(reminderRepositoryProvider).createReminder(reminder);
      await ref.read(notificationServiceProvider).scheduleRepeatingNotification(saved);
      ref.refresh(remindersProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder created')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating reminder: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEE, MMM d, y');

    return Container(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New Reminder', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            // Quick templates
            const Text('Quick Templates:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _templates.keys.map((name) => ActionChip(
                label: Text(name),
                onPressed: () => _applyTemplate(name),
              )).toList(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedModule,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _modules.map((module) {
                return DropdownMenuItem(
                  value: module,
                  child: Text(module[0].toUpperCase() + module.substring(1)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedModule = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a message';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(dateFormat.format(_selectedDate)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_selectedTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRepeat,
              decoration: const InputDecoration(
                labelText: 'Repeat',
                border: OutlineInputBorder(),
              ),
              items: _repeatOptions.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(option[0].toUpperCase() + option.substring(1)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedRepeat = value);
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveReminder,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Create Reminder'),
            ),
          ],
        ),
      ),
    );
  }
}
