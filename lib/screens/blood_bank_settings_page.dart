import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'signin_page.dart';

class BloodBankSettingsPage extends StatefulWidget {
  const BloodBankSettingsPage({super.key});

  @override
  State<BloodBankSettingsPage> createState() => _BloodBankSettingsPageState();
}

class _BloodBankSettingsPageState extends State<BloodBankSettingsPage> {
  Map<String, dynamic> staffData = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap =
        await FirebaseDatabase.instance.ref("BloodBankStaff/$uid").get();
    if (snap.exists && snap.value is Map) {
      final raw = Map<String, dynamic>.from(snap.value as Map);

      // ✅ تحويل آمن لكل الحقول لـ String لتجنب خطأ type 'int' is not a subtype of type 'String'
      final data = raw.map((k, v) => MapEntry(k, v?.toString() ?? ""));

      // جلب اسم المستشفى من جدول Hospitals
      final hospitalId = data['hospitalId'] ?? "";
      if (hospitalId.isNotEmpty) {
        final hospSnap =
            await FirebaseDatabase.instance.ref("Hospitals/$hospitalId").get();
        if (hospSnap.exists && hospSnap.value is Map) {
          final hospRaw = Map<String, dynamic>.from(hospSnap.value as Map);
          data['hospitalName'] = hospRaw['hospitalName']?.toString() ?? "";
        }
      }

      setState(() {
        staffData = data;
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SignInPage()),
        (route) => false,
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تسجيل الخروج"),
        content: const Text("هل أنت متأكد؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text("تأكيد", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "الإعدادات",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── بطاقة الموظف ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red.shade200, width: 2),
                    ),
                    child:
                        const Icon(Icons.person, color: Colors.red, size: 40),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    staffData['name'] ?? "موظف بنك الدم",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    staffData['hospitalName'] ?? "",
                    style: const TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                  Text(
                    "📍 ${staffData['city'] ?? ''}",
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // ── معلومات الحساب ──
            _sectionTitle("معلومات الحساب"),
            _infoCard([
              _infoRow(Icons.person, "الاسم", staffData['name'] ?? "-"),
              _infoRow(Icons.email, "البريد", staffData['email'] ?? "-"),
              _infoRow(Icons.phone, "الهاتف", staffData['phone'] ?? "-"),
              _infoRow(Icons.local_hospital, "المستشفى",
                  staffData['hospitalName'] ?? "-"),
              _infoRow(
                  Icons.location_city, "المدينة", staffData['city'] ?? "-"),
            ]),

            const SizedBox(height: 20),

            // ── تسجيل الخروج ──
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  "تسجيل الخروج",
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                onPressed: _showLogoutDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(text,
              style: const TextStyle(
                  fontSize: 18,
                  color: Colors.red,
                  fontWeight: FontWeight.bold)),
        ),
      );

  Widget _infoCard(List<Widget> children) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ],
        ),
        child: Column(children: children),
      );

  Widget _infoRow(IconData icon, String title, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Icon(icon, color: Colors.red, size: 22),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );
}
