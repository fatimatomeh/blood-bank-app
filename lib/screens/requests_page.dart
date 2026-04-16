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
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final donorSnap =
        await FirebaseDatabase.instance.ref("Donors/${user.uid}").get();

    if (donorSnap.exists && donorSnap.value is Map) {
      final donor = Map<String, dynamic>.from(donorSnap.value as Map);

      donorCity = CityHelper.normalize(donor['city']?.toString());
      donorBlood = donor['bloodType']?.toString().trim() ?? "";
    }

    // ✅ مراقبة التبرعات المسجلة لهذا المتبرع
    await _donationsSubscription?.cancel();
    _donationsSubscription = FirebaseDatabase.instance
        .ref("Donors/${user.uid}/donations")
        .onValue
        .listen((event) {
      final data = event.snapshot.value;

      setState(() {
        if (data != null && data is Map) {
          donatedRequestIds = Map<String, dynamic>.from(data).keys.toSet();
        } else {
          donatedRequestIds = {};
        }
      });
    });

    // ✅ مراقبة الطلبات
    await _requestsSubscription?.cancel();
    _requestsSubscription =
        FirebaseDatabase.instance.ref("Requests").onValue.listen((event) {
      final data = event.snapshot.value;
      List<Map<String, dynamic>> temp = [];

      if (data != null && data is Map) {
        data.forEach((key, value) {
          final req = Map<String, dynamic>.from(value);

          final reqCity = CityHelper.normalize(req['city']?.toString());
          final reqBlood = req['bloodType']?.toString().trim() ?? "";

          // فلترة حسب المدينة وفصيلة الدم فقط
          if (reqCity == donorCity && reqBlood == donorBlood) {
            req['requestId'] = key;
            temp.add(req);
          }
        });
      }

      temp.sort((a, b) {
        final aTime = a['createdAt'] ?? 0;
        final bTime = b['createdAt'] ?? 0;
        return (bTime as int).compareTo(aTime as int);
      });

      if (mounted) {
        setState(() {
          requests = temp;
        });
      }
    });
  }

  @override
  void dispose() {
    _donationsSubscription?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }

  String _formatDateTime(dynamic ts) {
    if (ts == null) return "غير متوفر";

    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts as int);

      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;

      int hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');

      String period = "ص";
      if (hour >= 12) period = "م";

      hour = hour % 12;
      if (hour == 0) hour = 12;

      final hourStr = hour.toString().padLeft(2, '0');

      return "$day/$month/$year - $hourStr:$minute $period";
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
        title: const Text(
          "طلبات الدم",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: requests.isEmpty
          ? const Center(
              child: Text(
                "لا يوجد طلبات في مدينتك حالياً",
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final req = requests[index];
                final requestId = req['requestId']?.toString() ?? "";

                final alreadyDonated = requestId.isNotEmpty &&
                    donatedRequestIds.contains(requestId);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "🏥 ${req['hospitalName'] ?? 'غير محدد'}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text("📍 المدينة: ${req['city'] ?? 'غير محدد'}"),
                        Text(
                            "🩸 فصيلة الدم: ${req['bloodType'] ?? 'غير محدد'}"),
                        Text("🧪 عدد الوحدات: ${req['units'] ?? '0'}"),
                        Text("🏢 القسم: ${req['department'] ?? 'غير محدد'}"),
                        Text(
                          "📅 تاريخ الطلب: ${_formatDateTime(req['createdAt'])}",
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 15),
                        alreadyDonated
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.green.shade300),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.green),
                                    SizedBox(width: 8),
                                    Text(
                                      "لقد تبرعت لهذا الطلب",
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    // ✅ انتقل مباشرة لصفحة التبرع بدون أي فحص
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DonatePage(
                                          requestData: req,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "تبرع الآن",
                                    style: TextStyle(color: Colors.white),
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
}