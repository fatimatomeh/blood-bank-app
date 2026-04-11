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
  bool isLoading = false;

  String bloodType = "";

  late DatabaseReference donorRef;

  static const Color _primary = Color(0xFFD32F2F);
  static const Color _border = Color(0xFF212121);
  static const Color _label = Color(0xFF212121);
  static const Color _text = Color(0xFF212121);

  final List<String> _cities = [
    "رام الله", "البيرة", "نابلس", "الخليل", "بيت لحم",
    "جنين", "طولكرم", "قلقيلية", "أريحا", "سلفيت", "طوباس"
  ];

  String? normalizeCity(String? city) {
    if (city == null) return null;
    final lower = city.toLowerCase();
    const map = {
      "ramallah": "رام الله", "al-bireh": "البيرة", "nablus": "نابلس",
      "hebron": "الخليل", "bethlehem": "بيت لحم", "jenin": "جنين",
      "tulkarm": "طولكرم", "qalqilya": "قلقيلية", "jericho": "أريحا",
      "salfit": "سلفيت", "tubas": "طوباس",
    };
    return map[lower] ?? city;
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
    donorRef = FirebaseDatabase.instance.ref().child("Donors").child(widget.donorId);
    _loadDonorData();
  }

  Future<void> _loadDonorData() async {
    final snapshot = await donorRef.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      setState(() {
        fullNameController.text = data["fullName"] ?? "";
        emailController.text = data["email"] ?? "";
        phoneController.text = data["phone"] ?? "";
        diseaseController.text = data["diseaseName"] ?? "";
        bloodLevelController.text = data["bloodLevel"]?.toString() ?? "";
        selectedCity = normalizeCity(data["city"]);
        hasDisease = data["hasDiseases"] == "Y";
        bloodType = data["bloodType"] ?? "غير محدد";

        if (data["lastDonation"] != null &&
            data["lastDonation"].toString().isNotEmpty) {
          try {
            final parts = data["lastDonation"].split("/");
            lastDonationDate = DateTime(
              int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]),
            );
          } catch (_) {}
        } else {
          neverDonated = true;
        }

        if (data["lastBloodTest"] != null &&
            data["lastBloodTest"].toString().isNotEmpty) {
          try {
            final parts = data["lastBloodTest"].split("/");
            bloodTestDate = DateTime(
              int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]),
            );
          } catch (_) {}
        }
      });
    }
  }

  InputDecoration _dec(String label, {Widget? prefixIcon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 15, color: _label),
      floatingLabelStyle: const TextStyle(
          fontSize: 14, color: _primary, fontWeight: FontWeight.w600),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 14, top: 6),
        child: Row(
          children: [
            Container(
              width: 5, height: 22,
              decoration: BoxDecoration(
                color: _primary, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 10),
            Text(text,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: _text)),
          ],
        ),
      );

  Widget _buildDateField({
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
          border: Border.all(color: _border, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: _primary, size: 22),
            const SizedBox(width: 12),
            Text(
              displayText,
              style: TextStyle(
                fontSize: 16,
                color: displayText.contains('/') ? _text : _label,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pickDate() async {
    if (neverDonated) return;
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: lastDonationDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => lastDonationDate = picked);
  }

  Future<void> pickBloodTestDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: bloodTestDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => bloodTestDate = picked);
  }

  void _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

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
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم حفظ التعديلات بنجاح ✅"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "تعديل الحساب",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
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
              // ── فصيلة الدم للعرض فقط ──
              TextFormField(
                initialValue: bloodType,
                enabled: false,
                style: const TextStyle(color: _text),
                decoration: _dec("فصيلة الدم (لا يمكن تغييرها)",
                    prefixIcon: const Icon(Icons.bloodtype, color: _primary, size: 22))
                    .copyWith(
                  fillColor: Colors.grey.shade100,
                  suffixIcon: const Icon(Icons.lock, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 26),

              // ── المعلومات الشخصية ──
              _sectionTitle("المعلومات الشخصية"),
              TextFormField(
                controller: fullNameController,
                style: const TextStyle(color: _text),
                textAlign: TextAlign.right,
                validator: (v) {
                  if (v == null || v.isEmpty) return "الاسم الكامل مطلوب";
                  if (v.length < 5) return "الاسم يجب أن يكون 5 أحرف على الأقل";
                  return null;
                },
                decoration: _dec("الاسم الكامل",
                    prefixIcon: const Icon(Icons.person_outline, color: _primary, size: 22)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                style: const TextStyle(color: _text),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return "البريد الإلكتروني مطلوب";
                  if (!v.contains('@')) return "بريد غير صالح";
                  return null;
                },
                decoration: _dec("البريد الإلكتروني",
                    prefixIcon: const Icon(Icons.email_outlined, color: _primary, size: 22)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                style: const TextStyle(color: _text),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return "رقم الهاتف مطلوب";
                  if (!RegExp(r'^05\d{8}$').hasMatch(v))
                    return "أدخل رقم صحيح (05XXXXXXXX)";
                  return null;
                },
                decoration: _dec("رقم الهاتف",
                    prefixIcon: const Icon(Icons.phone_outlined, color: _primary, size: 22)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _cities.contains(selectedCity) ? selectedCity : null,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _primary, size: 26),
                decoration: _dec("المدينة",
                    prefixIcon: const Icon(Icons.location_city_outlined, color: _primary, size: 22)),
                items: _cities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => selectedCity = v),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              const SizedBox(height: 26),

              // ── الحالة الصحية ──
              _sectionTitle("الحالة الصحية"),
              const Text("هل تعاني من أي أمراض مزمنة؟",
                  style: TextStyle(fontSize: 15, color: _label)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _border, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        value: true,
                        groupValue: hasDisease,
                        activeColor: _primary,
                        title: const Text("نعم", style: TextStyle(fontSize: 15)),
                        onChanged: (v) => setState(() => hasDisease = v),
                      ),
                    ),
                    Container(width: 1, height: 44, color: _border),
                    Expanded(
                      child: RadioListTile<bool>(
                        value: false,
                        groupValue: hasDisease,
                        activeColor: _primary,
                        title: const Text("لا", style: TextStyle(fontSize: 15)),
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
                  style: const TextStyle(color: _text),
                  textAlign: TextAlign.right,
                  decoration: _dec("اسم المرض",
                      prefixIcon: const Icon(Icons.medical_information_outlined,
                          color: _primary, size: 22)),
                ),
              ],
              const SizedBox(height: 26),

              // ── معلومات الفحص الطبي ──
              _sectionTitle("معلومات الفحص الطبي"),
              TextFormField(
                controller: bloodLevelController,
                style: const TextStyle(color: _text),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: _dec("نسبة الدم",
                    prefixIcon: const Icon(Icons.water_drop_outlined, color: _primary, size: 22),
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
              const Text("تاريخ آخر فحص دم",
                  style: TextStyle(fontSize: 15, color: _label)),
              const SizedBox(height: 8),
              _buildDateField(
                displayText: bloodTestDate != null
                    ? "${bloodTestDate!.day}/${bloodTestDate!.month}/${bloodTestDate!.year}"
                    : "اختر تاريخ الفحص",
                onTap: pickBloodTestDate,
                icon: Icons.science_outlined,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6, right: 4),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.blueGrey),
                    SizedBox(width: 4),
                    Text(
                      "تحديث تاريخ الفحص يوقف تذكير الفحص الدوري لمدة 4 أشهر",
                      style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              // ── سجل التبرع ──
              _sectionTitle("سجل التبرع"),
              _buildDateField(
                displayText: neverDonated
                    ? "لم أتبرع من قبل"
                    : lastDonationDate != null
                        ? "${lastDonationDate!.day}/${lastDonationDate!.month}/${lastDonationDate!.year}"
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
                          if (neverDonated) lastDonationDate = null;
                        });
                      },
                    ),
                  ),
                  const Text("لم أقم بالتبرع من قبل",
                      style: TextStyle(fontSize: 15, color: _text)),
                ],
              ),
              if (!neverDonated) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: donationsCountController,
                  style: const TextStyle(color: _text),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (!neverDonated) {
                      if (v == null || v.isEmpty)
                        return "يرجى إدخال عدد مرات التبرع";
                      if (!RegExp(r'^[0-9]+$').hasMatch(v))
                        return "أدخل رقم صحيح";
                    }
                    return null;
                  },
                  decoration: _dec("كم مرة تبرعت من قبل؟",
                      prefixIcon: const Icon(Icons.format_list_numbered,
                          color: _primary, size: 22)),
                ),
              ],
              const SizedBox(height: 40),

              // ── زر الحفظ ──
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    elevation: 3,
                    shadowColor: _primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: isLoading ? null : _saveChanges,
                  child: isLoading
                      ? const SizedBox(
                          width: 26, height: 26,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          "حفظ التغييرات",
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
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