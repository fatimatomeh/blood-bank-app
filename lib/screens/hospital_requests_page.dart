import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'hospital_create_request_page.dart';
import 'city_helper.dart';

class HospitalRequestsPage extends StatefulWidget {
  const HospitalRequestsPage({super.key});

  @override
  State<HospitalRequestsPage> createState() => _HospitalRequestsPageState();
}

class _HospitalRequestsPageState extends State<HospitalRequestsPage> {
  List<Map<String, dynamic>> requests = [];
  Map<String, dynamic> hospitalData = {};
  String hospitalName = "";
  String hospitalUid = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    hospitalUid = user.uid;
    final hospSnap =
        await FirebaseDatabase.instance.ref("Hospitals/${user.uid}").get();
    if (hospSnap.exists && hospSnap.value is Map) {
      hospitalData = Map<String, dynamic>.from(hospSnap.value as Map);
      hospitalName = hospitalData['hospitalName']?.toString().trim() ?? "";
    }

    FirebaseDatabase.instance.ref("Requests").onValue.listen((event) {
      final data = event.snapshot.value;
      List<Map<String, dynamic>> temp = [];

      if (data != null && data is Map) {
        data.forEach((key, value) {
          final req = Map<String, dynamic>.from(value);
          final byId = req['hospitalId']?.toString() == hospitalUid;
          if (byId) {
            req['_key'] = key;
            temp.add(req);
          }
        });
      }

      temp.sort((a, b) {
        final order = {'عاجل': 0, 'open': 1, 'closed': 2, 'cancelled': 3};
        final aOrder = order[a['status']] ?? 4;
        final bOrder = order[b['status']] ?? 4;
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        final aTime = a['createdAt'] ?? 0;
        final bTime = b['createdAt'] ?? 0;
        return (bTime as int).compareTo(aTime as int);
      });

      if (mounted) {
        setState(() {
          requests = temp;
          isLoading = false;
        });
      }
    });
  }

  void _goToCreateRequest() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HospitalCreateRequestPage(hospitalData: hospitalData),
      ),
    );
    if (result == true) _loadData();
  }

  void _showEditDialog(Map<String, dynamic> req) {
    final rawUnits = req['units']?.toString() ?? "";
    final unitsNum = RegExp(r'\d+').firstMatch(rawUnits)?.group(0) ?? "";

    final unitsController = TextEditingController(text: unitsNum);
    final deptController = TextEditingController(text: req['department'] ?? "");
    final bloodNotifier = ValueNotifier<String?>(req['bloodType']);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تعديل الطلب",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<String?>(
                  valueListenable: bloodNotifier,
                  builder: (_, val, __) => DropdownButtonFormField<String>(
                    value: val,
                    validator: (v) => v == null ? "اختر فصيلة الدم" : null,
                    decoration: InputDecoration(
                      labelText: "فصيلة الدم",
                      prefixIcon:
                          const Icon(Icons.bloodtype, color: Colors.red),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"]
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => bloodNotifier.value = v,
                  ),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: unitsController,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return "أدخل عدد الوحدات";
                    if (int.tryParse(v) == null || int.parse(v) < 1) {
                      return "أدخل رقم صحيح";
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: "عدد الوحدات",
                    prefixIcon: const Icon(Icons.format_list_numbered,
                        color: Colors.red),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: deptController,
                  validator: (v) =>
                      v == null || v.isEmpty ? "أدخل القسم" : null,
                  decoration: InputDecoration(
                    labelText: "القسم",
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
              await FirebaseDatabase.instance
                  .ref("Requests/${req['_key']}")
                  .update({
                'bloodType': bloodNotifier.value,
             
                'units': "${unitsController.text.trim()} وحدات",
                'department': deptController.text.trim(),
              });
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("تم تعديل الطلب ✅")),
                );
              }
            },
            child: const Text("حفظ", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteRequest(String key) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("حذف الطلب"),
        content: const Text("هل أنت متأكد من حذف هذا الطلب؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseDatabase.instance.ref("Requests/$key").remove();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("تم حذف الطلب")),
                );
              }
            },
            child: const Text("حذف", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _changeStatus(String key, String currentStatus) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تغيير حالة الطلب",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusOption(key, 'عاجل', 'عاجل', Icons.warning_amber,
                Colors.orange, currentStatus),
            _statusOption(key, 'open', 'مفتوح', Icons.radio_button_on,
                Colors.green, currentStatus),
            _statusOption(key, 'closed', 'مغلق', Icons.check_circle,
                Colors.blue, currentStatus),
            _statusOption(key, 'cancelled', 'ملغي', Icons.cancel, Colors.red,
                currentStatus),
          ],
        ),
      ),
    );
  }

  Widget _statusOption(String key, String status, String label, IconData icon,
      Color color, String current) {
    final isSelected = current == status;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing:
          isSelected ? const Icon(Icons.check, color: Colors.green) : null,
      tileColor: isSelected ? color.withOpacity(0.08) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () async {
        await FirebaseDatabase.instance
            .ref("Requests/$key")
            .update({'status': status});
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("تم تغيير الحالة إلى $label")),
          );
        }
      },
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'عاجل':
        return Colors.orange;
      case 'open':
        return Colors.green;
      case 'closed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'عاجل':
        return 'عاجل';
      case 'open':
        return 'مفتوح';
      case 'closed':
        return 'مغلق';
      case 'cancelled':
        return 'ملغي';
      default:
        return status ?? 'غير محدد';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        title: const Text("الطلبات",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        onPressed: _goToCreateRequest,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("طلب جديد", style: TextStyle(color: Colors.white)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 70, color: Colors.grey[400]),
                      const SizedBox(height: 15),
                      const Text("لا يوجد طلبات بعد",
                          style:
                              TextStyle(fontSize: 16, color: Colors.black54)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    final status = req['status']?.toString() ?? "";
                    final isDone = status == 'closed' || status == 'cancelled';
                    final unitsDisplay = req['units']?.toString() ?? "0";

                    
                    final donatedCount =
                        int.tryParse(req['donatedCount']?.toString() ?? "0") ??
                            0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.bloodtype,
                                        color: Colors.red),
                                    const SizedBox(width: 8),
                                    Text(
                                      req['bloodType'] ?? "غير محدد",
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color:
                                        _statusColor(status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border:
                                        Border.all(color: _statusColor(status)),
                                  ),
                                  child: Text(
                                    _statusLabel(status),
                                    style: TextStyle(
                                        color: _statusColor(status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text("🧪 عدد الوحدات: $unitsDisplay"),
                            Text(
                                "🏥 القسم: ${req['department'] ?? 'غير محدد'}"),
                            Text("📍 المدينة: ${req['city'] ?? 'غير محدد'}"),

                            const SizedBox(height: 10),

                            
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: donatedCount > 0
                                    ? Colors.green.shade50
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: donatedCount > 0
                                      ? Colors.green.shade300
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    donatedCount > 0
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: donatedCount > 0
                                        ? Colors.green
                                        : Colors.grey,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    donatedCount > 0
                                        ? "تم التبرع $donatedCount مرة ✅"
                                        : "لم يتبرع أحد بعد",
                                    style: TextStyle(
                                      color: donatedCount > 0
                                          ? Colors.green.shade700
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon:
                                        const Icon(Icons.swap_horiz, size: 16),
                                    label: const Text("الحالة"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side:
                                          const BorderSide(color: Colors.blue),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    onPressed: () =>
                                        _changeStatus(req['_key'], status),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!isDone) ...[
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text("تعديل"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.orange,
                                        side: const BorderSide(
                                            color: Colors.orange),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => _showEditDialog(req),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.delete, size: 16),
                                    label: const Text("حذف"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    onPressed: () =>
                                        _deleteRequest(req['_key']),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
