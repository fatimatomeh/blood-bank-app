import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'edit_profile_page.dart';
import 'ChangePasswardPage.dart'; // نفس اسم الملف عندك

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("users/fatima");
  Map userData = {};

  @override
  void initState() {
    super.initState();
    dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          userData = data;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        title:
            const Text("حسابي", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(userData['name'] ?? "الاسم غير متوفر",
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text("🩸 فصيلة الدم: ${userData['bloodType'] ?? 'غير محدد'}",
                style: const TextStyle(fontSize: 16)),
            Text("📍 ${userData['city'] ?? 'غير محدد'}",
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 25),
            sectionTitle("معلوماتي الشخصية"),
            infoCard([
              infoRow(Icons.person, "الاسم الكامل",
                  userData['name'] ?? 'غير متوفر'),
              infoRow(Icons.email, "البريد الإلكتروني",
                  userData['email'] ?? 'غير متوفر'),
              infoRow(
                  Icons.phone, "رقم الهاتف", userData['phone'] ?? 'غير متوفر'),
            ]),
            const SizedBox(height: 20),
            sectionTitle("معلومات التبرع"),
            infoCard([
              infoRow(Icons.calendar_today, "آخر تبرع",
                  userData['lastDonation'] ?? 'غير متوفر'),
              infoRow(Icons.favorite, "عدد التبرعات",
                  userData['donationsCount']?.toString() ?? '0'),
            ]),
            const SizedBox(height: 20),
            sectionTitle("الإعدادات"),
            infoCard([
              settingRow(Icons.edit, "تعديل الحساب", () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const EditProfilePage()),
                );
              }),
              settingRow(Icons.lock, "تغيير كلمة المرور", () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ChangePasswordPage()),
                );
              }),
            ]),
          ],
        ),
      ),
    );
  }

  // الدوال المساعدة
  Widget sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(text,
          style: const TextStyle(
              fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold)),
    );
  }

  Widget infoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ]),
      child: Column(children: children),
    );
  }

  Widget infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, color: Colors.red),
        const SizedBox(width: 10),
        Text(title),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
      ]),
    );
  }

  Widget settingRow(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap);
  }
}
