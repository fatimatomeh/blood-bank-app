import 'package:flutter/material.dart';
import 'hospital_home_page.dart';
import 'hospital_requests_page.dart';
import 'hospital_donors_page.dart';
import 'hospital_settings_page.dart';

class HospitalNavigation extends StatefulWidget {
  const HospitalNavigation({super.key});

  @override
  State<HospitalNavigation> createState() => _HospitalNavigationState();
}

class _HospitalNavigationState extends State<HospitalNavigation> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    HospitalHomePage(),
    HospitalRequestsPage(),
    HospitalDonorsPage(),
    HospitalSettingsPage(),
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
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "الطلبات"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "المتبرعون"),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: "الإعدادات"),
        ],
      ),
    );
  }
}