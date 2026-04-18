import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'city_helper.dart';
import 'donate_page.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  List<Map<String, dynamic>> requests = [];
  Set<String> donatedRequestIds = {};
  String donorCity = "";
  String donorBlood = "";

  StreamSubscription? _donationsSubscription;
  StreamSubscription? _requestsSubscription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final donorSnap =
        await FirebaseDatabase.instance.ref("Donors/${user.uid}").get();
    if (donorSnap.exists && donorSnap.value is Map) {
      final donor = Map<String, dynamic>.from(donorSnap.value as Map);
      donorCity = CityHelper.normalize(donor['city']?.toString());
      donorBlood = donor['bloodType']?.toString().trim() ?? "";
    }

    await _donationsSubscription?.cancel();
    _donationsSubscription = FirebaseDatabase.instance
        .ref("Donors/${user.uid}/donations")
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      setState(() {
        donatedRequestIds = (data is Map)
            ? Map<String, dynamic>.from(data).keys.toSet()
            : {};
      });
    });

    await _requestsSubscription?.cancel();
    _requestsSubscription =
        FirebaseDatabase.instance.ref("Requests").onValue.listen((event) {
      final data = event.snapshot.value;
      List<Map<String, dynamic>> temp = [];

      if (data is Map) {
        data.forEach((key, value) {
          final req = Map<String, dynamic>.from(value);
          final reqCity = CityHelper.normalize(req['city']?.toString());
          final reqBlood = req['bloodType']?.toString().trim() ?? "";
          final status = req['status']?.toString() ?? "";
          // ملغي فقط نخفيه، المغلق نعرضه ببانر
          if (reqCity == donorCity &&
              reqBlood == donorBlood &&
              status != 'ملغي') {
            req['requestId'] = key;
            temp.add(req);
          }
        });
      }

      const orderMap = {
        'عاجل': 0,
        'مفتوح': 1,
        'بانتظار': 2,
        'مغلق': 3,
        'مكتمل': 4
      };
      temp.sort((a, b) {
        final aO = orderMap[a['status']] ?? 5;
        final bO = orderMap[b['status']] ?? 5;
        if (aO != bO) return aO.compareTo(bO);
        return ((b['createdAt'] ?? 0) as int)
            .compareTo((a['createdAt'] ?? 0) as int);
      });

      if (mounted) setState(() => requests = temp);
    });
  }

  @override
  void dispose() {
    _donationsSubscription?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }

  bool _isOpen(String status) =>
      status == 'عاجل' || status == 'مفتوح' || status == 'بانتظار';

  String _formatDateTime(dynamic ts) {
    if (ts == null) return "غير متوفر";
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts as int);
      int h = dt.hour;
      final period = h >= 12 ? "م" : "ص";
      h = h % 12;
      if (h == 0) h = 12;
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}"
          " - ${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period";
    } catch (_) {
      return "غير متوفر";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        title: const Text("طلبات الدم",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: requests.isEmpty
          ? const Center(
              child: Text("لا يوجد طلبات في مدينتك حالياً",
                  style: TextStyle(fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: requests.length,
              itemBuilder: (ctx, index) {
                final req = requests[index];
                final requestId = req['requestId']?.toString() ?? "";
                final status = req['status']?.toString() ?? "";
                final isOpen = _isOpen(status);
                final alreadyDonated = donatedRequestIds.contains(requestId);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(
                        color:
                            isOpen ? Colors.red.shade200 : Colors.grey.shade300,
                        width: 1),
                  ),
                  color: isOpen ? Colors.white : Colors.grey.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "🏥 ${req['hospitalName'] ?? 'غير محدد'}",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: isOpen
                                      ? Colors.black87
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOpen
                                    ? Colors.red.shade50
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isOpen ? "مفتوح 🔴" : "مغلق ✅",
                                style: TextStyle(
                                  color: isOpen ? Colors.red : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text("📍 ${req['city'] ?? '-'}",
                            style: TextStyle(
                                color: isOpen
                                    ? Colors.black87
                                    : Colors.grey.shade500)),
                        Text("🩸 ${req['bloodType'] ?? '-'}",
                            style: TextStyle(
                                color: isOpen
                                    ? Colors.black87
                                    : Colors.grey.shade500)),
                        Text("🧪 ${req['units'] ?? '-'}",
                            style: TextStyle(
                                color: isOpen
                                    ? Colors.black87
                                    : Colors.grey.shade500)),
                        Text("🏢 ${req['department'] ?? '-'}",
                            style: TextStyle(
                                color: isOpen
                                    ? Colors.black87
                                    : Colors.grey.shade500)),
                        Text("📅 ${_formatDateTime(req['createdAt'])}",
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12)),
                        const SizedBox(height: 12),
                        if (alreadyDonated)
                          _banner(
                              Colors.green, Icons.check_circle,
                              "لقد تبرعت لهذا الطلب ✅")
                        else if (!isOpen)
                          _banner(
                              Colors.grey, Icons.lock_outline,
                              "تم التبرع لهذا الطلب من شخص آخر")
                        else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.favorite,
                                  color: Colors.white, size: 18),
                              label: const Text("تبرع الآن",
                                  style: TextStyle(color: Colors.white)),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        DonatePage(requestData: req)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _banner(Color color, IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}