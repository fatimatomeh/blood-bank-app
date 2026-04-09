import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

class EditProfilePage extends StatefulWidget {
  final String donorId;

  const EditProfilePage({Key? key, required this.donorId}) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController fullNameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController diseaseController;
  late TextEditingController donationsCountController;
  late TextEditingController bloodLevelController;

  String? selectedCity;
  bool? hasDisease;
  DateTime? lastDonationDate;
  DateTime? bloodTestDate;
  bool neverDonated = false;

  String bloodType = "";

  late DatabaseReference donorRef;

  Map<String, String> cityMap = {
    "ramallah": "رام الله",
    "al-bireh": "البيرة",
    "nablus": "نابلس",
    "hebron": "الخليل",
    "bethlehem": "بيت لحم",
    "jenin": "جنين",
    "tulkarm": "طولكرم",
    "qalqilya": "قلقيلية",
    "jericho": "أريحا",
    "salfit": "سلفيت",
    "tubas": "طوباس",
  };

  String? normalizeCity(String? city) {
    if (city == null) return null;
    String lower = city.toLowerCase();
    return cityMap[lower] ?? city;
  }

  @override
  void initState() {
    super.initState();
    fullNameController = TextEditingController();
    emailController = TextEditingController();
    phoneController = TextEditingController();
    diseaseController = TextEditingController();
    donationsCountController = TextEditingController();
    bloodLevelController = TextEditingController();

    donorRef =
        FirebaseDatabase.instance.ref().child("Donors").child(widget.donorId);

    _loadDonorData();
  }

  Future<void> _loadDonorData() async {
    final snapshot = await donorRef.get();
    if (snapshot.exists) {
      final donorData = snapshot.value as Map;

      setState(() {
        fullNameController.text = donorData["fullName"] ?? "";
        emailController.text = donorData["email"] ?? "";
        phoneController.text = donorData["phone"] ?? "";
        diseaseController.text = donorData["diseaseName"] ?? "";
        bloodLevelController.text = donorData["bloodLevel"]?.toString() ?? "";
        selectedCity = normalizeCity(donorData["city"]);
        hasDisease = donorData["hasDiseases"] == "Y";
        bloodType = donorData["bloodType"] ?? "غير محدد";

        // ✅ تحميل تاريخ آخر تبرع
        if (donorData["lastDonation"] != null &&
            donorData["lastDonation"].toString().isNotEmpty) {
          try {
            final parts = donorData["lastDonation"].split("/");
            lastDonationDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          } catch (_) {}
        } else {
          neverDonated = true;
        }

        // ✅ تحميل تاريخ آخر فحص دم
        if (donorData["lastBloodTest"] != null &&
            donorData["lastBloodTest"].toString().isNotEmpty) {
          try {
            final parts = donorData["lastBloodTest"].split("/");
            bloodTestDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          } catch (_) {}
        }
      });
    }
  }

  Future<void> pickDate() async {
    if (neverDonated) return;

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: lastDonationDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.red),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        lastDonationDate = picked;
      });
    }
  }

  Future<void> pickBloodTestDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: bloodTestDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.red),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        bloodTestDate = picked;
      });
    }
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      await donorRef.update({
        "fullName": fullNameController.text,
        "email": emailController.text,
        "phone": phoneController.text,
        "city": selectedCity,
        "hasDiseases": hasDisease == true ? "Y" : "N",
        "diseaseName": diseaseController.text,
        "bloodLevel": bloodLevelController.text.trim(),
        "lastDonation": neverDonated
            ? ""
            : (lastDonationDate != null
                ? "${lastDonationDate!.day}/${lastDonationDate!.month}/${lastDonationDate!.year}"
                : ""),
        "donationCount": neverDonated
            ? 0
            : int.tryParse(donationsCountController.text.trim()) ?? 0,
        "lastBloodTest": bloodTestDate != null
            ? "${bloodTestDate!.day}/${bloodTestDate!.month}/${bloodTestDate!.year}"
            : "",
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم حفظ التعديلات بنجاح")),
        );
        Navigator.of(context).pop();
      }
    }
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
          "تعديل الحساب",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── فصيلة الدم (للعرض فقط) ──
              TextFormField(
                initialValue: bloodType,
                enabled: false,
                decoration: InputDecoration(
                  labelText: "فصيلة الدم (لا يمكن تغييرها)",
                  prefixIcon: const Icon(Icons.bloodtype, color: Colors.red),
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── المعلومات الشخصية ──
              const Text("المعلومات الشخصية",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              buildTextField(fullNameController, "الاسم الكامل", Icons.person),
              const SizedBox(height: 16),
              buildTextField(emailController, "البريد الإلكتروني", Icons.email,
                  isEmail: true),
              const SizedBox(height: 16),
              buildTextField(phoneController, "رقم الهاتف", Icons.phone,
                  isPhone: true),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: normalizeCity(selectedCity),
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
                onChanged: (value) => setState(() => selectedCity = value),
                decoration: InputDecoration(
                  labelText: "المدينة",
                  prefixIcon: const Icon(Icons.location_city),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // ── الحالة الصحية ──
              const Text("الحالة الصحية",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Text("هل تعاني من أي أمراض مزمنة؟"),
              Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: hasDisease,
                    onChanged: (v) => setState(() => hasDisease = v),
                  ),
                  const Text("نعم"),
                  const SizedBox(width: 20),
                  Radio<bool>(
                    value: false,
                    groupValue: hasDisease,
                    onChanged: (v) => setState(() => hasDisease = v),
                  ),
                  const Text("لا"),
                ],
              ),
              if (hasDisease == true) ...[
                buildTextField(
                    diseaseController, "يرجى ذكر المرض", Icons.healing),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 25),

              // ── معلومات الفحص الطبي ──
              const Text("معلومات الفحص الطبي",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              // نسبة الدم
              TextFormField(
                controller: bloodLevelController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: "نسبة الدم",
                  hintText: "مثال: 13.5",
                  prefixIcon: const Icon(Icons.water_drop, color: Colors.red),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
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
              const SizedBox(height: 16),

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
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
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
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "💡 تحديث تاريخ الفحص يوقف تذكير الفحص الدوري لمدة 4 أشهر",
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              const SizedBox(height: 25),

              // ── سجل التبرع ──
              const Text("سجل التبرع",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: pickDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: neverDonated ? Colors.grey[100] : Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: neverDonated ? Colors.grey : Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        neverDonated
                            ? "لم يسبق لي التبرع"
                            : (lastDonationDate != null
                                ? "${lastDonationDate!.day} / ${lastDonationDate!.month} / ${lastDonationDate!.year}"
                                : "اختر التاريخ"),
                        style: TextStyle(
                          fontSize: 16,
                          color: neverDonated ? Colors.grey : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Checkbox(
                    value: neverDonated,
                    activeColor: Colors.red,
                    onChanged: (bool? value) {
                      setState(() {
                        neverDonated = value ?? false;
                        if (neverDonated) lastDonationDate = null;
                      });
                    },
                  ),
                  const Text("لم أقم بالتبرع من قبل"),
                ],
              ),
              if (!neverDonated) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: donationsCountController,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (!neverDonated) {
                      if (value == null || value.isEmpty) {
                        return "يرجى إدخال عدد مرات التبرع";
                      }
                      if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                        return "أدخل رقم صحيح";
                      }
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: "كم مرة تبرعت من قبل؟",
                    prefixIcon: const Icon(Icons.format_list_numbered),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),

              // ── زر الحفظ ──
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
                  onPressed: _saveChanges,
                  child: const Text(
                    "حفظ التغييرات",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isEmail = false,
    bool isPhone = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isEmail
          ? TextInputType.emailAddress
          : (isPhone ? TextInputType.phone : TextInputType.text),
      validator: (value) {
        if (value == null || value.isEmpty) return "هذا الحقل مطلوب";
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
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
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    diseaseController.dispose();
    donationsCountController.dispose();
    bloodLevelController.dispose();
    super.dispose();
  }
}
