import 'reminder_scheduler_web.dart'
    if (dart.library.io) 'reminder_scheduler_io.dart' as impl;

/// Platform-agnostic local-notification scheduler.
///
/// The concrete backend is chosen at compile time: a real
/// `flutter_local_notifications` implementation on mobile/desktop (dart:io), and
/// a no-op on web — so the web build never imports the native plugin and stays
/// buildable. Callers always get a valid object; check [supported] to know
/// whether an OS notification can actually fire.
abstract class ReminderScheduler {
  /// True when this platform can fire OS-scheduled local notifications.
  bool get supported;

  Future<void> init();

  /// Schedule a one-off notification for [when]. Returns true when an OS
  /// notification was actually set (false on web, denied permission, a past
  /// time, or exact-alarm restrictions).
  Future<bool> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  });

  Future<void> cancel(int id);
}

ReminderScheduler makeReminderScheduler() => impl.createReminderScheduler();
