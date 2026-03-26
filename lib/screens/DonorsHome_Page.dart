import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'donate_page.dart';
import 'requests_page.dart';

class DonorsHomePage extends StatefulWidget {
  const DonorsHomePage({super.key});

  @override
  _DonorsHomePageState createState() => _DonorsHomePageState();
}

class _DonorsHomePageState extends State<DonorsHomePage> {
  final DatabaseReference urgentRef =
      FirebaseDatabase.instance.ref("urgentRequest");
  final DatabaseReference statsRef =
      FirebaseDatabase.instance.ref("userStats/fatima");

  Map urgentData = {};
  Map statsData = {};

  @override
  void initState() {
    super.initState();

    // جلب الطلب العاجل
    urgentRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          urgentData = data;
        });
      }
    });

    // جلب الإحصائيات
    statsRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          statsData = data;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        title: Text(
          "VivaLink",
          style: GoogleFonts.atma(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.waving_hand, color: Colors.red),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "أهلاً بك ! تبرعك قد ينقذ حياة",
                      style: TextStyle(fontSize: 19),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // الطلب العاجل من القاعدة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bloodtype, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        "طلب دم عاجل",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text("المستشفى: ${urgentData['hospital'] ?? 'غير محدد'}",
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                  Text(
                      "الفصيلة المطلوبة: ${urgentData['bloodType'] ?? 'غير محدد'}",
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                  Text(
                      "الوحدات المطلوبة: ${urgentData['units']?.toString() ?? '0'}",
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const DonatePage()));
                      },
                      child: const Text("تبرع الآن",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const RequestsPage()));
                },
                child: const Text("عرض جميع الطلبات",
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 30),
            const Text("إحصائياتك",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                statCard(
                    Icons.favorite,
                    statsData['donationsCount']?.toString() ?? "0",
                    "عدد التبرعات"),
                statCard(Icons.calendar_today,
                    statsData['lastDonation'] ?? "غير محدد", "آخر تبرع"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget statCard(IconData icon, String value, String label) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.red),
          const SizedBox(height: 10),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
