import 'package:flutter/material.dart';
import 'donate_page.dart';

class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],

      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        title: const Text("طلبات التبرع"),
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          requestCard(
            context,
            "A+",
            "مستشفى النجاح",
            "نابلس",
            "قسم الطوارئ",
            "3",
            "قبل 20 دقيقة",
          ),

          const SizedBox(height: 20),

          requestCard(
            context,
            "O-",
            "مستشفى رفيديا",
            "نابلس",
            "قسم العمليات",
            "2",
            "قبل ساعة",
          ),
        ],
      ),
    );
  }

  Widget requestCard(
    BuildContext context,
    String blood,
    String hospital,
    String city,
    String department,
    String units,
    String time,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          )
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          Container(
            width: 70,
            height: 70,

            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),

            child: Center(
              child: Text(
                blood,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          Text(
            hospital,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text("📍 $city", textAlign: TextAlign.center),

          const SizedBox(height: 6),

          Text("🏥 $department", textAlign: TextAlign.center),

          const SizedBox(height: 12),

          Text("🩸 عدد الوحدات: $units", textAlign: TextAlign.center),

          const SizedBox(height: 6),

          Text("⏰ $time", textAlign: TextAlign.center),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,

            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),

              onPressed: () {

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DonatePage(),
                  ),
                );

              },

              child: const Text(
                "تبرع الآن",
                style: TextStyle(fontSize: 16),
              ),
            ),
          )
        ],
      ),
    );
  }
}