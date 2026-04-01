import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'city_helper.dart';

class HospitalEditProfilePage extends StatefulWidget {
  const HospitalEditProfilePage({super.key});

  @override
  State<HospitalEditProfilePage> createState() =>
      _HospitalEditProfilePageState();
}

class _HospitalEditProfilePageState extends State<HospitalEditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  String? selectedCity;
  bool isLoading = false;

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
      final data = Map<String, dynamic>.from(snap.value as Map);

      nameController.text = data['name'] ?? "";
      emailController.text = data['email'] ?? "";
      phoneController.text = data['phone'] ?? "";

      final city = CityHelper.normalize(data['city']?.toString());

      setState(() {
        selectedCity = CityHelper.arabicCities.contains(city) ? city : null;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseDatabase.instance.ref("Hospitals/${user.uid}").update({
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم التحديث بنجاح ✅")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("حدث خطأ: $e")),
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
        title: const Text(
          "إعدادات الحساب",
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
              // 🏥 أيقونة
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade100, width: 2),
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    color: Colors.red,
                    size: 45,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                "معلومات الحساب",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              // 🏥 اسم المستشفى (مقفول)
              TextFormField(
                controller: nameController,
                enabled: false,
                decoration: InputDecoration(
                  labelText: "اسم المستشفى",
                  prefixIcon:
                      const Icon(Icons.local_hospital, color: Colors.red),
                  suffixIcon: const Icon(Icons.lock, color: Colors.grey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 16),

              // 📍 المدينة (مقفولة)
              DropdownButtonFormField<String>(
                value: selectedCity,
                items: CityHelper.arabicCities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: null,
                decoration: InputDecoration(
                  labelText: "المدينة",
                  prefixIcon:
                      const Icon(Icons.location_city, color: Colors.red),
                  suffixIcon: const Icon(Icons.lock, color: Colors.grey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 16),

              // 📧 الإيميل
              TextFormField(
                controller: emailController,
                validator: (v) {
                  if (v == null || v.isEmpty) return "أدخل البريد الإلكتروني";
                  if (!v.contains('@')) return "إيميل غير صالح";
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "البريد الإلكتروني",
                  prefixIcon: const Icon(Icons.email, color: Colors.red),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 16),

              // 📱 رقم الهاتف
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty) return "أدخل رقم الهاتف";
                  if (v.length != 10) return "يجب أن يكون 10 أرقام";
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "رقم الهاتف",
                  prefixIcon: const Icon(Icons.phone, color: Colors.red),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 40),

              // 💾 زر الحفظ
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLoading ? null : _saveChanges,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "حفظ التغييرات",
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

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}
