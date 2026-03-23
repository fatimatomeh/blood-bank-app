import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController fullNameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController diseaseController;

  String? selectedCity;
  bool? hasDisease;
  DateTime? lastDonationDate;
  bool neverDonated = false;

  final String bloodType = "O+";

  @override
  void initState() {
    super.initState();
    fullNameController = TextEditingController(text: "فاطمة محمد");
    emailController = TextEditingController(text: "fatima@gmail.com");
    phoneController = TextEditingController(text: "0591234567");
    diseaseController = TextEditingController();
    selectedCity = "نابلس";
    hasDisease = false;
    lastDonationDate = DateTime(2026, 1, 2);
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
          data: Theme.of(
            context,
          ).copyWith(colorScheme: const ColorScheme.light(primary: Colors.red)),
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
              const Text(
                "المعلومات الشخصية",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),

              buildTextField(fullNameController, "الاسم الكامل", Icons.person),
              const SizedBox(height: 16),
              buildTextField(
                emailController,
                "البريد الإلكتروني",
                Icons.email,
                isEmail: true,
              ),
              const SizedBox(height: 16),
              buildTextField(
                phoneController,
                "رقم الهاتف",
                Icons.phone,
                isPhone: true,
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
              const Text(
                "الحالة الصحية",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
                  diseaseController,
                  "يرجى ذكر المرض",
                  Icons.healing,
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 25),
              const Text(
                "سجل التبرع",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
                        const SnackBar(content: Text("تم حفظ التعديلات بنجاح")),
                      );
                      Navigator.of(context).pop();
                    }
                  },
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
    super.dispose();
  }
}
