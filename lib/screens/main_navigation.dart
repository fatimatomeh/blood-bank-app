import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

import 'DonorsHome_Page.dart';
import 'requests_page.dart';
import 'donate_page.dart';
import 'donor_notifications_page.dart';
import 'profile_page.dart';
import 'privacy_policy_page.dart'; // ✅ إضافة جديدة

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;
  int _unreadNotifications = 0;
  StreamSubscription? _notifSubscription;

  final _pageController = PageController(keepPage: true);

  @override
  void initState() {
    super.initState();
    _listenToUnread();
    // ✅ إضافة جديدة: فحص الموافقة على السياسة بعد بناء الـ widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPolicyAgreement();
    });
  }

  // ✅ إضافة جديدة: فحص هل وافق المستخدم على السياسة من قبل
  Future<void> _checkPolicyAgreement() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap =
        await FirebaseDatabase.instance.ref("Donors/$uid/agreedToPolicy").get();

    // لو ما في قيمة = مستخدم قديم ما شاف السياسة → نعرضها
    if (!snap.exists || snap.value != true) {
      if (mounted) _showPolicyDialog(uid);
    }
  }

  // ✅ إضافة جديدة: dialog يظهر مرة وحدة للمستخدمين القدامى
  void _showPolicyDialog(String uid) {
    showDialog(
      context: context,
      barrierDismissible: false, // لازم يتعامل معه، ما يقدر يتجاهله
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.red, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "تحديث سياسة الخصوصية",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "قمنا بتحديث سياسة الخصوصية وشروط الاستخدام الخاصة بتطبيق VivaLink.",
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            SizedBox(height: 12),
            Text(
              "يرجى مراجعة السياسة والموافقة عليها للاستمرار في استخدام التطبيق.",
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          // زر عرض السياسة
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.open_in_new,
                color: Colors.red, size: 16),
            label: const Text("عرض السياسة",
                style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyPage()),
            ),
          ),
          // زر الموافقة
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              // نحفظ الموافقة في Firebase
              await FirebaseDatabase.instance
                  .ref("Donors/$uid")
                  .update({
                'agreedToPolicy': true,
                'agreedToPolicyAt': DateTime.now().toString(),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text("أوافق وأكمل",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _listenToUnread() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _notifSubscription = FirebaseDatabase.instance
        .ref("Donors/$uid/notifications")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        setState(() => _unreadNotifications = 0);
        return;
      }
      int count = 0;
      Map<String, dynamic>.from(event.snapshot.value as Map)
          .forEach((key, value) {
        if (value is Map) {
          final n = Map<String, dynamic>.from(value);
          if (n['isRead'] != true) count++;
        }
      });
      setState(() => _unreadNotifications = count);
    });
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    setState(() => currentIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _KeepAlivePage(child: DonorsHomePage()),
          _KeepAlivePage(child: RequestsPage()),
          _KeepAlivePage(child: DonatePage()),
          _KeepAlivePage(child: DonorNotificationsPage()),
          _KeepAlivePage(child: ProfilePage()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _onTap,
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.home), label: "الرئيسية"),
          const BottomNavigationBarItem(
              icon: Icon(Icons.list), label: "الطلبات"),
          const BottomNavigationBarItem(
              icon: Icon(Icons.bloodtype), label: "تبرع"),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6)),
                      constraints: const BoxConstraints(
                          minWidth: 14, minHeight: 14),
                      child: Text(
                        _unreadNotifications > 9
                            ? "9+"
                            : "$_unreadNotifications",
                        style: const TextStyle(
                            color: Colors.white, fontSize: 9),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: "الإشعارات",
          ),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person), label: "حسابي"),
        ],
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}