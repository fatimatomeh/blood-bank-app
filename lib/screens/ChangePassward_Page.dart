import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({Key? key}) : super(key: key);

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isCurrentPasswordObscure = true;
  bool _isNewPasswordObscure = true;
  bool _isConfirmPasswordObscure = true;
  bool _isLoading = false;

  // ── real-time validation flags ──
  bool hasMinLength = false;
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecialChar = false;
  bool hasNoSpaces = true;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم تحديث كلمة المرور بنجاح ✅"),
            backgroundColor: Colors.green,
          ),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        backgroundColor: Colors.red,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "تغيير كلمة المرور",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── أيقونة وسط ──
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

              // ── كلمة المرور الحالية ──
              _buildPasswordField(
                controller: _currentPasswordController,
                label: "كلمة المرور الحالية",
                isObscure: _isCurrentPasswordObscure,
                toggleObscure: () => setState(
                  () => _isCurrentPasswordObscure = !_isCurrentPasswordObscure,
                ),
              ),
              const SizedBox(height: 25),
              const Divider(),
              const SizedBox(height: 25),

              // ── كلمة المرور الجديدة ──
              _buildPasswordField(
                controller: _newPasswordController,
                label: "كلمة المرور الجديدة",
                isObscure: _isNewPasswordObscure,
                toggleObscure: () => setState(
                  () => _isNewPasswordObscure = !_isNewPasswordObscure,
                ),
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

              // ── chips real-time ──
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip("8 أحرف+", hasMinLength),
                  _chip("حرف كبير", hasUppercase),
                  _chip("حرف صغير", hasLowercase),
                  _chip("رقم", hasNumber),
                  _chip("رمز خاص", hasSpecialChar),
                  _chip("بدون مسافات", hasNoSpaces),
                ],
              ),
              const SizedBox(height: 25),

              // ── تأكيد كلمة المرور ──
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: "تأكيد كلمة المرور الجديدة",
                isObscure: _isConfirmPasswordObscure,
                toggleObscure: () => setState(
                  () =>
                      _isConfirmPasswordObscure = !_isConfirmPasswordObscure,
                ),
                validator: (value) {
                  if (value != _newPasswordController.text) {
                    return "كلمة المرور غير متطابقة";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // ── زر التحديث ──
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _changePassword,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "تحديث كلمة المرور",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, bool met) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: met ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: met ? Colors.green.shade300 : Colors.red.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: met ? Colors.green.shade600 : Colors.red.shade400,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: met ? Colors.green.shade700 : Colors.red.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isObscure,
    required VoidCallback toggleObscure,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      onChanged: onChanged,
      validator: validator ??
          (value) =>
              (value == null || value.isEmpty) ? "هذا الحقل مطلوب" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.red),
        suffixIcon: IconButton(
          icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility),
          onPressed: toggleObscure,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}