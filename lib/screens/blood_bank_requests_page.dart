import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'city_helper.dart';

class BloodBankRequestsPage extends StatefulWidget {
  const BloodBankRequestsPage({super.key});

  @override
  State<BloodBankRequestsPage> createState() => _BloodBankRequestsPageState();
}

class _BloodBankRequestsPageState extends State<BloodBankRequestsPage> {
  List<Map<String, dynamic>> requests = [];
  String staffCity = "";
  String staffHospital = "";
  String staffHospitalId = "";
  bool isLoading = true;
  String statusFilter = "all";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final staffSnap =
        await FirebaseDatabase.instance.ref("BloodBankStaff/$uid").get();
    if (staffSnap.exists && staffSnap.value is Map) {
      final data = Map<String, dynamic>.from(staffSnap.value as Map);
      staffCity = CityHelper.normalize(data['city']?.toString());

      final hospitalId = data['hospitalId']?.toString() ?? "";
      staffHospitalId = hospitalId;
      if (hospitalId.isNotEmpty) {
        final hospSnap =
            await FirebaseDatabase.instance.ref("Hospitals/$hospitalId").get();
        if (hospSnap.exists && hospSnap.value is Map) {
          final hospData = Map<String, dynamic>.from(hospSnap.value as Map);
          staffHospital = hospData['hospitalName']?.toString() ?? "";
        }
      }
    }

    FirebaseDatabase.instance.ref("Requests").onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) {
        setState(() {
          requests = [];
          isLoading = false;
        });
        return;
      }

      List<Map<String, dynamic>> temp = [];
      Map<String, dynamic>.from(data).forEach((key, value) {
        final req = Map<String, dynamic>.from(value);
        if (req['hospitalId']?.toString() == staffHospitalId) {
          req['_key'] = key;
          temp.add(req);
        }
      });

      temp.sort((a, b) {
        final aTime = a['createdAt'] ?? 0;
        final bTime = b['createdAt'] ?? 0;
        return (bTime as int).compareTo(aTime as int);
      });

      setState(() {
        requests = temp;
        isLoading = false;
      });
    });
  }

  bool _isOpen(String status) {
    return status == "عاجل" || status == "مفتوح" || status == "بانتظار";
  }

  Future<void> _createRequest() async {
    final formKey = GlobalKey<FormState>();
    String? selectedBlood;
    final unitsCtrl = TextEditingController();
    final deptCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [
          Icon(Icons.add_circle, color: Colors.red),
          SizedBox(width: 8),
          Text("إنشاء طلب دم جديد"),
        ]),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  validator: (v) => v == null ? "اختر فصيلة الدم" : null,
                  decoration: InputDecoration(
                    labelText: "فصيلة الدم",
                    prefixIcon: const Icon(Icons.bloodtype, color: Colors.red),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"]
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => selectedBlood = v,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: unitsCtrl,
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v == null || v.isEmpty ? "أدخل عدد الوحدات" : null,
                  decoration: InputDecoration(
                    labelText: "عدد الوحدات",
                    prefixIcon: const Icon(Icons.format_list_numbered,
                        color: Colors.red),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: deptCtrl,
                  validator: (v) =>
                      v == null || v.isEmpty ? "أدخل القسم" : null,
                  decoration: InputDecoration(
                    labelText: "القسم (طوارئ، جراحة...)",
                    prefixIcon:
                        const Icon(Icons.medical_services, color: Colors.red),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;

              final newRef = FirebaseDatabase.instance.ref("Requests").push();

              await newRef.set({
                'requestId': newRef.key,
                'hospitalId': staffHospitalId,
                'hospitalName': staffHospital,
                'city': staffCity,
                'bloodType': selectedBlood,
                'units': "${unitsCtrl.text.trim()} وحدات",
                'department': deptCtrl.text.trim(),
                'status': 'عاجل',          // ✅ عربي
                'role': 'request',
                'donatedCount': 0,
                'createdAt': ServerValue.timestamp,
                'createdByStaff': true,
              });

              // ── إشعار للمستشفى ──
              if (staffHospitalId.isNotEmpty) {
                final notifRef = FirebaseDatabase.instance
                    .ref("Notifications/$staffHospitalId")
                    .push();
                await notifRef.set({
                  'title': "طلب دم جديد 🩸",
                  'message':
                      "تم إنشاء طلب دم من بنك الدم — فصيلة $selectedBlood، قسم ${deptCtrl.text.trim()}",
                  'type': "new_request",
                  'requestId': newRef.key,
                  'isRead': false,
                  'createdAt': ServerValue.timestamp,
                });
              }

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ تم إنشاء الطلب بنجاح"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text("إنشاء", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _closeRequest(String key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("إغلاق الطلب"),
        content: const Text("هل أنت متأكد من إغلاق هذا الطلب؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("إغلاق", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseDatabase.instance
        .ref("Requests/$key")
        .update({'status': 'مغلق'}); // ✅ عربي

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("✅ تم إغلاق الطلب"), backgroundColor: Colors.green),
      );
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return "";
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts as int);
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return "";
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    if (statusFilter == "all") return requests;
    return requests.where((r) {
      final status = r['status']?.toString() ?? "";
      if (statusFilter == "open") {
        // مفتوح = عاجل أو مفتوح أو بانتظار
        return _isOpen(status);
      }
      // مغلق
      return status == "مغلق";
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "الطلبات",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("طلب جديد", style: TextStyle(color: Colors.white)),
        onPressed: _createRequest,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : Column(
              children: [
                // ── فلتر الحالة ──
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      _filterChip("all", "الكل", Colors.grey),
                      const SizedBox(width: 8),
                      _filterChip("open", "مفتوح", Colors.orange),
                      const SizedBox(width: 8),
                      _filterChip("مغلق", "مغلق", Colors.green),
                    ],
                  ),
                ),

                Expanded(
                  child: _filteredRequests.isEmpty
                      ? const Center(child: Text("لا يوجد طلبات"))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredRequests.length,
                          itemBuilder: (context, index) {
                            final req = _filteredRequests[index];
                            final key = req['_key']?.toString() ?? "";
                            final status = req['status']?.toString() ?? "";
                            final isOpen = _isOpen(status);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: BorderSide(
                                  color: isOpen
                                      ? Colors.orange.shade300
                                      : Colors.green.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "🏥 ${req['hospitalName'] ?? 'غير محدد'}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isOpen
                                                ? Colors.orange.shade100
                                                : Colors.green.shade100,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            isOpen ? "مفتوح 🔴" : "مغلق ✅",
                                            style: TextStyle(
                                              color: isOpen
                                                  ? Colors.orange
                                                  : Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                        "🩸 الفصيلة: ${req['bloodType'] ?? '-'}"),
                                    Text("🧪 الوحدات: ${req['units'] ?? '-'}"),
                                    Text(
                                        "🏢 القسم: ${req['department'] ?? '-'}"),
                                    if (req['createdAt'] != null)
                                      Text(
                                        "📅 ${_formatTimestamp(req['createdAt'])}",
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 13),
                                      ),
                                    if (isOpen) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: const Icon(Icons.check,
                                              color: Colors.white),
                                          label: const Text(
                                            "إغلاق الطلب",
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                          onPressed: () => _closeRequest(key),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _filterChip(String value, String label, Color color) {
    final isSelected = statusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => statusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? color : Colors.grey.shade300, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}