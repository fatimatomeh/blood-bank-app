import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'donate_page.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  _RequestsPageState createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  List<Map<String, dynamic>> filteredRequests = [];
  bool isLoading = true;
  String donorCity = "";

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  // دالة لتوحيد أسماء المدن
  String normalizeCity(String? city) {
    if (city == null) return "";
    return city.toLowerCase().trim();
  }

  void _fetchRequests() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      // 1. جلب مدينة المتبرع
      DataSnapshot donorSnapshot =
          await FirebaseDatabase.instance.ref("Donors/${user.uid}/city").get();

      if (donorSnapshot.exists) {
        donorCity = donorSnapshot.value.toString().trim();
      }

      // 2. جلب الطلبات
      DatabaseReference requestsRef = FirebaseDatabase.instance.ref("Requests");

      DataSnapshot snapshot = await requestsRef.get();
      _processData(snapshot.value);

      // مراقبة التحديثات
      requestsRef.onValue.listen((event) {
        _processData(event.snapshot.value);
      });
    } catch (e) {
      print("Error fetching data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _processData(Object? data) {
    if (!mounted) return;

    List<Map<String, dynamic>> tempRequests = [];
    if (data != null && data is Map) {
      data.forEach((key, value) {
        final req = Map<String, dynamic>.from(value as Map);
        String reqCity = normalizeCity(req['city']);
        String donorCityNorm = normalizeCity(donorCity);

        if (reqCity == donorCityNorm) {
          tempRequests.add(req);
        }
      });
    }

    setState(() {
      filteredRequests = tempRequests;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        title: const Text("طلبات التبرع"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : filteredRequests.isEmpty
              ? _buildNoRequestsWidget()
              : _buildRequestsList(),
    );
  }

  Widget _buildNoRequestsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "لا يوجد طلبات حالياً في $donorCity",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text("سوف تظهر الطلبات هنا فور إضافتها",
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredRequests.length,
      itemBuilder: (context, index) {
        final req = filteredRequests[index];
        return requestCard(context, req);
      },
    );
  }

  Widget requestCard(BuildContext context, Map<String, dynamic> req) {
    final blood = req['bloodType'] ?? "؟";
    final hospital = req['hospitalName'] ?? "غير محدد";
    final city = req['city'] ?? "غير محدد";
    final department = req['department'] ?? "غير محدد";
    final units = req['units']?.toString() ?? "0";
    final time = req['time'] ?? "غير محدد";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.red,
                child: Text(blood,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hospital,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("📍 $city - $department",
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("🩸 الوحدات: $units",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("⏰ $time",
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DonatePage(requestData: {
                      "bloodType": blood,
                      "hospitalName": hospital,
                      "city": city,
                      "department": department,
                      "units": units,
                      "time": time,
                    }),
                  ),
                );
              },
              child: const Text("تبرع الآن",
                  style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }
}
