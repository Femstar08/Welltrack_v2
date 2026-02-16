import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:welltrack/features/reminders/domain/reminder_entity.dart';

/// Repository for managing reminders in Supabase
class ReminderRepository {
  final SupabaseClient _supabase;

  ReminderRepository(this._supabase);

  /// Gets all active reminders for a profile
  Future<List<ReminderEntity>> getActiveReminders(String profileId) async {
    final response = await _supabase
        .from('wt_reminders')
        .select()
        .eq('profile_id', profileId)
        .eq('is_active', true)
        .order('remind_at');

    return (response as List)
        .map((json) => ReminderEntity.fromJson(json))
        .toList();
  }

  /// Gets upcoming reminders within the next N hours
  Future<List<ReminderEntity>> getUpcomingReminders(
    String profileId,
    int nextHours,
  ) async {
    final now = DateTime.now();
    final until = now.add(Duration(hours: nextHours));

    final response = await _supabase
        .from('wt_reminders')
        .select()
        .eq('profile_id', profileId)
        .eq('is_active', true)
        .gte('remind_at', now.toIso8601String())
        .lte('remind_at', until.toIso8601String())
        .order('remind_at');

    return (response as List)
        .map((json) => ReminderEntity.fromJson(json))
        .toList();
  }

  /// Gets all reminders for a profile (including inactive)
  Future<List<ReminderEntity>> getAllReminders(String profileId) async {
    final response = await _supabase
        .from('wt_reminders')
        .select()
        .eq('profile_id', profileId)
        .order('remind_at');

    return (response as List)
        .map((json) => ReminderEntity.fromJson(json))
        .toList();
  }

  /// Gets reminders filtered by module
  Future<List<ReminderEntity>> getRemindersByModule(
    String profileId,
    String module,
  ) async {
    final response = await _supabase
        .from('wt_reminders')
        .select()
        .eq('profile_id', profileId)
        .eq('module', module)
        .order('remind_at');

    return (response as List)
        .map((json) => ReminderEntity.fromJson(json))
        .toList();
  }

  /// Creates a new reminder
  Future<ReminderEntity> createReminder(ReminderEntity reminder) async {
    final now = DateTime.now();
    final reminderData = {
      'profile_id': reminder.profileId,
      'module': reminder.module,
      'title': reminder.title,
      'body': reminder.body,
      'remind_at': reminder.remindAt.toIso8601String(),
      'repeat_rule': reminder.repeatRule,
      'is_active': reminder.isActive,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    final response = await _supabase
        .from('wt_reminders')
        .insert(reminderData)
        .select()
        .single();

    return ReminderEntity.fromJson(response);
  }

  /// Updates an existing reminder
  Future<ReminderEntity> updateReminder(ReminderEntity reminder) async {
    final reminderData = {
      'module': reminder.module,
      'title': reminder.title,
      'body': reminder.body,
      'remind_at': reminder.remindAt.toIso8601String(),
      'repeat_rule': reminder.repeatRule,
      'is_active': reminder.isActive,
      'last_triggered_at': reminder.lastTriggeredAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await _supabase
        .from('wt_reminders')
        .update(reminderData)
        .eq('id', reminder.id)
        .select()
        .single();

    return ReminderEntity.fromJson(response);
  }

  /// Deletes a reminder
  Future<void> deleteReminder(String reminderId) async {
    await _supabase.from('wt_reminders').delete().eq('id', reminderId);
  }

  /// Marks a reminder as triggered
  Future<void> markAsTriggered(String reminderId) async {
    await _supabase.from('wt_reminders').update({
      'last_triggered_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reminderId);
  }

  /// Toggles reminder active status
  Future<ReminderEntity> toggleActive(String reminderId, bool isActive) async {
    final response = await _supabase
        .from('wt_reminders')
        .update({
          'is_active': isActive,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reminderId)
        .select()
        .single();

    return ReminderEntity.fromJson(response);
  }
}

/// Provider for reminder repository
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final supabase = Supabase.instance.client;
  return ReminderRepository(supabase);
});
