import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_scheduler.dart';

/// Native backend (mobile/desktop) using flutter_local_notifications + the
/// timezone packages for correct local-time scheduling.
ReminderScheduler createReminderScheduler() => _NativeReminderScheduler();

class _NativeReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  bool get supported => true;

  @override
  Future<void> init() async {
    if (_ready) return;

    // Resolve the device's IANA zone so zonedSchedule fires at local wall-clock.
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Leave tz.local at its default (UTC) if the device zone can't resolve.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin, macOS: darwin),
    );

    // Runtime permission: Android 13+ and iOS/macOS.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _ready = true;
  }

  @override
  Future<bool> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (!_ready) await init();
    if (!when.isAfter(DateTime.now())) return false; // never schedule the past

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'vess_outfit_reminders',
            'Outfit reminders',
            channelDescription: 'Reminders for outfits you planned in Vess',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } catch (_) {
      // Exact-alarm restrictions / denied permission — fall back gracefully.
      return false;
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }
}
