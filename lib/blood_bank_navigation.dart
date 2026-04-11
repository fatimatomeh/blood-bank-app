import 'package:flutter/material.dart';
import 'blood_bank_home_page.dart';
import 'blood_bank_donors_page.dart';
import 'blood_bank_requests_page.dart';
import 'blood_bank_settings_page.dart';

class BloodBankNavigation extends StatefulWidget {
  final String hospitalId; // ← نمرر hospitalId من صفحة تسجيل الدخول

  const BloodBankNavigation({super.key, required this.hospitalId});

  @override
  State<BloodBankNavigation> createState() => _BloodBankNavigationState();
}

class _BloodBankNavigationState extends State<BloodBankNavigation> {
  int currentIndex = 0;

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    // تمرير hospitalId للصفحات اللي تحتاجه
    pages = [
      BloodBankHomePage(hospitalId: widget.hospitalId),
      BloodBankDonorsPage(hospitalId: widget.hospitalId),
      BloodBankRequestsPage(hospitalId: widget.hospitalId),
      const BloodBankSettingsPage(),
    ];
  }

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
              icon: Icon(Icons.settings), label: "الإعدادات"),
        ],
      ),
    );
  }
}
