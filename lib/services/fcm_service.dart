import 'db.dart';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';

const String sosChannelId = 'sos_alerts';

/// Notifications the user tapped — consumed by the router.
final notificationTapProvider = StateProvider<String?>((ref) => null);

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

/// Set up FCM: permission, token registration, foreground display, taps.
///
/// [onTapAlert] receives the alertId of a tapped SOS notification so the
/// router can open the alert detail screen.
Future<void> setupFcm({
  required String uid,
  void Function(String alertId)? onTapAlert,
}) async {
  final messaging = FirebaseMessaging.instance;

  try {
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[fcm] permission: ${settings.authorizationStatus}');
  } catch (e) {
    debugPrint('[fcm] requestPermission failed: $e');
    return; // Without permission there is nothing more to do.
  }

  if (Platform.isAndroid) {
    await localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          sosChannelId,
          'การแจ้งเตือน SOS',
          description: 'แจ้งเตือนฉุกเฉินเมื่อผู้ที่ดูแลอยู่ขอความช่วยเหลือ',
          importance: Importance.max,
        ));
  }

  await localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: (response) {
      final alertId = response.payload;
      if (alertId != null && alertId.isNotEmpty && onTapAlert != null) {
        onTapAlert(alertId);
      }
    },
  );

  await _registerToken(messaging, uid);
  messaging.onTokenRefresh.listen((_) => _registerToken(messaging, uid));

  // Foreground: show SOS messages as heads-up local notifications.
  FirebaseMessaging.onMessage.listen((message) {
    debugPrint('[fcm] onMessage: ${message.data}');
    final alertId = message.data['alertId'] as String?;
    if (message.notification != null) {
      localNotifications.show(
        alertId.hashCode,
        message.notification?.title ?? '🚨 SOS',
        message.notification?.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            sosChannelId,
            'การแจ้งเตือน SOS',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            ongoing: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: alertId,
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    final alertId = message.data['alertId'] as String?;
    if (alertId != null && onTapAlert != null) onTapAlert(alertId);
  });

  final initial = await messaging.getInitialMessage();
  if (initial != null) {
    final alertId = initial.data['alertId'] as String?;
    if (alertId != null && onTapAlert != null) onTapAlert(alertId);
  }
}

Future<void> _registerToken(FirebaseMessaging messaging, String uid) async {
  try {
    final token = await messaging.getToken();
    if (token == null) return;
    await mysosDb.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  } catch (e) {
    // Expected to fail on the emulator suite (no FCM emulator) — ignore.
    debugPrint('[fcm] token registration skipped: $e');
  }
}

/// Deliver a local test notification (used by "ทดสอบเสียงแจ้งเตือน" in settings).
Future<void> showTestNotification() async {
  await localNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    '🔔 ทดสอบการแจ้งเตือน',
    'หากคุณเห็นข้อความนี้ ระบบแจ้งเตือนพร้อมใช้งาน',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        sosChannelId,
        'การแจ้งเตือน SOS',
        importance: Importance.max,
        priority: Priority.max,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    ),
  );
}

/// Whether [profile] should be treated as an alert receiver (caregiver).
bool receivesAlerts(Profile? profile) => profile?.role == Role.caregiver;
