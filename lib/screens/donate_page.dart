import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DonatePage extends StatefulWidget {
  const DonatePage({super.key});

  @override
  _DonatePageState createState() => _DonatePageState();
}

class _DonatePageState extends State<DonatePage> {
  final DatabaseReference dbRef =
      FirebaseDatabase.instance.ref("requests/request1");
  Map requestData = {};

  @override
  void initState() {
    super.initState();
    dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          requestData = data;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        title: const Text("التبرع بالدم"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10)
                ],
              ),
              child: Column(
                children: [
                  infoRow(Icons.favorite,
                      "فصيلة الدم: ${requestData['bloodType'] ?? 'غير محدد'}"),
                  infoRow(Icons.local_hospital,
                      requestData['hospital'] ?? "غير محدد"),
                  infoRow(Icons.location_on, requestData['city'] ?? "غير محدد"),
                  infoRow(Icons.medical_services,
                      requestData['department'] ?? "غير محدد"),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Align(
                alignment: Alignment.centerRight,
                child: Text("وقت الوصول المتوقع",
                    style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15))),
              hint: const Text("اختر الوقت"),
              items: const [
                DropdownMenuItem(value: "9", child: Text("9:00 صباحاً")),
                DropdownMenuItem(value: "10", child: Text("10:00 صباحاً")),
              ],
              onChanged: (value) {},
            ),
            const SizedBox(height: 20),
            customTextField("رقم الهاتف", TextInputType.phone),
            const SizedBox(height: 10),
            customTextField("تأكيد رقم الهاتف", TextInputType.phone),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(20)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("تعليمات قبل التبرع",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      "• تناول وجبة خفيفة\n• اشرب ماء كافٍ\n• احضر الهوية\n• العمر فوق 18"),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30))),
                onPressed: () => confirmDialog(context),
                child: const Text("تأكيد التبرع",
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void confirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد التبرع"),
        content: const Text("هل أنت متأكد من رغبتك بالتبرع؟"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("تأكيد")),
        ],
      ),
    );
  }

  Widget customTextField(String hint, TextInputType type) {
    return TextField(
      keyboardType: type,
      decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
    );
  }
}

class infoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const infoRow(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.red),
        const SizedBox(width: 8),
        Text(text)
      ]),
    );
  }
}
