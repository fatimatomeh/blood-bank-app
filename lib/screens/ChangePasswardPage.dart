import 'package:flutter/material.dart';

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

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) return "هذا الحقل مطلوب";
    if (value.length < 8) return "يجب أن تكون 8 خانات على الأقل";
    if (!RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    ).hasMatch(value)) {
      return "كلمة المرور لا تستوفي الشروط المطلوبة";
    }
    if (value.contains(' ')) return "لا يسمح بوجود مسافات";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "تغيير كلمة المرور",
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
              buildPasswordField(
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
              buildPasswordField(
                controller: _newPasswordController,
                label: "كلمة المرور الجديدة",
                isObscure: _isNewPasswordObscure,
                toggleObscure: () => setState(
                  () => _isNewPasswordObscure = !_isNewPasswordObscure,
                ),
                validator: _validateNewPassword,
              ),
              const SizedBox(height: 15),
              const Text(
                "يجب أن تحتوي كلمة المرور على:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              buildValidationRule("8 أحرف على الأقل"),
              buildValidationRule("حرف كبير (A-Z) وحرف صغير (a-z)"),
              buildValidationRule("رقم واحد على الأقل (0-9)"),
              buildValidationRule("رمز خاص واحد على الأقل (@#%&*)"),
              buildValidationRule("بدون مسافات"),
              const SizedBox(height: 25),
              buildPasswordField(
                controller: _confirmPasswordController,
                label: "تأكيد كلمة المرور الجديدة",
                isObscure: _isConfirmPasswordObscure,
                toggleObscure: () => setState(
                  () => _isConfirmPasswordObscure = !_isConfirmPasswordObscure,
                ),
                validator: (value) {
                  if (value != _newPasswordController.text) {
                    return "كلمة المرور غير متطابقة";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
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
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("تم تحديث كلمة المرور بنجاح"),
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
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

  Widget buildValidationRule(String ruleText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.red),
          const SizedBox(width: 10),
          Text(
            ruleText,
            style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }

  Widget buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isObscure,
    required VoidCallback toggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
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
