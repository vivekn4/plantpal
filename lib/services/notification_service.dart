import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Stable notification id per plant, masked to a positive 31-bit int
/// so rescheduling replaces rather than duplicates.
int notificationIdFor(String plantId) => plantId.hashCode & 0x7fffffff;

/// Reminder time: 09:00 local on the due date — a friendly hour, not
/// midnight (ARCHITECTURE.md 6.4). If that hour already passed, the
/// due instant itself is used when it is still in the future.
/// Pure, so tests can pin it down.
DateTime reminderTimeUtc(DateTime dueUtc, DateTime nowUtc) {
  final local = dueUtc.toLocal();
  final nineAm = DateTime(local.year, local.month, local.day, 9).toUtc();
  if (nineAm.isAfter(nowUtc)) return nineAm;
  if (dueUtc.isAfter(nowUtc)) return dueUtc;
  return nineAm;
}

/// Local notifications on Android; a no-op guard on web, where
/// background notifications are not promised (PLAN.md 1).
/// The in-app due state is always the backup — a notification is a
/// bonus, the home screen is the truth (PLAN.md bug 1).
class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        settings: const InitializationSettings(android: android),
      );
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> scheduleWatering({
    required int id,
    required String plantName,
    required DateTime dueUtc,
  }) async {
    if (kIsWeb || !_ready) return;
    final nowUtc = DateTime.now().toUtc();
    final remindAt = reminderTimeUtc(dueUtc, nowUtc);
    if (!remindAt.isAfter(nowUtc)) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'plantpal_watering',
          'Watering reminders',
          channelDescription: 'Reminds you when a plant needs water.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );
      // Scheduled against UTC so the absolute instant is right no
      // matter what the device time zone is set to.
      await _plugin.zonedSchedule(
        id: id,
        title: 'Time to water $plantName',
        body: '$plantName is ready for a drink.',
        scheduledDate: tz.TZDateTime.from(remindAt, tz.UTC),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Notification failure must never break watering itself.
    }
  }

  Future<void> cancel(int id) async {
    if (kIsWeb || !_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {
      // Ignore: the in-app state is the source of truth.
    }
  }
}
