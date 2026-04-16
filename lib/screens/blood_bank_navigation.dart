// =====================================================================
// blood_bank_navigation.dart — نسخة محدّثة
// أضفنا تبويب "إشعار عاجل" للموظف
// =====================================================================

import 'package:flutter/material.dart';
import 'blood_bank_home_page.dart';
import 'blood_bank_donors_page.dart';
import 'blood_bank_requests_page.dart';
import 'blood_bank_settings_page.dart';
import 'blood_bank_broadcast_page.dart'; // ← جديد

class BloodBankNavigation extends StatefulWidget {
  final String hospitalId;

  const BloodBankNavigation({super.key, required this.hospitalId});

  @override
  State<BloodBankNavigation> createState() => _BloodBankNavigationState();
}

class _BloodBankNavigationState extends State<BloodBankNavigation> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    BloodBankHomePage(),
    BloodBankDonorsPage(),
    BloodBankRequestsPage(),
    BloodBankBroadcastPage(), // ← جديد
    BloodBankSettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "الرئيسية"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "المتبرعون"),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "الطلبات"),
          BottomNavigationBarItem(
              icon: Icon(Icons.broadcast_on_personal), label: "إشعار"),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: "الإعدادات"),
        ],
      ),
    );
  }
}
