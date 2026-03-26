import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'edit_profile_page.dart';
import 'ChangePassward_Page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> userData = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference ref =
    FirebaseDatabase.instance.ref("Donors/$user.uid");


      DataSnapshot snapshot = await ref.get();
      if (snapshot.exists) {
        setState(() {
          userData = Map<String, dynamic>.from(snapshot.value as Map);
        });
      }
    }
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
            Text(userData['fullName'] ?? "الاسم غير متوفر",
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text("🩸 فصيلة الدم: ${userData['bloodType'] ?? 'غير محدد'}"),
            Text("📍 ${userData['city'] ?? 'غير محدد'}"),
            const SizedBox(height: 25),
            sectionTitle("معلوماتي الشخصية"),
            infoCard([
              infoRow(Icons.person, "الاسم الكامل",
                  userData['fullName'] ?? 'غير متوفر'),
              infoRow(Icons.email, "البريد الإلكتروني",
                  userData['email'] ?? 'غير متوفر'),
              infoRow(
                  Icons.phone, "رقم الهاتف", userData['phone'] ?? 'غير متوفر'),
            ]),
            const SizedBox(height: 20),
            sectionTitle("معلومات التبرع"),
            infoCard([
              infoRow(Icons.calendar_today, "آخر تبرع",
                  userData['lastDonationDate'] ?? 'غير متوفر'),
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

  Widget sectionTitle(String text) => Align(
        alignment: Alignment.centerRight,
        child: Text(text,
            style: const TextStyle(
                fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold)),
      );

  Widget infoCard(List<Widget> children) => Container(
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

  Widget infoRow(IconData icon, String title, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, color: Colors.red),
          const SizedBox(width: 10),
          Text(title),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
        ]),
      );

  Widget settingRow(IconData icon, String title, VoidCallback onTap) =>
      ListTile(
          leading: Icon(icon, color: Colors.grey),
          title: Text(title),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap);
}
