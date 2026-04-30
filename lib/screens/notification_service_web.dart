import 'package:firebase_database/firebase_database.dart';

// نسخة الويب - كل الدوال فاضية
Future<void> initMobile(
  String appId,
  Future<void> Function(String) savePlayerId,
  Future<void> Function() setUserTags,
) async {
  // لا يوجد شي على الويب
}

Future<void> setUserTagsMobile(String uid) async {
  // لا يوجد شي على الويب
}

Future<void> showLocalNotificationMobile({
  required String title,
  required String body,
}) async {
  // لا يوجد شي على الويب
}
