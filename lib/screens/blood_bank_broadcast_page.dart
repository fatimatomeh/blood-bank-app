// =====================================================================
// blood_bank_broadcast_page.dart — صفحة جديدة
// إرسال إشعار عاجل لجميع متبرعي المدينة أو فصيلة معينة
// =====================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'city_helper.dart';

class BloodBankBroadcastPage extends StatefulWidget {
  const BloodBankBroadcastPage({super.key});

  @override
  State<BloodBankBroadcastPage> createState() => _BloodBankBroadcastPageState();
}

class _BloodBankBroadcastPageState extends State<BloodBankBroadcastPage> {
  String staffCity = "";
  String staffHospitalId = "";
  String staffHospitalName = "";
  bool isLoading = true;
  bool isSending = false;

  String? selectedBloodType; // null = الكل
  final TextEditingController _messageController = TextEditingController();
  String _urgencyLevel = "urgent"; // urgent | normal
  int _estimatedRecipients = 0;

  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadStaffData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final staffSnap =
        await FirebaseDatabase.instance.ref("BloodBankStaff/$uid").get();
    if (staffSnap.exists && staffSnap.value is Map) {
      final data = Map<String, dynamic>.from(staffSnap.value as Map);
      staffCity = CityHelper.normalize(data['city']?.toString());
      staffHospitalId = data['hospitalId']?.toString() ?? "";

      if (staffHospitalId.isNotEmpty) {
        final hospSnap = await FirebaseDatabase.instance
            .ref("Hospitals/$staffHospitalId")
            .get();
        if (hospSnap.exists && hospSnap.value is Map) {
          final hospData = Map<String, dynamic>.from(hospSnap.value as Map);
          staffHospitalName = hospData['hospitalName']?.toString() ?? "";
        }
      }
    }

    await _countRecipients();
    setState(() => isLoading = false);
  }

  Future<void> _countRecipients() async {
    final donorsSnap = await FirebaseDatabase.instance.ref("Donors").get();
    if (!donorsSnap.exists || donorsSnap.value is! Map) return;

    int count = 0;
    Map<String, dynamic>.from(donorsSnap.value as Map).forEach((key, value) {
      final donor = Map<String, dynamic>.from(value);
      final city = CityHelper.normalize(donor['city']?.toString());
      final blood = donor['bloodType']?.toString() ?? "";

      if (city != staffCity) return;
      if (selectedBloodType != null && blood != selectedBloodType) return;
      count++;
    });

    setState(() => _estimatedRecipients = count);
  }

  Future<void> _sendBroadcast() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("يرجى كتابة رسالة الإشعار"),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.broadcast_on_personal, color: Colors.red),
          SizedBox(width: 8),
          Text("تأكيد الإرسال"),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("سيصل هذا الإشعار لـ $_estimatedRecipients متبرع في $staffCity"
                "${selectedBloodType != null ? ' (فصيلة $selectedBloodType فقط)' : ''}."),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _messageController.text.trim(),
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text("إرسال الآن", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isSending = true);

    try {
      final donorsSnap = await FirebaseDatabase.instance.ref("Donors").get();
      if (!donorsSnap.exists || donorsSnap.value is! Map) return;

      final now = DateTime.now();
      final dateStr = "${now.day}/${now.month}/${now.year}";
      final message = _messageController.text.trim();
      int sentCount = 0;

      final updates = <String, dynamic>{};

      Map<String, dynamic>.from(donorsSnap.value as Map).forEach((key, value) {
        final donor = Map<String, dynamic>.from(value);
        final city = CityHelper.normalize(donor['city']?.toString());
        final blood = donor['bloodType']?.toString() ?? "";

        if (city != staffCity) return;
        if (selectedBloodType != null && blood != selectedBloodType) return;

        updates["Donors/$key/notification"] = {
          'message':
              _urgencyLevel == "urgent" ? "🚨 [عاجل] $message" : "📢 $message",
          'isRead': false,
          'createdAt': dateStr,
          'type': _urgencyLevel == "urgent" ? "urgent" : "info",
          'from': staffHospitalName,
        };
        sentCount++;
      });

      if (updates.isNotEmpty) {
        await FirebaseDatabase.instance.ref().update(updates);
      }

      // تسجيل الإشعار في سجل المستشفى
      await FirebaseDatabase.instance
          .ref("Hospitals/$staffHospitalId/broadcastHistory")
          .push()
          .set({
        'message': message,
        'sentAt': dateStr,
        'recipientsCount': sentCount,
        'bloodType': selectedBloodType ?? 'الكل',
        'urgency': _urgencyLevel,
        'city': staffCity,
      });

      if (mounted) {
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ تم إرسال الإشعار لـ $sentCount متبرع"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        title: const Text("إشعار عاجل للمتبرعين",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── بطاقة معلومات ───────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.broadcast_on_personal,
                                color: Colors.white, size: 24),
                            SizedBox(width: 8),
                            Text("إرسال إشعار جماعي",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "المدينة: $staffCity — المستشفى: $staffHospitalName",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── اختيار الفصيلة ──────────────────────────────
                  const Text("فصيلة الدم المستهدفة",
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _bloodChip("الكل 🩸", null),
                      ...["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"]
                          .map((b) => _bloodChip(b, b))
                          .toList(),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── مستوى الأولوية ──────────────────────────────
                  const Text("مستوى الأولوية",
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _urgencyChip("urgent", "عاجل 🚨", Colors.red),
                      const SizedBox(width: 10),
                      _urgencyChip("normal", "عادي 📢", Colors.blue),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── الرسالة ──────────────────────────────────────
                  const Text("نص الرسالة",
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _messageController,
                    maxLines: 4,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText:
                          "مثال: نحتاج متبرعين عاجلاً لفصيلة O+ في قسم الطوارئ...",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            const BorderSide(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── عدد المستقبلين ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          "سيصل الإشعار لـ $_estimatedRecipients متبرع",
                          style: const TextStyle(
                              color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── زر الإرسال ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send, color: Colors.white),
                      label: Text(
                        isSending ? "جاري الإرسال..." : "إرسال الإشعار",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold),
                      ),
                      onPressed: isSending ? null : _sendBroadcast,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _bloodChip(String label, String? value) {
    final isSelected = selectedBloodType == value;
    return GestureDetector(
      onTap: () async {
        setState(() => selectedBloodType = value);
        await _countRecipients();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: isSelected ? Colors.red : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.red : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _urgencyChip(String value, String label, Color color) {
    final isSelected = _urgencyLevel == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _urgencyLevel = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
                width: isSelected ? 2 : 1),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: isSelected ? color : Colors.grey,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15)),
          ),
        ),
      ),
    );
  }
}
