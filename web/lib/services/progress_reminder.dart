import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/l10n.dart';
import '../platform/web_alerts.dart';
import 'train_reminder.dart';

class ProgressReminder {
  ProgressReminder._();
  static final ProgressReminder instance = ProgressReminder._();

  static const _id = 1002;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool enabled = true;

  AndroidNotificationDetails get _android => AndroidNotificationDetails(
        'progress_photo',
        t.notifPhotoChannel,
        channelDescription: t.notifPhotoChannelWhy,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
      );

  DarwinNotificationDetails get _darwin => const DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
      );

  Future<void> scheduleFor(DateTime day, int intervalDays) async {
    if (!enabled) return;
    await cancel();
    if (intervalDays <= 0) return;

    if (kIsWeb) {
      final when = DateTime(day.year, day.month, day.day, 10);
      if (!when.isAfter(DateTime.now())) return;
      await WebAlerts.schedule(
        id: _id,
        title: t.notifPhotoTitle,
        body: t.notifPhotoBody(intervalDays),
        when: when,
      );
      return;
    }

    try {
      final when = atLocal(DateTime(day.year, day.month, day.day, 10));
      if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;
      await _plugin.zonedSchedule(
        id: _id,
        title: t.notifPhotoTitle,
        body: t.notifPhotoBody(intervalDays),
        scheduledDate: when,
        notificationDetails: NotificationDetails(android: _android, iOS: _darwin),
        androidScheduleMode: await reminderMode(_plugin),
      );
    } catch (e) {
      debugPrint('No se pudo programar el recordatorio de fotos: $e');
    }
  }

  Future<void> cancel() async {
    if (!enabled) return;
    if (kIsWeb) {
      await WebAlerts.cancel(_id);
      return;
    }
    try {
      await _plugin.cancel(id: _id);
    } catch (_) {}
  }
}
