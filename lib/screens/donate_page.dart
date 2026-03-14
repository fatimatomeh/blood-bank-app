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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.favorite, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        "فصيلة الدم: A+",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),

                  SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.local_hospital, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        "اسم المستشفى: مستشفى النجاح",
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.location_on, color: Colors.red),
                      SizedBox(width: 8),
                      Text("الموقع: نابلس", textAlign: TextAlign.center),
                    ],
                  ),

                  SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.medical_services, color: Colors.red),
                      SizedBox(width: 8),
                      Text("القسم: قسم الطوارئ", textAlign: TextAlign.center),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            const Text(
              "وقت الوصول المتوقع",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              hint: const Text("9:00 صباحاً"),
              items: const [
                DropdownMenuItem(value: "9", child: Text("9:00 صباحاً")),
                DropdownMenuItem(value: "10", child: Text("10:00 صباحاً")),
                DropdownMenuItem(value: "11", child: Text("11:00 صباحاً")),
              ],
              onChanged: (value) {},
            ),

            const SizedBox(height: 20),

            const Text(
              "رقم الهاتف",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            TextField(
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "رقم الهاتف",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "تأكيد رقم الهاتف",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 25),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 248, 130, 130),
                borderRadius: BorderRadius.circular(20),
              ),

              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "تعليمات قبل التبرع",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 10),

                  Text("• تناول وجبة خفيفة"),
                  Text("• اشرب كمية كافية من الماء"),
                  Text("• احضر الهوية الشخصية"),
                  Text("• يجب أن يكون عمرك أكثر من 18 سنة"),
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
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),

                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("تأكيد التبرع"),
                      content: const Text("هل أنت متأكد من رغبتك بالتبرع؟"),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text("إلغاء"),
                        ),

                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text("تأكيد"),
                        ),
                      ],
                    ),
                  );
                },

                child: const Text(
                  "تأكيد التبرع",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
