import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

import 'DonorsHome_Page.dart';
import 'requests_page.dart';
import 'donate_page.dart';
import 'donor_notifications_page.dart';
import 'profile_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;
  int _unreadNotifications = 0;
  StreamSubscription? _notifSubscription;

  // ✅ PageController + PageView بدل IndexedStack لتجنب مشكلة const
  final _pageController = PageController(keepPage: true);

  @override
  void initState() {
    super.initState();
    _listenToUnread();
  }

  void _listenToUnread() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _notifSubscription = FirebaseDatabase.instance
        .ref("Donors/$uid/notification")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        setState(() => _unreadNotifications = 0);
        return;
      }
      final data =
          Map<String, dynamic>.from(event.snapshot.value as Map);
      setState(() =>
          _unreadNotifications = data['isRead'] == true ? 0 : 1);
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
      // ✅ PageView بدل IndexedStack — كل صفحة تحافظ على state-ها
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
                      child: Text("$_unreadNotifications",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9),
                          textAlign: TextAlign.center),
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

/// Wrapper يحافظ على حالة الصفحة حتى لو انتقل المستخدم لصفحة أخرى
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