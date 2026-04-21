import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// خدمة المؤقت - تُخزَّن في Firebase لتستمر بين الصفحات
class DonationTimerService {
  // الحالات:
  // 'في الطريق'  → المتبرع ضغط تبرع والمؤقت شغّال
  // 'قيد الوصول' → انتهى الوقت، المتبرع في طريقه (ينتظر تأكيد الموظف)
  // 'تم التبرع'  → أكّد الموظف التبرع

  static Future<void> startTimer({
    required String requestId,
    required String hospitalId,
    required String hospitalName,
    required String bloodType,
    required double arrivalHours,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final durationSeconds = (arrivalHours * 3600).round();
    final now = DateTime.now().millisecondsSinceEpoch;

    await FirebaseDatabase.instance.ref("Donors/$uid/activeTimer").set({
      'startedAt': now,
      'durationSeconds': durationSeconds,
      'requestId': requestId,
      'hospitalId': hospitalId,
      'hospitalName': hospitalName,
      'bloodType': bloodType,
      'status': 'في الطريق',
    });
  }

  /// انتهى الوقت → غيّر الحالة لقيد الوصول (ينتظر الموظف يأكد)
  static Future<void> markAsArriving(String uid) async {
    await FirebaseDatabase.instance
        .ref("Donors/$uid/activeTimer")
        .update({'status': 'قيد الوصول'});
  }

  /// الموظف أكّد التبرع
  static Future<void> confirmArrival(String uid) async {
    await FirebaseDatabase.instance
        .ref("Donors/$uid/activeTimer")
        .update({'status': 'تم التبرع'});
  }

  /// حذف المؤقت بعد اكتمال العملية
  static Future<void> clearTimer(String uid) async {
    await FirebaseDatabase.instance.ref("Donors/$uid/activeTimer").remove();
  }

  static int getRemainingSeconds(Map<String, dynamic> timerData) {
    final startedAt = timerData['startedAt'] as int? ?? 0;
    final duration = timerData['durationSeconds'] as int? ?? 900;
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - startedAt) ~/ 1000;
    final remaining = duration - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  static bool isExpired(Map<String, dynamic> timerData) {
    return getRemainingSeconds(timerData) <= 0;
  }

  static String formatTime(int seconds) {
    if (seconds >= 3600) {
      final h = seconds ~/ 3600;
      final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final s = (seconds % 60).toString().padLeft(2, '0');
      return "$h:$m:$s";
    }
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  static String arrivalLabel(String value) {
    switch (value) {
      case '0.25':
        return 'ربع ساعة';
      case '0.5':
        return 'نص ساعة';
      case '1':
        return 'ساعة';
      case '2':
        return 'ساعتين';
      case '3':
        return '3 ساعات';
      default:
        return '$value ساعات';
    }
  }
}