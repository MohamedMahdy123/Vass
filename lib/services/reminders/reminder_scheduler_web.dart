import 'reminder_scheduler.dart';

/// Web (and any non-dart:io) backend: OS-scheduled local notifications aren't
/// available, so this is a no-op. The scheduler feature still records reminders
/// in-app; only the push itself is skipped here.
ReminderScheduler createReminderScheduler() => _WebReminderScheduler();

class _WebReminderScheduler implements ReminderScheduler {
  @override
  bool get supported => false;

  @override
  Future<void> init() async {}

  @override
  Future<bool> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async =>
      false;

  @override
  Future<void> cancel(int id) async {}
}
