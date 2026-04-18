import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

import 'hospital_home_page.dart';
import 'hospital_requests_page.dart';
import 'hospital_donors_page.dart';
import 'hospital_notifications_page.dart';
import 'hospital_settings_page.dart';

class HospitalNavigation extends StatefulWidget {
  const HospitalNavigation({super.key});

  @override
  State<HospitalNavigation> createState() => _HospitalNavigationState();
}

class _HospitalNavigationState extends State<HospitalNavigation> {
  int currentIndex = 0;
  int _unreadNotifications = 0;
  StreamSubscription? _notifSubscription;

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
        .ref("Notifications/$uid")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        setState(() => _unreadNotifications = 0);
        return;
      }
      int count = 0;
      final data =
          Map<String, dynamic>.from(event.snapshot.value as Map);
      data.forEach((key, value) {
        if (value is Map &&
            Map<String, dynamic>.from(value)['isRead'] != true) {
          count++;
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
          _KeepAlivePage(child: HospitalHomePage()),
          _KeepAlivePage(child: HospitalRequestsPage()),
          _KeepAlivePage(child: HospitalDonorsPage()),
          _KeepAlivePage(child: HospitalNotificationsPage()),
          _KeepAlivePage(child: HospitalSettingsPage()),
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
              icon: Icon(Icons.list_alt), label: "الطلبات"),
          const BottomNavigationBarItem(
              icon: Icon(Icons.people), label: "المتبرعون"),
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
              icon: Icon(Icons.settings), label: "الإعدادات"),
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