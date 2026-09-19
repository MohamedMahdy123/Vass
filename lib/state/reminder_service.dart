import 'package:flutter/foundation.dart';

import '../services/reminders/reminder_scheduler.dart';

/// A reminder the user has scheduled for a planned outfit.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.when,
    required this.occasion,
    required this.dateLabel,
    required this.osNotified,
  });

  final int id;
  final DateTime when;
  final String occasion;
  final String dateLabel;

  /// True when a real OS notification was scheduled (mobile). False on web,
  /// where the reminder is recorded in-app but can't fire a push.
  final bool osNotified;
}

/// Owns outfit reminders: schedules the local notification (native) and keeps
/// an in-app record so the reminder is visible everywhere, including web where
/// OS notifications aren't available.
class ReminderService extends ChangeNotifier {
  final ReminderScheduler _scheduler = makeReminderScheduler();
  final List<ScheduledReminder> _reminders = [];

  /// Whether this platform can fire OS-scheduled local notifications.
  bool get osSupported => _scheduler.supported;

  List<ScheduledReminder> get reminders => List.unmodifiable(_reminders);

  Future<void> init() => _scheduler.init();

  /// Schedule (or replace) a reminder for a planned outfit. [id] should be
  /// stable per day so re-scheduling the same day replaces the old reminder.
  /// Returns true if an OS notification was actually set.
  Future<bool> schedule({
    required int id,
    required DateTime when,
    required String occasion,
    required String dateLabel,
    required String title,
    required String body,
  }) async {
    await _scheduler.cancel(id);
    _reminders.removeWhere((r) => r.id == id);

    final os = await _scheduler.schedule(
      id: id,
      when: when,
      title: title,
      body: body,
    );
    _reminders.add(ScheduledReminder(
      id: id,
      when: when,
      occasion: occasion,
      dateLabel: dateLabel,
      osNotified: os,
    ));
    _reminders.sort((a, b) => a.when.compareTo(b.when));
    notifyListeners();
    return os;
  }

  Future<void> cancel(int id) async {
    await _scheduler.cancel(id);
    _reminders.removeWhere((r) => r.id == id);
    notifyListeners();
  }
}
