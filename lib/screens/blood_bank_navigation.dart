import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'blood_bank_broadcast_page.dart';
import 'blood_bank_home_page.dart';
import 'blood_bank_donors_page.dart';
import 'blood_bank_requests_page.dart';
import 'blood_inventory_page.dart';
import 'blood_bank_settings_page.dart';

class BloodBankNavigation extends StatefulWidget {
  final String hospitalId;
  const BloodBankNavigation({super.key, required this.hospitalId});

  @override
  State<BloodBankNavigation> createState() => _BloodBankNavigationState();
}

class _BloodBankNavigationState extends State<BloodBankNavigation> {
  int currentIndex = 0;
  int _pendingTests = 0;
  int _unreadNotifs = 0;

  StreamSubscription? _donorsSubscription;
  StreamSubscription? _notifsSubscription;

  final _pageController = PageController(keepPage: true);

  @override
  void initState() {
    super.initState();
    _listenToPendingTests();
    _listenToUnreadNotifs();
  }

  void _listenToPendingTests() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final staffSnap =
        await FirebaseDatabase.instance.ref("BloodBankStaff/$uid").get();
    if (!staffSnap.exists || staffSnap.value is! Map) return;
    final staffData = Map<String, dynamic>.from(staffSnap.value as Map);
    final staffCity = staffData['city']?.toString().trim().toLowerCase() ?? "";

    _donorsSubscription =
        FirebaseDatabase.instance.ref("Donors").onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        setState(() => _pendingTests = 0);
        return;
      }
      int count = 0;
      Map<String, dynamic>.from(event.snapshot.value as Map)
          .forEach((key, value) {
        if (value is! Map) return;
        final d = Map<String, dynamic>.from(value);

        final city = d['city']?.toString().trim().toLowerCase() ?? "";
        if (city != staffCity) return;

        final testHospitalId = d['bloodTestHospitalId']?.toString() ?? "";
        if (testHospitalId.isNotEmpty && testHospitalId != widget.hospitalId)
          return;

        final raw = d['bloodTestStatus']?.toString() ?? "";
        final hasProof = d['bloodTestProofUrl']?.toString().isNotEmpty == true;
        if (hasProof && (raw.isEmpty || raw == "معلق")) count++;
      });
      setState(() => _pendingTests = count);
    });
  }

  // ── الاستماع للإشعارات غير المقروءة ──
  void _listenToUnreadNotifs() {
    if (widget.hospitalId.isEmpty) return;

    _notifsSubscription = FirebaseDatabase.instance
        .ref("Notifications/${widget.hospitalId}")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        setState(() => _unreadNotifs = 0);
        return;
      }
      int count = 0;
      Map<String, dynamic>.from(event.snapshot.value as Map)
          .forEach((key, value) {
        if (value is! Map) return;
        final n = Map<String, dynamic>.from(value);
        if (n['isRead'] == false) count++;
      });
      setState(() => _unreadNotifs = count);
    });
  }

  @override
  void dispose() {
    _donorsSubscription?.cancel();
    _notifsSubscription?.cancel();
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
          _KeepAlivePage(child: BloodBankHomePage()),
          _KeepAlivePage(child: BloodBankDonorsPage()),
          _KeepAlivePage(child: BloodBankRequestsPage()),
          _KeepAlivePage(child: BloodBankBroadcastPage()),
          _KeepAlivePage(child: BloodBankSettingsPage()),
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

          // ── المتبرعون مع badge الفحوصات ──
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.people),
                if (_pendingTests > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(6)),
                      constraints:
                          const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text("$_pendingTests",
                          style:
                              const TextStyle(color: Colors.white, fontSize: 9),
                          textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
            label: "المتبرعون",
          ),

          const BottomNavigationBarItem(
              icon: Icon(Icons.list_alt), label: "الطلبات"),

          // ── الإشعارات مع badge الوارد ──
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.broadcast_on_personal),
                if (_unreadNotifs > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6)),
                      constraints:
                          const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text("$_unreadNotifs",
                          style:
                              const TextStyle(color: Colors.white, fontSize: 9),
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
