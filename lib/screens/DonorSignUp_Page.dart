import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'signin_page.dart';
import 'dart:async';
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

  // دالة موحدة لتزيين الحقول باللون الأسود
  InputDecoration blackInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black),
      border: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black),
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black, width: 2),
      ),
    );
  }

  Future<void> pickBloodTestDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.red),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => bloodTestDate = picked);
    }
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        neverDonated = false;
      });
    }
  }

  Future<void> _registerUser() async {
    setState(() => isLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.red),
      ),
    );

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      await FirebaseDatabase.instance.ref("Donors/$uid").set({
        'uid': uid,
        'fullName': fullNameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'bloodType': selectedBloodType,
        'city': selectedCity,
        'hasDisease': hasDisease ?? false,
        'hasDiseases': (hasDisease == true) ? "Y" : "N",
        'diseaseName': hasDisease == true ? diseaseController.text.trim() : "",
        'diseaseDetails':
            hasDisease == true ? diseaseController.text.trim() : "",
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

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => isLoading = false);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SignInPage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ: ${e.message}")),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل الاتصال: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "إنشاء حساب",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3),
              Center(child: Image.asset("assets/welcomepage.png", height: 150)),

              // الاسم الكامل
              TextFormField(
                controller: fullNameController,
                style: const TextStyle(color: Colors.black),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "الاسم الكامل مطلوب";
                  }
                  if (value.length < 5) {
                    return "الاسم يجب أن يكون 5 أحرف على الأقل";
                  }
                  if (!RegExp(r'^[a-zA-Z\u0600-\u06FF ]+$').hasMatch(value)) {
                    return "يسمح فقط بالحروف العربية أو الإنجليزية";
                  }
                  return null;
                },
                decoration: blackInputDecoration("الاسم الكامل"),
              ),
              const SizedBox(height: 16),

              // البريد الإلكتروني
              TextFormField(
                controller: emailController,
                style: const TextStyle(color: Colors.black),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "البريد الإلكتروني مطلوب";
                  }
                  if (!RegExp(
                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                  ).hasMatch(value)) {
                    return "أدخل بريد إلكتروني صحيح (example@gmail.com)";
                  }
                  return null;
                },
                decoration: blackInputDecoration("البريد الإلكتروني"),
              ),
              const SizedBox(height: 16),

              // رقم الهاتف
              TextFormField(
                controller: phoneController,
                style: const TextStyle(color: Colors.black),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "رقم الهاتف مطلوب";
                  }
                  if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                    return "يجب أن يتكون رقم الهاتف من 10 أرقام";
                  }
                  return null;
                },
                decoration: blackInputDecoration("رقم الهاتف"),
              ),
              const SizedBox(height: 16),

              // فصيلة الدم
              DropdownButtonFormField<String>(
                value: selectedBloodType,
                style: const TextStyle(color: Colors.black),
                items: ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"]
                    .map((type) =>
                        DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedBloodType = value;
                  });
                },
                decoration: blackInputDecoration("فصيلة الدم"),
              ),
              const SizedBox(height: 16),

              // المدينة
              DropdownButtonFormField<String>(
                value: selectedCity,
                style: const TextStyle(color: Colors.black),
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
                ]
                    .map((city) =>
                        DropdownMenuItem(value: city, child: Text(city)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCity = value;
                  });
                },
                decoration: blackInputDecoration("المدينة"),
              ),
              const SizedBox(height: 16),

              // الأمراض
              const Text("هل تعاني من أي أمراض؟"),
              Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: hasDisease,
                    onChanged: (value) {
                      setState(() {
                        hasDisease = value;
                      });
                    },
                  ),
                  const Text("نعم"),
                  Radio<bool>(
                    value: false,
                    groupValue: hasDisease,
                    onChanged: (value) {
                      setState(() {
                        hasDisease = value;
                      });
                    },
                  ),
                  const Text("لا"),
                ],
              ),
              if (hasDisease == true)
                TextField(
                  controller: diseaseController,
                  style: const TextStyle(color: Colors.black),
                  decoration: blackInputDecoration("الأمراض"),
                ),
              const SizedBox(height: 16),

              // تاريخ آخر تبرع
              const Text("تاريخ آخر تبرع"),
              GestureDetector(
                onTap: pickDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    neverDonated
                        ? "لم أتبرع من قبل"
                        : selectedDate != null
                            ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                            : "اختر التاريخ",
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ),
              Row(
                children: [
                  Checkbox(
                    value: neverDonated,
                    onChanged: (value) {
                      setState(() {
                        neverDonated = value!;
                        if (neverDonated) selectedDate = null;
                      });
                    },
                  ),
                  const Text("لم أقم بالتبرع من قبل"),
                ],
              ),
              if (selectedDate != null && !neverDonated)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: donationsCountController,
                      style: const TextStyle(color: Colors.black),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "يرجى إدخال عدد مرات التبرع";
                        }
                        if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                          return "أدخل رقم صحيح";
                        }
                        return null;
                      },
                      decoration: blackInputDecoration("كم مرة تبرعت من قبل؟"),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              // ── نسبة الدم وتاريخ الفحص ──
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "معلومات الفحص الطبي",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: bloodLevelController,
                style: const TextStyle(color: Colors.black),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: blackInputDecoration("نسبة الدم ").copyWith(
                  hintText: "مثال: 13.5",
                  prefixIcon: const Icon(Icons.water_drop, color: Colors.red),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "الرجاء إدخال نسبة الدم";
                  }
                  final number = double.tryParse(value);
                  if (number == null) {
                    return "أدخل رقم صحيح (مثال: 13.5)";
                  }
                  if (number < 5 || number > 20) {
                    return "أدخل قيمة منطقية بين 5 و 20";
                  }
                  if (number < 12) {
                    return "نسبة الدم منخفضة للتبرع";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // تاريخ آخر فحص دم
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "تاريخ آخر فحص دم",
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: pickBloodTestDate,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.science_outlined, color: Colors.red),
                      const SizedBox(width: 12),
                      Text(
                        bloodTestDate != null
                            ? "${bloodTestDate!.day}/${bloodTestDate!.month}/${bloodTestDate!.year}"
                            : "اختر تاريخ الفحص",
                        style: TextStyle(
                          fontSize: 15,
                          color: bloodTestDate != null
                              ? Colors.black87
                              : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "💡 إذا أدخلت تاريخ الفحص، لن يتم إزعاجك بتذكير الفحص الدوري إلا بعد 4 أشهر",
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),

              const SizedBox(height: 20),

              // كلمة المرور
              TextFormField(
                controller: passwordController,
                style: const TextStyle(color: Colors.black),
                obscureText: obscurePassword,
                onChanged: (value) {
                  setState(() {
                    hasMinLength = value.length >= 8;
                    hasUppercase = value.contains(RegExp(r'[A-Z]'));
                    hasLowercase = value.contains(RegExp(r'[a-z]'));
                    hasNumber = value.contains(RegExp(r'[0-9]'));
                    hasSpecialChar =
                        value.contains(RegExp(r'[!@#\$&*~%^()_\-+=<>?/]'));
                    hasNoSpaces = !value.contains(" ");
                  });
                },
                validator: (value) {
                  if (!hasMinLength ||
                      !hasUppercase ||
                      !hasLowercase ||
                      !hasNumber ||
                      !hasSpecialChar ||
                      !hasNoSpaces) {
                    return "كلمة المرور لا تحقق الشروط";
                  }
                  return null;
                },
                decoration: blackInputDecoration("كلمة المرور").copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              buildRequirement("8 أحرف على الأقل", hasMinLength),
              buildRequirement("يحتوي على حرف كبير", hasUppercase),
              buildRequirement("يحتوي على حرف صغير", hasLowercase),
              buildRequirement("يحتوي على رقم", hasNumber),
              buildRequirement("يحتوي على رمز خاص", hasSpecialChar),
              buildRequirement("بدون مسافات", hasNoSpaces),
              const SizedBox(height: 16),

              // تأكيد كلمة المرور
              TextFormField(
                controller: confirmPasswordController,
                style: const TextStyle(color: Colors.black),
                obscureText: obscureConfirmPassword,
                validator: (value) {
                  if (value != passwordController.text) {
                    return "كلمتا المرور غير متطابقتين";
                  }
                  return null;
                },
                decoration: blackInputDecoration("تأكيد كلمة المرور").copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword = !obscureConfirmPassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // زر التسجيل
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: isLoading
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            if (selectedBloodType == null ||
                                selectedCity == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "يرجى اختيار فصيلة الدم والمدينة")),
                              );
                              return;
                            }
                            if (hasDisease == true &&
                                diseaseController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("يرجى كتابة اسم المرض")),
                              );
                              return;
                            }
                            if (bloodTestDate == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text("يرجى اختيار تاريخ فحص الدم")),
                              );
                              return;
                            }
                            _registerUser();
                          }
                        },
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("تسجيل",
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildRequirement(String text, bool condition) {
    return Row(
      children: [
        Icon(
          condition ? Icons.check_circle : Icons.cancel,
          color: condition ? Colors.green : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: condition ? Colors.green : Colors.red,
            fontSize: 13,
          ),
        ),
      ],
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
