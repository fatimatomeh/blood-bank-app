import 'package:flutter/material.dart';

class DonatePage extends StatelessWidget {
  const DonatePage({super.key});

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
              child: const Column(
                children: [
                  infoRow(Icons.favorite, "فصيلة الدم: A+"),
                  infoRow(Icons.local_hospital, "مستشفى النجاح"),
                  infoRow(Icons.location_on, "نابلس"),
                  infoRow(Icons.medical_services, "قسم الطوارئ"),
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
              hint: const Text("9:00 صباحاً"),
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
