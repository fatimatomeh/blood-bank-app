import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// صفحة مخزون الدم الفائض للمستشفيات
/// الإصلاحات:
/// 1. تاب المستشفيات: قائمة مستشفيات أولاً، ولما تضغط تنزل فصائلها
/// 2. الموافقة: fromHospitalId هي الي عندها الدم وتوافق/ترفض
/// 3. المخزون الفائض: كل فصيلة لها حد احتياطي، وبس الزيادة تظهر للثانيين
class BloodInventoryPage extends StatefulWidget {
  const BloodInventoryPage({super.key});

  @override
  State<BloodInventoryPage> createState() => _BloodInventoryPageState();
}

class _BloodInventoryPageState extends State<BloodInventoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _hospitalId = "";
  String _hospitalName = "";
  String _hospitalCity = "";
  bool _isLoading = true;

  // ── مخزون هذا المستشفى ──
  Map<String, int> _myInventory = {};

  // ── الحدود الاحتياطية لكل فصيلة (يحتفظ بها لنفسه) ──
  Map<String, int> _reserveThresholds = {};

  // ── طلبات التبادل المُرسَلة والواردة ──
  // الصادرة: طلبات أرسلناها لمستشفيات أخرى (نحن الطالبون)
  // الواردة: طلبات مستشفيات أخرى تطلب منا (نحن المصدر، نوافق أو نرفض)
  List<Map<String, dynamic>> _outgoingRequests = [];
  List<Map<String, dynamic>> _incomingRequests = [];

  // ── مستشفيات أخرى لها فائض ──
  // Map<hospitalId, {hospitalName, city, inventory: Map<bloodType, units>}>
  Map<String, Map<String, dynamic>> _otherHospitals = {};

  // ── المستشفى المفتوح في تاب المستشفيات ──
  String? _expandedHospitalId;

  static const List<String> _bloodTypes = [
    "A+",
    "A-",
    "B+",
    "B-",
    "O+",
    "O-",
    "AB+",
    "AB-"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _hospitalId = uid;

    // ── بيانات المستشفى ──
    final hospSnap =
        await FirebaseDatabase.instance.ref("Hospitals/$uid").get();
    if (hospSnap.exists && hospSnap.value is Map) {
      final d = Map<String, dynamic>.from(hospSnap.value as Map);
      _hospitalName = d['hospitalName']?.toString() ?? "";
      _hospitalCity = d['city']?.toString() ?? "";
    }

    // ── تحميل الحدود الاحتياطية المحفوظة ──
    final threshSnap = await FirebaseDatabase.instance
        .ref("BloodInventoryThresholds/$_hospitalId")
        .get();
    if (threshSnap.exists && threshSnap.value is Map) {
      final t = Map<String, dynamic>.from(threshSnap.value as Map);
      t.forEach((blood, val) {
        _reserveThresholds[blood] = (val as num?)?.toInt() ?? 0;
      });
    }

    // ── مخزون هذا المستشفى ──
    FirebaseDatabase.instance
        .ref("BloodInventory/$_hospitalId")
        .onValue
        .listen((event) {
      final Map<String, int> inv = {};
      if (event.snapshot.exists && event.snapshot.value is Map) {
        Map<String, dynamic>.from(event.snapshot.value as Map)
            .forEach((blood, val) {
          if (val is Map) {
            inv[blood] = (val['units'] as num?)?.toInt() ?? 0;
          }
        });
      }
      setState(() => _myInventory = inv);
    });

    // ── مخزون المستشفيات الأخرى — مجمّع حسب المستشفى ──
    FirebaseDatabase.instance.ref("BloodInventory").onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        setState(() => _otherHospitals = {});
        return;
      }

      // نحتاج أيضاً الحدود الاحتياطية لكل مستشفى عشان نحسب الفائض الحقيقي
      FirebaseDatabase.instance
          .ref("BloodInventoryThresholds")
          .get()
          .then((threshSnap) {
        final Map<String, Map<String, int>> allThresholds = {};
        if (threshSnap.exists && threshSnap.value is Map) {
          Map<String, dynamic>.from(threshSnap.value as Map)
              .forEach((hId, tVal) {
            if (tVal is Map) {
              final t = Map<String, dynamic>.from(tVal);
              allThresholds[hId] = {};
              t.forEach((blood, val) {
                allThresholds[hId]![blood] = (val as num?)?.toInt() ?? 0;
              });
            }
          });
        }

        final Map<String, Map<String, dynamic>> hospitals = {};
        Map<String, dynamic>.from(event.snapshot.value as Map)
            .forEach((hId, hVal) {
          if (hId == _hospitalId) return;
          if (hVal is! Map) return;

          final hData = Map<String, dynamic>.from(hVal);
          String hospName = hId;
          String hospCity = "";
          final Map<String, int> surplus = {};

          hData.forEach((blood, bVal) {
            if (bVal is Map) {
              final units = (bVal['units'] as num?)?.toInt() ?? 0;
              final threshold = allThresholds[hId]?[blood] ?? 0;
              final available = units - threshold;
              if (available > 0) {
                surplus[blood] = available;
                hospName = bVal['hospitalName']?.toString().isNotEmpty == true
                    ? bVal['hospitalName'].toString()
                    : hospName;
                hospCity = bVal['city']?.toString() ?? hospCity;
              }
            }
          });

          if (surplus.isNotEmpty) {
            hospitals[hId] = {
              'hospitalId': hId,
              'hospitalName': hospName,
              'city': hospCity,
              'surplus': surplus,
            };
          }
        });

        // ترتيب: نفس المدينة أولاً
        final sorted = hospitals.entries.toList()
          ..sort((a, b) {
            final aCity = a.value['city'] == _hospitalCity ? 0 : 1;
            final bCity = b.value['city'] == _hospitalCity ? 0 : 1;
            return aCity.compareTo(bCity);
          });

        setState(() {
          _otherHospitals = Map.fromEntries(sorted);
        });
      });
    });

    // ── طلبات التبادل ──
    // الواردة: fromHospitalId == _hospitalId (نحن المصدر، نوافق أو نرفض)
    // الصادرة: toHospitalId == _hospitalId (نحن الطالبون، ننتظر)
    FirebaseDatabase.instance
        .ref("BloodTransferRequests")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        setState(() {
          _outgoingRequests = [];
          _incomingRequests = [];
          _isLoading = false;
        });
        return;
      }
      final List<Map<String, dynamic>> outgoing = [];
      final List<Map<String, dynamic>> incoming = [];

      Map<String, dynamic>.from(event.snapshot.value as Map)
          .forEach((key, val) {
        if (val is! Map) return;
        final req = Map<String, dynamic>.from(val);
        req['_key'] = key;

        // نحن المصدر (عندنا الدم) → طلب وارد، نوافق أو نرفض
        if (req['fromHospitalId'] == _hospitalId) incoming.add(req);

        // نحن الطالبون → طلب صادر، ننتظر رد المصدر
        if (req['toHospitalId'] == _hospitalId) outgoing.add(req);
      });

      outgoing.sort((a, b) => ((b['createdAt'] ?? 0) as int)
          .compareTo((a['createdAt'] ?? 0) as int));
      incoming.sort((a, b) => ((b['createdAt'] ?? 0) as int)
          .compareTo((a['createdAt'] ?? 0) as int));

      setState(() {
        _outgoingRequests = outgoing;
        _incomingRequests = incoming;
        _isLoading = false;
      });
    });
  }

  Future<void> _updateInventory(String bloodType, int units) async {
    final now = DateTime.now();
    final dateStr = "${now.day}/${now.month}/${now.year}";
    await FirebaseDatabase.instance
        .ref("BloodInventory/$_hospitalId/$bloodType")
        .set({
      'units': units,
      'hospitalName': _hospitalName,
      'city': _hospitalCity,
      'updatedAt': dateStr,
    });
  }

  Future<void> _saveThreshold(String bloodType, int threshold) async {
    await FirebaseDatabase.instance
        .ref("BloodInventoryThresholds/$_hospitalId/$bloodType")
        .set(threshold);
    setState(() => _reserveThresholds[bloodType] = threshold);
  }

  // ── الفائض الفعلي = المخزون - الحد الاحتياطي ──
  int _surplusFor(String bloodType) {
    final total = _myInventory[bloodType] ?? 0;
    final reserve = _reserveThresholds[bloodType] ?? 0;
    return (total - reserve).clamp(0, 9999);
  }

  void _showUpdateDialog(String bloodType) {
    final currentTotal = _myInventory[bloodType] ?? 0;
    final currentReserve = _reserveThresholds[bloodType] ?? 0;
    final totalCtrl = TextEditingController(text: currentTotal.toString());
    final reserveCtrl = TextEditingController(text: currentReserve.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.bloodtype, color: Colors.red),
          const SizedBox(width: 8),
          Text("إدارة مخزون $bloodType"),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: totalCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "إجمالي الوحدات المتوفرة",
                hintText: "مثال: 20",
                prefixIcon: const Icon(Icons.water_drop, color: Colors.red),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reserveCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "الاحتياطي (لا يظهر للثانيين)",
                hintText: "مثال: 10",
                helperText: "الفائض = الإجمالي - الاحتياطي",
                prefixIcon:
                    const Icon(Icons.lock_outline, color: Colors.orange),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final total = int.tryParse(totalCtrl.text.trim()) ?? 0;
              final reserve = int.tryParse(reserveCtrl.text.trim()) ?? 0;
              final clampedReserve = reserve.clamp(0, total);
              await _updateInventory(bloodType, total);
              await _saveThreshold(bloodType, clampedReserve);
              if (mounted) {
                Navigator.pop(context);
                final surplus = (total - clampedReserve).clamp(0, 9999);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      "✅ $bloodType: $total وحدة | احتياطي: $clampedReserve | فائض: $surplus"),
                  backgroundColor: Colors.green,
                ));
              }
            },
            child: const Text("حفظ", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendTransferRequest(String fromHospitalId,
      String fromHospitalName, String bloodType, int availableUnits) async {
    final unitsCtrl = TextEditingController(text: "1");
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.local_shipping, color: Colors.blue),
          SizedBox(width: 8),
          Text("طلب نقل دم"),
        ]),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  "من: $fromHospitalName\nالفصيلة: $bloodType\nالمتوفر (فائض): $availableUnits وحدات",
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 14),
              TextFormField(
                controller: unitsCtrl,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? "");
                  if (n == null || n < 1) return "أدخل عدداً صحيحاً";
                  if (n > availableUnits) {
                    return "لا يتجاوز $availableUnits";
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "عدد الوحدات المطلوبة",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, true);
            },
            child: const Text("إرسال الطلب",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final units = int.tryParse(unitsCtrl.text.trim()) ?? 1;

    final newRef =
        FirebaseDatabase.instance.ref("BloodTransferRequests").push();
    await newRef.set({
      'fromHospitalId': fromHospitalId, // الي عندها الدم (توافق/ترفض)
      'fromHospitalName': fromHospitalName,
      'toHospitalId': _hospitalId, // الي طلبت (تنتظر)
      'toHospitalName': _hospitalName,
      'bloodType': bloodType,
      'requestedUnits': units,
      'status': 'معلق',
      'city': _hospitalCity,
      'createdAt': ServerValue.timestamp,
    });

    // إشعار للمستشفى الي عندها الدم (هي الي ستوافق/ترفض)
    await FirebaseDatabase.instance
        .ref("Notifications/$fromHospitalId")
        .push()
        .set({
      'title': "طلب نقل دم 🩸",
      'message': "$_hospitalName تطلب $units وحدة من فصيلة $bloodType.",
      'type': "blood_transfer_request",
      'requestId': newRef.key,
      'isRead': false,
      'createdAt': ServerValue.timestamp,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("✅ تم إرسال طلب النقل للمستشفى"),
        backgroundColor: Colors.blue,
      ));
    }
  }

  // ── الموافقة/الرفض: نحن fromHospitalId (عندنا الدم) ──
  Future<void> _respondToTransferRequest(
      String key, String status, Map<String, dynamic> req) async {
    await FirebaseDatabase.instance
        .ref("BloodTransferRequests/$key")
        .update({'status': status});

    if (status == "مقبول") {
      final blood = req['bloodType']?.toString() ?? "";
      final requested = (req['requestedUnits'] as num?)?.toInt() ?? 0;
      final current = _myInventory[blood] ?? 0;
      // نخفض من إجمالي مخزوننا
      final newUnits = (current - requested).clamp(0, 9999);
      await _updateInventory(blood, newUnits);

      // إشعار للمستشفى الطالبة (toHospitalId)
      final toId = req['toHospitalId']?.toString() ?? "";
      if (toId.isNotEmpty) {
        await FirebaseDatabase.instance.ref("Notifications/$toId").push().set({
          'title': "تم قبول طلب نقل الدم ✅",
          'message':
              "$_hospitalName قبلت إرسال $requested وحدة من فصيلة $blood.",
          'type': "blood_transfer_approved",
          'isRead': false,
          'createdAt': ServerValue.timestamp,
        });
      }
    } else {
      final toId = req['toHospitalId']?.toString() ?? "";
      if (toId.isNotEmpty) {
        await FirebaseDatabase.instance.ref("Notifications/$toId").push().set({
          'title': "تم رفض طلب نقل الدم ❌",
          'message':
              "$_hospitalName اعتذرت عن إرسال ${req['requestedUnits']} وحدة من فصيلة ${req['bloodType']}.",
          'type': "blood_transfer_rejected",
          'isRead': false,
          'createdAt': ServerValue.timestamp,
        });
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == "مقبول" ? "✅ تم قبول الطلب" : "❌ تم رفض الطلب"),
        backgroundColor: status == "مقبول" ? Colors.green : Colors.red,
      ));
    }
  }

  Color _bloodColor(String blood) {
    final units = _myInventory[blood] ?? 0;
    if (units == 0) return Colors.grey;
    if (units <= 2) return Colors.red;
    if (units <= 5) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        title: const Text("مخزون الدم",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2, size: 18),
                  SizedBox(width: 5),
                  Text("مخزوني"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.other_houses, size: 18),
                  const SizedBox(width: 5),
                  Text(
                    "مستشفيات${_otherHospitals.isNotEmpty ? ' 🟢' : ''}",
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.swap_horiz, size: 18),
                  const SizedBox(width: 5),
                  Text(
                    "طلبات${_incomingRequests.where((r) => r['status'] == 'معلق').isNotEmpty ? ' 🔴' : ''}",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMyInventoryTab(),
                _buildOtherHospitalsTab(),
                _buildTransferRequestsTab(),
              ],
            ),
    );
  }

  // ══════════════════════════════════════
  // تاب مخزوني
  // ══════════════════════════════════════
  Widget _buildMyInventoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.inventory_2, color: Colors.white),
                  SizedBox(width: 8),
                  Text("مخزون الدم",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 4),
                Text(
                  "المستشفى: $_hospitalName — $_hospitalCity",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "اضغط على أي فصيلة لتحديث مخزونها وتحديد الكمية الاحتياطية التي لا تظهر للمستشفيات الأخرى.",
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: _bloodTypes.length,
            itemBuilder: (_, i) {
              final blood = _bloodTypes[i];
              final total = _myInventory[blood] ?? 0;
              final reserve = _reserveThresholds[blood] ?? 0;
              final surplus = _surplusFor(blood);
              final color = _bloodColor(blood);
              return GestureDetector(
                onTap: () => _showUpdateDialog(blood),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            blood,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: color),
                          ),
                          Icon(Icons.edit,
                              color: Colors.grey.shade400, size: 16),
                        ],
                      ),
                      // إجمالي
                      Row(children: [
                        Icon(Icons.water_drop, color: color, size: 14),
                        const SizedBox(width: 3),
                        Text("$total إجمالي",
                            style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ]),
                      // احتياطي وفائض
                      Row(children: [
                        const Icon(Icons.lock_outline,
                            color: Colors.orange, size: 13),
                        const SizedBox(width: 3),
                        Text("$reserve احتياطي",
                            style: const TextStyle(
                                color: Colors.orange, fontSize: 11)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: surplus > 0
                                ? Colors.green.shade50
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "$surplus فائض",
                            style: TextStyle(
                              color: surplus > 0 ? Colors.green : Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("مفتاح الألوان:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _legendRow(Colors.green, "متوفر بكمية كافية (+5)"),
                _legendRow(Colors.orange, "متوفر بكمية محدودة (3-5)"),
                _legendRow(Colors.red, "منخفض جداً (1-2)"),
                _legendRow(Colors.grey, "غير متوفر (0)"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ]),
    );
  }

  // ══════════════════════════════════════
  // تاب مستشفيات أخرى — قائمة مستشفيات أولاً، ضغطة = فصائلها
  // ══════════════════════════════════════
  Widget _buildOtherHospitalsTab() {
    if (_otherHospitals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_hospital_outlined,
                size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text("لا يوجد فائض متاح من مستشفيات أخرى",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          ],
        ),
      );
    }

    final hospitals = _otherHospitals.values.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: hospitals.length,
      itemBuilder: (_, i) {
        final hosp = hospitals[i];
        final hId = hosp['hospitalId'] as String;
        final hName = hosp['hospitalName'] as String;
        final hCity = hosp['city'] as String;
        final surplus = hosp['surplus'] as Map<String, int>;
        final sameCity = hCity == _hospitalCity;
        final isExpanded = _expandedHospitalId == hId;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: sameCity ? Colors.blue.shade200 : Colors.grey.shade200),
          ),
          child: Column(
            children: [
              // ── رأس المستشفى (قابل للضغط) ──
              InkWell(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                onTap: () {
                  setState(() {
                    _expandedHospitalId = isExpanded ? null : hId;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: sameCity
                              ? Colors.blue.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.local_hospital,
                            color: sameCity ? Colors.blue : Colors.grey,
                            size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              "📍 $hCity${sameCity ? ' (نفس مدينتك)' : ''}",
                              style: TextStyle(
                                color: sameCity ? Colors.blue : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              "🩸 ${surplus.length} فصيلة متاحة",
                              style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),

              // ── فصائل الدم (تظهر عند الضغط) ──
              if (isExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: surplus.entries.map((entry) {
                      final blood = entry.key;
                      final units = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                blood,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "$units وحدة فائضة",
                                style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                              ),
                              onPressed: () => _sendTransferRequest(
                                  hId, hName, blood, units),
                              child: const Text("طلب",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════
  // تاب طلبات التبادل
  // ══════════════════════════════════════
  Widget _buildTransferRequestsTab() {
    // الواردة المعلقة: طلبات مستشفيات تريد منا دم، ننتظر ردنا
    final pendingIncoming =
        _incomingRequests.where((r) => r['status'] == 'معلق').toList();
    final otherIncoming =
        _incomingRequests.where((r) => r['status'] != 'معلق').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── الطلبات الواردة المعلقة (مستشفيات تريد منا دم) ──
          if (pendingIncoming.isNotEmpty) ...[
            _sectionHeader(
                "📥 مستشفيات تطلب منك دماً — بانتظار ردك", Colors.red),
            ...pendingIncoming.map((req) => _incomingCard(req, pending: true)),
            const SizedBox(height: 16),
          ],

          // ── الطلبات الصادرة (طلبنا من مستشفيات أخرى) ──
          if (_outgoingRequests.isNotEmpty) ...[
            _sectionHeader(
                "📤 طلباتك الصادرة — تنتظر رد المستشفى", Colors.blue),
            ..._outgoingRequests.map((req) => _outgoingCard(req)),
            const SizedBox(height: 16),
          ],

          // ── الواردة السابقة ──
          if (otherIncoming.isNotEmpty) ...[
            _sectionHeader("📋 طلبات واردة سابقة", Colors.grey),
            ...otherIncoming.map((req) => _incomingCard(req, pending: false)),
          ],

          if (_incomingRequests.isEmpty && _outgoingRequests.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(Icons.swap_horiz,
                        size: 60, color: Colors.grey.shade400),
                    const SizedBox(height: 14),
                    Text("لا يوجد طلبات تبادل",
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 15)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: color)),
    );
  }

  // بطاقة الطلب الوارد (مستشفى تطلب منا) — نحن نوافق أو نرفض
  Widget _incomingCard(Map<String, dynamic> req, {required bool pending}) {
    final status = req['status']?.toString() ?? "معلق";
    final statusColor = status == "مقبول"
        ? Colors.green
        : status == "مرفوض"
            ? Colors.red
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              // الطالبة هي toHospitalName
              Expanded(
                child: Text(
                  "🏥 ${req['toHospitalName'] ?? 'مستشفى'}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(status,
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
                "🩸 فصيلة: ${req['bloodType']}  |  ${req['requestedUnits']} وحدة"),
            if (pending) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text("قبول",
                        style: TextStyle(color: Colors.white)),
                    onPressed: () =>
                        _respondToTransferRequest(req['_key'], "مقبول", req),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text("رفض",
                        style: TextStyle(color: Colors.white)),
                    onPressed: () =>
                        _respondToTransferRequest(req['_key'], "مرفوض", req),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  // بطاقة الطلب الصادر (طلبنا من مستشفى أخرى) — ننتظر ردها
  Widget _outgoingCard(Map<String, dynamic> req) {
    final status = req['status']?.toString() ?? "معلق";
    final statusColor = status == "مقبول"
        ? Colors.green
        : status == "مرفوض"
            ? Colors.red
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                // المصدر هو fromHospitalName
                "من: ${req['fromHospitalName'] ?? 'مستشفى'}",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text("🩸 ${req['bloodType']}  |  ${req['requestedUnits']} وحدة"),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor),
            ),
            child: Text(status,
                style:
                    TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}
