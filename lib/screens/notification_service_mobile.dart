import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';

final FlutterLocalNotificationsPlugin _localNotif =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'vivalink_high',
  'VivaLink Notifications',
  importance: Importance.max,
  playSound: true,
);

Future<void> initMobile(
  String appId,
  Future<void> Function(String) savePlayerId,
  Future<void> Function() setUserTags,
) async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await _localNotif.initialize(
    const InitializationSettings(android: android, iOS: ios),
  );
  await _localNotif
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);

  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize(appId);
  await OneSignal.Notifications.requestPermission(true);

  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    event.notification.display();
  });

  OneSignal.Notifications.addClickListener((event) {
    debugPrint("📲 ضغط على إشعار: ${event.notification.title}");
  });

  OneSignal.User.pushSubscription.addObserver((state) {
    final playerId = state.current.id;
    if (playerId != null && playerId.isNotEmpty) {
      savePlayerId(playerId);
      setUserTags();
    }
  });

  final currentId = OneSignal.User.pushSubscription.id;
  if (currentId != null && currentId.isNotEmpty) {
    await savePlayerId(currentId);
    await setUserTags();
  }
}

Future<void> setUserTagsMobile(String uid) async {
  final donorSnap = await FirebaseDatabase.instance.ref("Donors/$uid").get();
  if (donorSnap.exists && donorSnap.value is Map) {
    final data = Map<String, dynamic>.from(donorSnap.value as Map);
    OneSignal.User.addTagWithKey("user_type", "donor");
    OneSignal.User.addTagWithKey("city", data['city']?.toString() ?? "");
    OneSignal.User.addTagWithKey(
        "blood_type", data['bloodType']?.toString() ?? "");
    return;
  }

  final hospSnap = await FirebaseDatabase.instance.ref("Hospitals/$uid").get();
  if (hospSnap.exists && hospSnap.value is Map) {
    final data = Map<String, dynamic>.from(hospSnap.value as Map);
    OneSignal.User.addTagWithKey("user_type", "hospital");
    OneSignal.User.addTagWithKey("city", data['city']?.toString() ?? "");
    return;
  }

  final staffSnap =
      await FirebaseDatabase.instance.ref("BloodBankStaff/$uid").get();
  if (staffSnap.exists && staffSnap.value is Map) {
    final data = Map<String, dynamic>.from(staffSnap.value as Map);
    OneSignal.User.addTagWithKey("user_type", "staff");
    OneSignal.User.addTagWithKey("city", data['city']?.toString() ?? "");
  }
}

Future<void> showLocalNotificationMobile({
  required String title,
  required String body,
}) async {
  await _localNotif.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF8b0000),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
  );
}
