import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HospitalChangePasswordPage extends StatefulWidget {
  const HospitalChangePasswordPage({super.key});

  @override
  State<HospitalChangePasswordPage> createState() =>
      _HospitalChangePasswordPageState();
}

class _HospitalChangePasswordPageState
    extends State<HospitalChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final currentPassController = TextEditingController();
  final newPassController = TextEditingController();
  final confirmPassController = TextEditingController();

  bool obscure1 = true;
  bool obscure2 = true;
  bool obscure3 = true;
  bool isLoading = false;

  // شروط كلمة المرور
  bool hasMinLength = false;
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecialChar = false;
  bool hasNoSpaces = true;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // إعادة المصادقة
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassController.text,
      );
      await user.reauthenticateWithCredential(cred);

      // تغيير كلمة المرور
      await user.updatePassword(newPassController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم تغيير كلمة المرور بنجاح ✅")),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg;
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          msg = "كلمة المرور الحالية غير صحيحة";
        } else {
          msg = "حدث خطأ: ${e.message}";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "تغيير كلمة المرور",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // أيقونة القفل
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade100, width: 2),
                  ),
                  child: const Icon(Icons.lock_outline,
                      color: Colors.red, size: 45),
                ),
              ),
              const SizedBox(height: 30),

              // كلمة المرور الحالية
              _passField(
                controller: currentPassController,
                label: "كلمة المرور الحالية",
                obscure: obscure1,
                toggle: () => setState(() => obscure1 = !obscure1),
                validator: (v) =>
                    v == null || v.isEmpty ? "هذا الحقل مطلوب" : null,
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),

              // كلمة المرور الجديدة
              _passField(
                controller: newPassController,
                label: "كلمة المرور الجديدة",
                obscure: obscure2,
                toggle: () => setState(() => obscure2 = !obscure2),
                onChanged: (v) {
                  setState(() {
                    hasMinLength = v.length >= 8;
                    hasUppercase = v.contains(RegExp(r'[A-Z]'));
                    hasLowercase = v.contains(RegExp(r'[a-z]'));
                    hasNumber = v.contains(RegExp(r'[0-9]'));
                    hasSpecialChar =
                        v.contains(RegExp(r'[!@#\$&*~%^()_\-+=<>?/]'));
                    hasNoSpaces = !v.contains(' ');
                  });
                },
                validator: (v) {
                  if (v == null || v.isEmpty) return "هذا الحقل مطلوب";
                  if (!hasMinLength ||
                      !hasUppercase ||
                      !hasLowercase ||
                      !hasNumber ||
                      !hasSpecialChar ||
                      !hasNoSpaces) {
                    return "كلمة المرور لا تستوفي الشروط";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // شروط كلمة المرور
              _requirement("8 أحرف على الأقل", hasMinLength),
              _requirement("حرف كبير (A-Z)", hasUppercase),
              _requirement("حرف صغير (a-z)", hasLowercase),
              _requirement("رقم واحد على الأقل", hasNumber),
              _requirement("رمز خاص (@#\$%&*)", hasSpecialChar),
              _requirement("بدون مسافات", hasNoSpaces),

              const SizedBox(height: 20),

              // تأكيد كلمة المرور
              _passField(
                controller: confirmPassController,
                label: "تأكيد كلمة المرور الجديدة",
                obscure: obscure3,
                toggle: () => setState(() => obscure3 = !obscure3),
                validator: (v) => v != newPassController.text
                    ? "كلمتا المرور غير متطابقتين"
                    : null,
              ),
              const SizedBox(height: 40),

              // زر التحديث
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLoading ? null : _changePassword,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "تحديث كلمة المرور",
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
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
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.red),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _requirement(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.info_outline,
            size: 16,
            color: met ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: met ? Colors.green : Colors.blueGrey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    currentPassController.dispose();
    newPassController.dispose();
    confirmPassController.dispose();
    super.dispose();
  }
}
