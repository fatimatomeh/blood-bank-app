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
  bool _showPeriodicCheckBanner = false;
  int _daysSinceLastCheck = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference ref =
          FirebaseDatabase.instance.ref("Donors/${user.uid}");

      DataSnapshot snapshot = await ref.get();
      if (snapshot.exists && snapshot.value is Map) {
        if (mounted) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          setState(() {
            userData = data;
          });
          _checkPeriodicBloodTest(data);
        }
      }
    }
  }

  void _checkPeriodicBloodTest(Map<String, dynamic> profile) {
    final checkStr =
        (profile['lastBloodTest'] ?? profile['lastDonation'])?.toString() ?? "";

    if (checkStr.isEmpty || checkStr == "غير محدد") {
      final createdAtStr = profile['createdAt']?.toString() ?? "";
      if (createdAtStr.isNotEmpty) {
        try {
          final createdAt = DateTime.parse(createdAtStr);
          final daysSince = DateTime.now().difference(createdAt).inDays;
          setState(() {
            _showPeriodicCheckBanner = daysSince >= 120;
            _daysSinceLastCheck = daysSince;
          });
          return;
        } catch (_) {}
      }
      setState(() => _showPeriodicCheckBanner = false);
      return;
    }

    try {
      final parts = checkStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final lastCheck = DateTime(year, month, day);
        final days = DateTime.now().difference(lastCheck).inDays;
        setState(() {
          _daysSinceLastCheck = days;
          _showPeriodicCheckBanner = days >= 120;
        });
      }
    } catch (_) {
      setState(() => _showPeriodicCheckBanner = false);
    }
  }

  void _updateBloodTestDate() async {
    final now = DateTime.now();
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseDatabase.instance.ref("Donors/${user.uid}").update({
      'lastBloodTest': "${now.day}/${now.month}/${now.year}",
    });

    setState(() {
      _showPeriodicCheckBanner = false;
      _daysSinceLastCheck = 0;
      userData['lastBloodTest'] = "${now.day}/${now.month}/${now.year}";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ تم تسجيل الفحص الدوري بنجاح"),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        title: const Text("حسابي",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(userData['fullName'] ?? "الاسم غير متوفر",
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            Text("🩸 فصيلة الدم: ${userData['bloodType'] ?? 'غير محدد'}"),
            Text("📍 ${userData['city'] ?? 'غير محدد'}"),

            const SizedBox(height: 20),

            // ── بانر الفحص الدوري ──
            if (_showPeriodicCheckBanner)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border:
                      Border.all(color: Colors.purple.shade300, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.science_outlined,
                            color: Colors.purple, size: 26),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "⏰ حان موعد فحصك الدوري!",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "مرّ $_daysSinceLastCheck يوماً على آخر فحص.\nيُنصح بإجراء فحص دم قبل التبرع مجدداً.",
                      style: TextStyle(
                          fontSize: 13, color: Colors.purple.shade700),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          "أجريت الفحص",
                          style: TextStyle(color: Colors.white),
                        ),
                        onPressed: _updateBloodTestDate,
                      ),
                    ),
                  ],
                ),
              ),

            if (_showPeriodicCheckBanner) const SizedBox(height: 15),

            sectionTitle("معلوماتي الشخصية"),
            infoCard([
              infoRow(Icons.person, "الاسم الكامل",
                  userData['fullName'] ?? 'غير متوفر'),
              infoRow(Icons.email, "البريد الإلكتروني",
                  userData['email'] ?? 'غير متوفر'),
              infoRow(Icons.phone, "رقم الهاتف",
                  userData['phone'] ?? 'غير متوفر'),
            ]),

            const SizedBox(height: 20),

            sectionTitle("معلومات التبرع"),
            infoCard([
              infoRow(Icons.calendar_today, "آخر تبرع",
                  userData['lastDonation'] ?? 'غير متوفر'),
              infoRow(Icons.favorite, "عدد التبرعات",
                  userData['donationCount']?.toString() ?? '0'),
              infoRow(
                Icons.science_outlined,
                "آخر فحص دم",
                userData['lastBloodTest']?.toString().isNotEmpty == true
                    ? userData['lastBloodTest'].toString()
                    : 'لم يُسجَّل',
              ),
            ]),

            const SizedBox(height: 20),

            sectionTitle("الإعدادات"),
            infoCard([
              settingRow(Icons.edit, "تعديل الحساب", () async {
                if (user != null) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EditProfilePage(donorId: user.uid),
                    ),
                  );
                  _loadUserData();
                }
              }),
              settingRow(Icons.lock, "تغيير كلمة المرور", () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ChangePasswordPage()),
                );
              }),
            ]),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget sectionTitle(String text) => Align(
        alignment: Alignment.centerRight,
        child: Text(text,
            style: const TextStyle(
                fontSize: 18,
                color: Colors.red,
                fontWeight: FontWeight.bold)),
      );

  Widget infoCard(List<Widget> children) => Container(
        padding: const EdgeInsets.all(15),
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05), blurRadius: 10)
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