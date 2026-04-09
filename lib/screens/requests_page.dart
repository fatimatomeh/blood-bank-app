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

  bool _needsBloodTest = false;

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

      _checkIfNeedsBloodTest(donor);
    }

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

  void _checkIfNeedsBloodTest(Map<String, dynamic> profile) {
    final checkStr =
        (profile['lastBloodTest'] ?? profile['lastDonation'])?.toString() ?? "";

    if (checkStr.isEmpty || checkStr == "غير محدد") {
      final createdAtStr = profile['createdAt']?.toString() ?? "";

      if (createdAtStr.isNotEmpty) {
        try {
          final createdAt = DateTime.parse(createdAtStr);
          final days = DateTime.now().difference(createdAt).inDays;

          setState(() {
            _needsBloodTest = days >= 120;
          });
          return;
        } catch (_) {}
      }

      setState(() => _needsBloodTest = false);
      return;
    }

    try {
      final parts = checkStr.split('/');

      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);

        final lastCheck = DateTime(year, month, day);
        final days = DateTime.now().difference(lastCheck).inDays;

        setState(() {
          _needsBloodTest = days >= 120;
        });
      }
    } catch (_) {
      setState(() => _needsBloodTest = false);
    }
  }

  @override
  void dispose() {
    _donationsSubscription?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return "";
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts as int);
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return "";
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
                        if (req['createdAt'] != null)
                          Text(
                            "📅 تاريخ الطلب: ${_formatDate(req['createdAt'])}",
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
                                    if (_needsBloodTest) {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                          title: const Row(
                                            children: [
                                              Icon(
                                                Icons.science_outlined,
                                                color: Colors.purple,
                                              ),
                                              SizedBox(width: 8),
                                              Text("فحص دوري مطلوب"),
                                            ],
                                          ),
                                          content: const Text(
                                            "يجب إجراء فحص الدم الدوري قبل التبرع.\nيرجى مراجعة صفحة حسابك.",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text("حسناً"),
                                            ),
                                          ],
                                        ),
                                      );
                                      return;
                                    }

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
