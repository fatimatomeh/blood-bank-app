import 'package:flutter/material.dart';
import 'DonorsHome_Page.dart';
import 'requests_page.dart';
import 'donate_page.dart';
import 'profile_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;

  // ✅ FIX: لا تحفظ الصفحات كـ const field ثابت
  // بناؤها داخل build يضمن إنها تتجدد وتقرأ البيانات صح
  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const DonorsHomePage();
      case 1:
        return const RequestsPage();
      case 2:
        return const DonatePage();
      case 3:
        return const ProfilePage();
      default:
        return const DonorsHomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: [
          const DonorsHomePage(),
          const RequestsPage(),
          const DonatePage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "الرئيسية"),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "الطلبات"),
          BottomNavigationBarItem(
              icon: Icon(Icons.bloodtype), label: "تبرع"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "حسابي"),
        ],
      ),
    );
  }
}