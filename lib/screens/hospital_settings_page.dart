import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'signin_page.dart';
import 'city_helper.dart';
import 'hospital_edit_profile_page.dart';
import 'hospital_change_password_page.dart';

class HospitalSettingsPage extends StatefulWidget {
  const HospitalSettingsPage({super.key});

  @override
  State<HospitalSettingsPage> createState() => _HospitalSettingsPageState();
}

class _HospitalSettingsPageState extends State<HospitalSettingsPage> {
  Map<String, dynamic> hospitalData = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap =
        await FirebaseDatabase.instance.ref("Hospitals/${user.uid}").get();
    if (snap.exists && snap.value is Map) {
      setState(
          () => hospitalData = Map<String, dynamic>.from(snap.value as Map));
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

  void _showEditHospitalDialog() {
    final nameController =
        TextEditingController(text: hospitalData['name'] ?? "");
    String? selectedCity =
        CityHelper.normalize(hospitalData['city']?.toString());
    if (!CityHelper.arabicCities.contains(selectedCity)) selectedCity = null;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("تعديل بيانات المستشفى",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  validator: (v) =>
                      v == null || v.isEmpty ? "أدخل اسم المستشفى" : null,
                  decoration: InputDecoration(
                    labelText: "اسم المستشفى",
                    prefixIcon:
                        const Icon(Icons.local_hospital, color: Colors.red),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedCity,
                  validator: (v) => v == null ? "اختر المدينة" : null,
                  decoration: InputDecoration(
                    labelText: "المدينة",
                    prefixIcon:
                        const Icon(Icons.location_city, color: Colors.red),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: CityHelper.arabicCities
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedCity = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                User? user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                await FirebaseDatabase.instance
                    .ref("Hospitals/${user.uid}")
                    .update({
                  'name': nameController.text.trim(),
                  'city': selectedCity,
                });
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("تم تحديث بيانات المستشفى ✅")),
                  );
                }
              },
              child: const Text("حفظ", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool obscure1 = true, obscure2 = true, obscure3 = true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("تغيير كلمة المرور",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _passField(
                  controller: currentPassController,
                  label: "كلمة المرور الحالية",
                  obscure: obscure1,
                  toggle: () => setDialogState(() => obscure1 = !obscure1),
                  validator: (v) =>
                      v == null || v.isEmpty ? "هذا الحقل مطلوب" : null,
                ),
                const SizedBox(height: 12),
                _passField(
                  controller: newPassController,
                  label: "كلمة المرور الجديدة",
                  obscure: obscure2,
                  toggle: () => setDialogState(() => obscure2 = !obscure2),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "هذا الحقل مطلوب";
                    if (v.length < 8) return "8 أحرف على الأقل";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _passField(
                  controller: confirmPassController,
                  label: "تأكيد كلمة المرور",
                  obscure: obscure3,
                  toggle: () => setDialogState(() => obscure3 = !obscure3),
                  validator: (v) => v != newPassController.text
                      ? "كلمتا المرور غير متطابقتين"
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  User? user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  final cred = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentPassController.text,
                  );
                  await user.reauthenticateWithCredential(cred);
                  await user.updatePassword(newPassController.text);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("تم تغيير كلمة المرور بنجاح ✅")),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("كلمة المرور الحالية غير صحيحة")),
                    );
                  }
                }
              },
              child: const Text("تحديث", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.red),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
        title: const Text("الإعدادات",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10)
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.local_hospital, color: Colors.red, size: 50),
                  const SizedBox(height: 10),
                  Text(
                    hospitalData['hospitalName'] ?? "جاري التحميل...",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "📍 ${hospitalData['city'] ?? ''}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    user?.email ?? "",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle("معلومات الحساب"),
            _infoCard([
              _infoRow(Icons.local_hospital, "اسم المستشفى",
                  hospitalData['hospitalName'] ?? 'غير متوفر'),
              _infoRow(Icons.location_city, "المدينة",
                  hospitalData['city'] ?? 'غير متوفر'),
              _infoRow(
                  Icons.email, "البريد الإلكتروني", user?.email ?? 'غير متوفر'),
            ]),
            const SizedBox(height: 20),
            _sectionTitle("الإعدادات"),
            _infoCard([
              _settingRow(Icons.edit, "تعديل بيانات المستشفى", () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const HospitalEditProfilePage()),
                );
                if (updated == true) _loadData();
              }),
              _settingRow(Icons.lock, "تغيير كلمة المرور", () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const HospitalChangePasswordPage()),
                );
              }),
            ]),
            const SizedBox(height: 20),
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
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("تسجيل الخروج"),
                    content: const Text("هل أنت متأكد من تسجيل الخروج؟"),
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
                        child: const Text("تأكيد",
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
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
            ]),
        child: Column(children: children),
      );

  Widget _infoRow(IconData icon, String title, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, color: Colors.red),
          const SizedBox(width: 10),
          Text(title),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
        ]),
      );

  Widget _settingRow(IconData icon, String title, VoidCallback onTap) =>
      ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      );
}
