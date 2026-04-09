import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'signin_page.dart';
import 'package:flutter/services.dart';

class DonorSignUpPage extends StatefulWidget {
  const DonorSignUpPage({Key? key}) : super(key: key);

  @override
  State<DonorSignUpPage> createState() => _DonorSignUpPageState();
}

class _DonorSignUpPageState extends State<DonorSignUpPage> {
  final _formKey = GlobalKey<FormState>();

  TextEditingController fullNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController diseaseController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  TextEditingController donationsCountController = TextEditingController();
  TextEditingController bloodLevelController = TextEditingController();

  String? selectedBloodType;
  String? selectedCity;
  bool? hasDisease;

  DateTime? selectedDate;
  DateTime? bloodTestDate;
  bool neverDonated = false;

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  bool hasMinLength = false;
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecialChar = false;
  bool hasNoSpaces = true;

  static const Color _primary = Color(0xFFD32F2F);
  static const Color _border = Color(0xFFBDBDBD);
  static const Color _label = Color(0xFF757575);
  static const Color _text = Color(0xFF212121);

  // ✅ بدل GoogleFonts.tajawal() — بنستخدم Theme.of(context).textTheme
  // عشان يرث الخط من main.dart مباشرة (marhey أو أي خط ثاني)
  TextStyle _bodyStyle(BuildContext context,
      {double fontSize = 16, Color? color, FontWeight? fontWeight}) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: fontSize,
          color: color ?? _text,
          fontWeight: fontWeight,
        );
  }

  TextStyle _labelStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 15,
          color: _label,
        );
  }

  InputDecoration _dec(BuildContext context, String label,
      {Widget? prefixIcon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: _labelStyle(context),
      floatingLabelStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 14,
            color: _primary,
            fontWeight: FontWeight.w600,
          ),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    Widget? prefixIcon,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: _primary, size: 26),
      decoration: _dec(context, label, prefixIcon: prefixIcon),
      // ✅ selectedItemBuilder يضمن تطبيق الخط على القيمة المختارة
      selectedItemBuilder: (ctx) => items
          .map((item) => Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  item,
                  style: _bodyStyle(context,
                      fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ))
          .toList(),
      items: items
          .map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  textAlign: TextAlign.right,
                  style: _bodyStyle(context, fontSize: 16),
                ),
              ))
          .toList(),
      onChanged: onChanged,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(14),
    );
  }

  Widget _buildDateField(
    BuildContext context, {
    required String displayText,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: _primary, size: 22),
            const SizedBox(width: 12),
            Text(
              displayText,
              style: _bodyStyle(
                context,
                fontSize: 16,
                color: displayText.contains('/') ? _text : _label,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoHint(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 6, right: 4),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 14, color: Colors.blueGrey),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontSize: 13,
                      color: Colors.blueGrey,
                    ),
              ),
            ),
          ],
        ),
      );

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 14, top: 6),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 22,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              text,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
            ),
          ],
        ),
      );

  Future<void> pickBloodTestDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => bloodTestDate = picked);
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        neverDonated = false;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedBloodType == null || selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى اختيار فصيلة الدم والمدينة")),
      );
      return;
    }
    if (hasDisease == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى تحديد هل تعاني من أمراض أم لا")),
      );
      return;
    }
    if (hasDisease == true && diseaseController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى كتابة اسم المرض")),
      );
      return;
    }
    if (bloodTestDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى اختيار تاريخ فحص الدم")),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      final user = userCredential.user!;
      await user.sendEmailVerification();
      await _saveUserData(user.uid);
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ تم إنشاء الحساب! تحقق من بريدك لتفعيل الحساب"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SignInPage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        String msg;
        if (e.code == 'email-already-in-use')
          msg = "البريد الإلكتروني مستخدم مسبقاً";
        else if (e.code == 'weak-password')
          msg = "كلمة المرور ضعيفة جداً";
        else if (e.code == 'invalid-email')
          msg = "البريد الإلكتروني غير صحيح";
        else
          msg = "خطأ: ${e.message}";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("فشل التسجيل: $e")));
      }
    }
  }

  Future<void> _saveUserData(String uid) async {
    await FirebaseDatabase.instance.ref("Donors/$uid").set({
      'uid': uid,
      'fullName': fullNameController.text.trim(),
      'email': emailController.text.trim(),
      'phone': phoneController.text.trim(),
      'bloodType': selectedBloodType,
      'city': selectedCity,
      'role': 'donor',
      'hasDisease': hasDisease ?? false,
      'hasDiseases': (hasDisease == true) ? "Y" : "N",
      'diseaseName': hasDisease == true ? diseaseController.text.trim() : "",
      'diseaseDetails': hasDisease == true ? diseaseController.text.trim() : "",
      'lastDonation': neverDonated
          ? ""
          : (selectedDate != null
              ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
              : ""),
      'donationCount': neverDonated
          ? 0
          : int.tryParse(donationsCountController.text.trim()) ?? 0,
      'bloodLevel': bloodLevelController.text.trim(),
      'lastBloodTest': bloodTestDate != null
          ? "${bloodTestDate!.day}/${bloodTestDate!.month}/${bloodTestDate!.year}"
          : "",
      'createdAt': DateTime.now().toString(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "إنشاء حساب",
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _primary,
              ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── الصورة دائرة ──────────────────────────────────
              Center(
                child: ClipOval(
                  child: Image.asset(
                    "assets/welcomepage.png",
                    height: 140,
                    width: 140,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 26),

              // ── المعلومات الشخصية ─────────────────────────────
              _sectionTitle(context, "المعلومات الشخصية"),
              TextFormField(
                controller: fullNameController,
                style: _bodyStyle(context),
                textAlign: TextAlign.right,
                validator: (v) {
                  if (v == null || v.isEmpty) return "الاسم الكامل مطلوب";
                  if (v.length < 5) return "الاسم يجب أن يكون 5 أحرف على الأقل";
                  if (!RegExp(r'^[a-zA-Z\u0600-\u06FF ]+$').hasMatch(v))
                    return "يسمح فقط بالحروف العربية أو الإنجليزية";
                  return null;
                },
                decoration: _dec(context, "الاسم الكامل",
                    prefixIcon: const Icon(Icons.person_outline,
                        color: _primary, size: 22)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                style: _bodyStyle(context),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return "البريد الإلكتروني مطلوب";
                  if (!RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                      .hasMatch(v))
                    return "أدخل بريد إلكتروني صحيح (example@gmail.com)";
                  return null;
                },
                decoration: _dec(context, "البريد الإلكتروني",
                    prefixIcon: const Icon(Icons.email_outlined,
                        color: _primary, size: 22)),
              ),
              _infoHint(context, "سيتم إرسال رابط تفعيل على هذا البريد"),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                style: _bodyStyle(context),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return "رقم الهاتف مطلوب";
                  if (!RegExp(r'^05\d{8}$').hasMatch(v))
                    return "أدخل رقم صحيح (05XXXXXXXX)";
                  return null;
                },
                decoration: _dec(context, "رقم الهاتف",
                    prefixIcon: const Icon(Icons.phone_outlined,
                        color: _primary, size: 22)),
              ),
              const SizedBox(height: 26),

              // ── معلومات التبرع ────────────────────────────────
              _sectionTitle(context, "معلومات التبرع"),
              _buildDropdown(
                context,
                label: "فصيلة الدم",
                value: selectedBloodType,
                items: ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"],
                onChanged: (v) => setState(() => selectedBloodType = v),
                prefixIcon: const Icon(Icons.bloodtype_outlined,
                    color: _primary, size: 22),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                context,
                label: "المدينة",
                value: selectedCity,
                items: [
                  "رام الله",
                  "البيرة",
                  "نابلس",
                  "الخليل",
                  "بيت لحم",
                  "جنين",
                  "طولكرم",
                  "قلقيلية",
                  "أريحا",
                  "سلفيت",
                  "طوباس"
                ],
                onChanged: (v) => setState(() => selectedCity = v),
                prefixIcon: const Icon(Icons.location_city_outlined,
                    color: _primary, size: 22),
              ),
              const SizedBox(height: 16),
              Text(
                "هل تعاني من أي أمراض؟",
                style: _labelStyle(context),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        value: true,
                        groupValue: hasDisease,
                        activeColor: _primary,
                        title: Text("نعم",
                            style: _bodyStyle(context, fontSize: 15)),
                        onChanged: (v) => setState(() => hasDisease = v),
                      ),
                    ),
                    Container(width: 1, height: 44, color: _border),
                    Expanded(
                      child: RadioListTile<bool>(
                        value: false,
                        groupValue: hasDisease,
                        activeColor: _primary,
                        title: Text("لا",
                            style: _bodyStyle(context, fontSize: 15)),
                        onChanged: (v) => setState(() => hasDisease = v),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasDisease == true) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: diseaseController,
                  style: _bodyStyle(context),
                  textAlign: TextAlign.right,
                  decoration: _dec(context, "اسم المرض",
                      prefixIcon: const Icon(Icons.medical_information_outlined,
                          color: _primary, size: 22)),
                ),
              ],
              const SizedBox(height: 26),

              // ── تاريخ آخر تبرع ────────────────────────────────
              _sectionTitle(context, "تاريخ آخر تبرع"),
              _buildDateField(
                context,
                displayText: neverDonated
                    ? "لم أتبرع من قبل"
                    : selectedDate != null
                        ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                        : "اختر التاريخ",
                onTap: pickDate,
                icon: Icons.calendar_today_outlined,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Transform.scale(
                    scale: 1.1,
                    child: Checkbox(
                      value: neverDonated,
                      activeColor: _primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      onChanged: (v) {
                        setState(() {
                          neverDonated = v!;
                          if (neverDonated) selectedDate = null;
                        });
                      },
                    ),
                  ),
                  Text("لم أقم بالتبرع من قبل",
                      style: _bodyStyle(context, fontSize: 15)),
                ],
              ),
              if (selectedDate != null && !neverDonated) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: donationsCountController,
                  style: _bodyStyle(context),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return "يرجى إدخال عدد مرات التبرع";
                    if (!RegExp(r'^[0-9]+$').hasMatch(v))
                      return "أدخل رقم صحيح";
                    return null;
                  },
                  decoration: _dec(context, "كم مرة تبرعت من قبل؟",
                      prefixIcon: const Icon(Icons.format_list_numbered,
                          color: _primary, size: 22)),
                ),
              ],
              const SizedBox(height: 26),

              // ── الفحص الطبي ───────────────────────────────────
              _sectionTitle(context, "معلومات الفحص الطبي"),
              TextFormField(
                controller: bloodLevelController,
                style: _bodyStyle(context),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: _dec(context, "نسبة الدم",
                    prefixIcon: const Icon(Icons.water_drop_outlined,
                        color: _primary, size: 22),
                    hint: "مثال: 13.5"),
                validator: (v) {
                  if (v == null || v.isEmpty) return "الرجاء إدخال نسبة الدم";
                  final n = double.tryParse(v);
                  if (n == null) return "أدخل رقم صحيح (مثال: 13.5)";
                  if (n < 5 || n > 20) return "أدخل قيمة منطقية بين 5 و 20";
                  if (n < 12) return "نسبة الدم منخفضة للتبرع";
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text("تاريخ آخر فحص دم", style: _labelStyle(context)),
              const SizedBox(height: 8),
              _buildDateField(
                context,
                displayText: bloodTestDate != null
                    ? "${bloodTestDate!.day}/${bloodTestDate!.month}/${bloodTestDate!.year}"
                    : "اختر تاريخ الفحص",
                onTap: pickBloodTestDate,
                icon: Icons.science_outlined,
              ),
              _infoHint(context, "لن يتم إزعاجك بتذكير الفحص إلا بعد 4 أشهر"),
              const SizedBox(height: 26),

              // ── كلمة المرور ───────────────────────────────────
              _sectionTitle(context, "كلمة المرور"),
              TextFormField(
                controller: passwordController,
                style: _bodyStyle(context),
                obscureText: obscurePassword,
                onChanged: (v) {
                  setState(() {
                    hasMinLength = v.length >= 8;
                    hasUppercase = v.contains(RegExp(r'[A-Z]'));
                    hasLowercase = v.contains(RegExp(r'[a-z]'));
                    hasNumber = v.contains(RegExp(r'[0-9]'));
                    hasSpecialChar =
                        v.contains(RegExp(r'[!@#\$&*~%^()_\-+=<>?/]'));
                    hasNoSpaces = !v.contains(" ");
                  });
                },
                validator: (v) {
                  if (!hasMinLength ||
                      !hasUppercase ||
                      !hasLowercase ||
                      !hasNumber ||
                      !hasSpecialChar ||
                      !hasNoSpaces) return "كلمة المرور لا تحقق الشروط";
                  return null;
                },
                decoration: _dec(context, "كلمة المرور",
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: _primary, size: 22))
                    .copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _label,
                      size: 22,
                    ),
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(context, "8 أحرف+", hasMinLength),
                  _chip(context, "حرف كبير", hasUppercase),
                  _chip(context, "حرف صغير", hasLowercase),
                  _chip(context, "رقم", hasNumber),
                  _chip(context, "رمز خاص", hasSpecialChar),
                  _chip(context, "بدون مسافات", hasNoSpaces),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordController,
                style: _bodyStyle(context),
                obscureText: obscureConfirmPassword,
                validator: (v) {
                  if (v != passwordController.text)
                    return "كلمتا المرور غير متطابقتين";
                  return null;
                },
                decoration: _dec(context, "تأكيد كلمة المرور",
                        prefixIcon: const Icon(Icons.lock_reset_outlined,
                            color: _primary, size: 22))
                    .copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _label,
                      size: 22,
                    ),
                    onPressed: () => setState(
                        () => obscureConfirmPassword = !obscureConfirmPassword),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // ── زر التسجيل ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: _primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isLoading ? null : _register,
                  child: isLoading
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          "إنشاء الحساب",
                          style:
                              Theme.of(context).textTheme.titleMedium!.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, bool met) {
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
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  fontSize: 13,
                  color: met ? Colors.green.shade700 : Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    diseaseController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    donationsCountController.dispose();
    bloodLevelController.dispose();
    super.dispose();
  }
}
