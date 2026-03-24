import 'package:flutter/material.dart';
// تأكدي أن أسماء الملفات هنا تطابق الأسماء عندك في المشروع
import 'edit_profile_page.dart';
import 'change_password_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
          backgroundColor: Colors.red,
          centerTitle: true,
          title: const Text("حسابي",
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text("فاطمة محمد",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text("🩸 فصيلة الدم: O+", style: TextStyle(fontSize: 16)),
            const Text("📍 نابلس", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 25),
            sectionTitle("معلوماتي الشخصية"),
            infoCard([
              infoRow(Icons.person, "الاسم الكامل", "فاطمة محمد"),
              infoRow(Icons.email, "البريد الإلكتروني", "fatima@gmail.com"),
              infoRow(Icons.phone, "رقم الهاتف", "0591234567"),
            ]),
            const SizedBox(height: 20),
            sectionTitle("معلومات التبرع"),
            infoCard([
              infoRow(Icons.calendar_today, "آخر تبرع", "2 / يناير / 2026"),
              infoRow(Icons.favorite, "عدد التبرعات", "5 مرات"),
            ]),
            const SizedBox(height: 20),
            sectionTitle("الإعدادات"),
            infoCard([
              // هنا رجعنا الربط لصفحة التعديل
              settingRow(Icons.edit, "تعديل الحساب", () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const EditProfilePage()),
                );
              }),

              // هنا رجعنا الربط لصفحة تغيير كلمة المرور
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

  // الدوال المساعدة (نفس اللي عندك)
  Widget sectionTitle(String text) {
    return Align(
        alignment: Alignment.centerRight,
        child: Text(text,
            style: const TextStyle(
                fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold)));
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
