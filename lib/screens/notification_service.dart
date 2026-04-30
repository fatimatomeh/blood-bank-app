import 'package:flutter/foundation.dart'; // ← ضروري لـ kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── استيراد مشروط للمكتبات اللي ما تشتغل على Web ──
import 'notification_service_mobile.dart'
    if (dart.library.html) 'notification_service_web.dart';

class NotificationService {
  static const String _oneSignalAppId =
      "33c1800b-ef1a-4882-8809-138550c2a3d0";

  static Future<void> init() async {
    if (kIsWeb) {
      // على الويب ما نشغل OneSignal ولا local notifications
      debugPrint("🌐 Web platform - skipping OneSignal init");
      return;
    }

    // شغّل النسخة المحمولة فقط
    await initMobile(_oneSignalAppId, _savePlayerId, _setUserTags);
  }

  static Future<void> _savePlayerId(String playerId) async {
    if (kIsWeb) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final donorSnap =
        await FirebaseDatabase.instance.ref("Donors/$uid").get();
    if (donorSnap.exists) {
      await FirebaseDatabase.instance
          .ref("Donors/$uid")
          .update({'oneSignalId': playerId});
      return;
    }

    final hospSnap =
        await FirebaseDatabase.instance.ref("Hospitals/$uid").get();
    if (hospSnap.exists) {
      await FirebaseDatabase.instance
          .ref("Hospitals/$uid")
          .update({'oneSignalId': playerId});
      return;
    }

    await FirebaseDatabase.instance
        .ref("BloodBankStaff/$uid")
        .update({'oneSignalId': playerId});
  }

  static Future<void> _setUserTags() async {
    if (kIsWeb) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await setUserTagsMobile(uid);
  }

  static Future<void> refreshTags() async {
    if (kIsWeb) return;
    await _setUserTags();
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      debugPrint("🌐 Web: إشعار: $title - $body");
      return;
    }
    await showLocalNotificationMobile(title: title, body: body);
  }
}