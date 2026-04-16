import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'city_helper.dart';

class HospitalCreateRequestPage extends StatefulWidget {
  final Map<String, dynamic> hospitalData;

  const HospitalCreateRequestPage({super.key, required this.hospitalData});

  @override
  State<HospitalCreateRequestPage> createState() =>
      _HospitalCreateRequestPageState();
}

class _HospitalCreateRequestPageState extends State<HospitalCreateRequestPage> {
  final _formKey = GlobalKey<FormState>();

  String? selectedBloodType;
  final TextEditingController unitsController = TextEditingController();
  final TextEditingController deptController = TextEditingController();

  bool isLoading = false;

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final hospitalName =
          widget.hospitalData['hospitalName']?.toString().trim() ?? "";

      final cityAr =
          CityHelper.normalize(widget.hospitalData['city']?.toString());

      final newRef = FirebaseDatabase.instance.ref("Requests").push();

      await newRef.set({
        'requestId': newRef.key,
        'hospitalId': user.uid,
        'hospitalName': hospitalName,
        'city': cityAr,
        'bloodType': selectedBloodType,
        'role': 'request',
        'units': "${unitsController.text.trim()} وحدات",
        'department': deptController.text.trim(),
        'status': 'عاجل',
        'donatedCount': 0,
        'createdAt': ServerValue.timestamp,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم إنشاء الطلب بنجاح ✅")),
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
    final cityDisplay =
        CityHelper.normalize(widget.hospitalData['city']?.toString());

    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        title: const Text(
          "إنشاء طلب جديد",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_hospital, color: Colors.red),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.hospitalData['hospitalName'] ?? "",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          "📍 $cityDisplay",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                "تفاصيل الطلب",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: selectedBloodType,
                validator: (v) => v == null ? "يرجى اختيار فصيلة الدم" : null,
                decoration: InputDecoration(
                  labelText: "فصيلة الدم المطلوبة",
                  prefixIcon: const Icon(Icons.bloodtype, color: Colors.red),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"]
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => selectedBloodType = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: unitsController,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return "يرجى إدخال عدد الوحدات";
                  final n = int.tryParse(v);
                  if (n == null || n < 1) return "أدخل رقم صحيح أكبر من صفر";
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "عدد الوحدات المطلوبة",
                  prefixIcon:
                      const Icon(Icons.format_list_numbered, color: Colors.red),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: deptController,
                validator: (v) =>
                    v == null || v.isEmpty ? "يرجى إدخال القسم" : null,
                decoration: InputDecoration(
                  labelText: "القسم (مثال: طوارئ، جراحة، أطفال)",
                  prefixIcon:
                      const Icon(Icons.medical_services, color: Colors.red),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLoading ? null : _submitRequest,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "إنشاء الطلب",
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
    unitsController.dispose();
    deptController.dispose();
    super.dispose();
  }
}