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
  late DatabaseReference dbRef;
  Map<String, dynamic> requests = {};

  @override
  void initState() {
    super.initState();
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String uid = user.uid;

      // أولاً: نجيب المدينة من بيانات المتبرع
      DatabaseReference donorRef = FirebaseDatabase.instance.ref("Donors/$uid");

      donorRef.get().then((snapshot) {
        if (snapshot.exists) {
          final donorData = Map<String, dynamic>.from(snapshot.value as Map);
          final city = donorData['city'] ?? "غير محدد";
          // الطلبات حسب المدينة
          dbRef = FirebaseDatabase.instance.ref("Requests/$city");

          dbRef.onValue.listen((event) {
            final data = event.snapshot.value as Map?;
            if (data != null) {
              setState(() {
                requests = Map<String, dynamic>.from(data);
                donorRef.get().then((snapshot) {});
              });
            }
          });
        }
      });
    }
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
      body: requests.isEmpty
          ? const Center(child: Text("لا يوجد طلبات حالياً"))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: requests.entries.map((entry) {
                final req = Map<String, dynamic>.from(entry.value);
                return Column(
                  children: [
                    requestCard(
                      context,
                      req['bloodType'] ?? "غير محدد",
                      req['hospital'] ?? "غير محدد",
                      req['city'] ?? "غير محدد",
                      req['department'] ?? "غير محدد",
                      req['units']?.toString() ?? "0",
                      req['time'] ?? "غير محدد",
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Widget requestCard(BuildContext context, String blood, String hospital,
      String city, String department, String units, String time) {
    return Container(
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
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.red,
            child: Text(blood,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 15),
          Text(hospital,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text("📍 $city"),
          Text("🏥 $department"),
          const SizedBox(height: 12),
          Text("🩸 عدد الوحدات: $units",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("⏰ $time", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DonatePage()));
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
