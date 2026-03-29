import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'donate_page.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  List<Map<String, dynamic>> requests = [];

  String donorCity = "";
  String donorBlood = "";

  Map<String, String> cityMap = {
    "ramallah": "ramallah",
    "رام الله": "ramallah",
    "al-bireh": "ramallah",
    "البيرة": "ramallah",
    "nablus": "nablus",
    "نابلس": "nablus",
    "hebron": "hebron",
    "الخليل": "hebron",
    "bethlehem": "bethlehem",
    "بيت لحم": "bethlehem",
    "jenin": "jenin",
    "جنين": "jenin",
    "tulkarm": "tulkarm",
    "طولكرم": "tulkarm",
    "qalqilya": "qalqilya",
    "قلقيلية": "qalqilya",
    "jericho": "jericho",
    "أريحا": "jericho",
    "salfit": "salfit",
    "سلفيت": "salfit",
    "tubas": "tubas",
    "طوباس": "tubas",
  };

  String normalizeCity(String? city) {
    if (city == null) return "";
    return cityMap[city.toLowerCase().trim()] ?? city.toLowerCase().trim();
  }

  @override
  void initState() {
    super.initState();
    _loadDonorAndRequests();
  }

  Future<void> _loadDonorAndRequests() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DatabaseReference donorRef =
        FirebaseDatabase.instance.ref("Donors/${user.uid}");

    final donorSnap = await donorRef.get();

    if (donorSnap.exists && donorSnap.value is Map) {
      final donor = Map<String, dynamic>.from(donorSnap.value as Map);

      donorCity = normalizeCity(donor['city']?.toString());
      donorBlood = donor['bloodType']?.toString().trim() ?? "";
    }

    DatabaseReference requestsRef = FirebaseDatabase.instance.ref("Requests");

    requestsRef.onValue.listen((event) {
      final data = event.snapshot.value;

      List<Map<String, dynamic>> temp = [];

      if (data != null && data is Map) {
        data.forEach((key, value) {
          final req = Map<String, dynamic>.from(value);

          final reqCity = normalizeCity(req['city']?.toString());
          final reqBlood = req['bloodType']?.toString().trim() ?? "";

        
          if (reqCity == donorCity && reqBlood == donorBlood) {
            temp.add(req);
          }
        });
      }

      setState(() {
        requests = temp;
      });
    });
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
                "لا يوجد طلبات مطابقة حالياً",
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final req = requests[index];

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
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
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
