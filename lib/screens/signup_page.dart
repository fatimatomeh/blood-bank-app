import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  TextEditingController fullNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController diseaseController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  String? selectedBloodType;
  String? selectedCity;
  bool? hasDisease;

  DateTime? selectedDate;
  bool neverDonated = false;

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  bool hasMinLength = false;
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecialChar = false;
  bool hasNoSpaces = true;

  void checkPassword(String value) {
    setState(() {
      hasMinLength = value.length >= 8;
      hasUppercase = value.contains(RegExp(r'[A-Z]'));
      hasLowercase = value.contains(RegExp(r'[a-z]'));
      hasNumber = value.contains(RegExp(r'[0-9]'));
      hasSpecialChar = value.contains(RegExp(r'[!@#\$&*~%^()_\-+=<>?/]'));
      hasNoSpaces = !value.contains(" ");
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "VivaLink",
          style: GoogleFonts.atma(
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
              Center(child: Image.asset("assets/welcomepage.png", height: 140)),

              /// الاسم الكامل
              TextFormField(
                controller: fullNameController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "الاسم الكامل مطلوب";
                  }

                  if (value.length < 5) {
                    return "الاسم يجب أن يكون 5 أحرف على الأقل";
                  }

                  if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(value)) {
                    return "يجب أن يحتوي الاسم على حروف إنجليزية فقط";
                  }

                  return null;
                },
                decoration: const InputDecoration(
                  labelText: "الاسم الكامل",
                  hintText: "أدخل اسمك الكامل",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

            
              TextFormField(
                controller: emailController,
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

                decoration: const InputDecoration(
                  labelText: "البريد الإلكتروني",
                  hintText: "أدخل بريدك الإلكتروني",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

     
              TextFormField(
                controller: phoneController,
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

                decoration: const InputDecoration(
                  labelText: "رقم الهاتف",
                  hintText: "أدخل رقم هاتفك",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

           
              DropdownButtonFormField<String>(
                value: selectedBloodType,

                items: ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"]
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),

                onChanged: (value) {
                  setState(() {
                    selectedBloodType = value;
                  });
                },

                decoration: const InputDecoration(
                  labelText: "فصيلة الدم",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

            
              DropdownButtonFormField<String>(
                value: selectedCity,

                items:
                    [
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
                          "طوباس",
                        ]
                        .map(
                          (city) =>
                              DropdownMenuItem(value: city, child: Text(city)),
                        )
                        .toList(),

                onChanged: (value) {
                  setState(() {
                    selectedCity = value;
                  });
                },

                decoration: const InputDecoration(
                  labelText: "المدينة",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

          
              const Text("هل تعاني من أي أمراض؟"),

              const SizedBox(height: 6),

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

              if (hasDisease == true) ...[
                const SizedBox(height: 8),

                TextField(
                  controller: diseaseController,

                  decoration: const InputDecoration(
                    labelText: "الأمراض",
                    hintText: "اكتب الأمراض التي تعاني منها",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 16),

            
              const Text("تاريخ آخر تبرع"),

              const SizedBox(height: 6),

              GestureDetector(
                onTap: pickDate,

                child: Container(
                  width: double.infinity,

                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 12,
                  ),

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

                    style: const TextStyle(fontSize: 16),
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

                        if (neverDonated) {
                          selectedDate = null;
                        }
                      });
                    },
                  ),

                  const Text("لم أقم بالتبرع من قبل"),
                ],
              ),

              const SizedBox(height: 20),

              
              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                onChanged: checkPassword,

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

                decoration: InputDecoration(
                  labelText: "كلمة المرور",
                  hintText: "أدخل كلمة المرور",
                  border: const OutlineInputBorder(),

                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
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

              
              TextFormField(
                controller: confirmPasswordController,
                obscureText: obscureConfirmPassword,

                validator: (value) {
                  if (value != passwordController.text) {
                    return "كلمتا المرور غير متطابقتين";
                  }

                  return null;
                },

                decoration: InputDecoration(
                  labelText: "تأكيد كلمة المرور",
                  hintText: "أعد إدخال كلمة المرور",
                  border: const OutlineInputBorder(),

                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
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

            
              SizedBox(
                width: double.infinity,
                height: 50,

                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),

                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("تم التسجيل بنجاح ✅")),
                      );
                    }
                  },

                  child: const Text("تسجيل", style: TextStyle(fontSize: 16)),
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

    super.dispose();
  }
}
