import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DonatePage extends StatefulWidget {
  final Map<String, dynamic>? requestData;

  const DonatePage({super.key, this.requestData});

  @override
  _DonatePageState createState() => _DonatePageState();
}

class _DonatePageState extends State<DonatePage> {
  List<Map<String, dynamic>> cityRequests = [];
  bool hasData = false;

  @override
  void initState() {
    super.initState();

    if (widget.requestData != null && widget.requestData!.isNotEmpty) {
      cityRequests = [widget.requestData!];
      hasData = true;
    } else {
      _loadCityRequests();
    }
  }
  String normalizeCity(String? city) {
    if (city == null) return "";

    city = city.toLowerCase().trim();

   Map<String, String> cityMap = {
    "ramallah": "رام الله",
    "al-bireh": "البيرة",
    "nablus": "نابلس",
    "hebron": "الخليل",
    "bethlehem": "بيت لحم",
    "jenin": "جنين",
    "tulkarm": "طولكرم",
    "qalqilya": "قلقيلية",
    "jericho": "أريحا",
    "salfit": "سلفيت",
    "tubas": "طوباس",
  };

    return cityMap[city] ?? city;
  }

  Future<void> _loadCityRequests() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DatabaseReference donorRef =
          FirebaseDatabase.instance.ref("Donors/${user.uid}");

      final snapshot = await donorRef.get();

      if (snapshot.exists && snapshot.value is Map) {
        final donorData = Map<String, dynamic>.from(snapshot.value as Map);

        final donorCity = normalizeCity(donorData['city']);
        final donorBlood = donorData['bloodType']?.toString().trim() ?? "";

        DatabaseReference requestsRef =
            FirebaseDatabase.instance.ref("Requests");

        final reqSnap = await requestsRef.get();

        if (reqSnap.exists && reqSnap.value is Map) {
          final requests = Map<String, dynamic>.from(reqSnap.value as Map);

          List<Map<String, dynamic>> temp = [];

          requests.forEach((key, value) {
            final request = Map<String, dynamic>.from(value);

            final reqCity = normalizeCity(request['city']);
            final reqBlood = request['bloodType']?.toString().trim() ?? "";

            if (reqCity == donorCity && reqBlood == donorBlood) {
              temp.add(request);
            }
          });

          setState(() {
            cityRequests = temp;
            hasData = temp.isNotEmpty;
          });
        }
      }
    } catch (e) {
      print("Error loading requests: $e");
    }
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
      body: !hasData
          ? _buildNoRequestWidget()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cityRequests.length,
              itemBuilder: (context, index) {
                final data = cityRequests[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        infoRow(Icons.favorite,
                            "فصيلة الدم: ${data['bloodType'] ?? 'غير محدد'}"),
                        infoRow(Icons.local_hospital,
                            data['hospitalName'] ?? "غير محدد"),
                        infoRow(Icons.location_on, data['city'] ?? "غير محدد"),
                        infoRow(Icons.medical_services,
                            data['department'] ?? "غير محدد"),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          hint: const Text("اختر وقت الوصول"),
                          items: const [
                            DropdownMenuItem(
                                value: "1", child: Text("خلال ساعة")),
                            DropdownMenuItem(
                                value: "2", child: Text("خلال ساعتين")),
                            DropdownMenuItem(
                                value: "3", child: Text("خلال 3 ساعات")),
                          ],
                          onChanged: (value) {},
                        ),
                        const SizedBox(height: 15),
                        customTextField("رقم الهاتف", TextInputType.phone),
                        const SizedBox(height: 10),
                        customTextField(
                            "تأكيد رقم الهاتف", TextInputType.phone),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("تعليمات قبل التبرع",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                  "• تناول وجبة خفيفة\n• اشرب ماء كافٍ\n• احضر الهوية الشخصية\n• يجب أن يكون العمر فوق 18 عاماً"),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
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
                            onPressed: () => confirmDialog(context),
                            child: const Text(
                              "تأكيد التبرع",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18),
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

  Widget _buildNoRequestWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            "لا يوجد طلب حالي بمدينتك",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "شكراً لروحك الطيبة، سنوافيك بكل جديد",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void confirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد التبرع"),
        content: const Text("هل أنت متأكد من رغبتك بالتبرع لهذا الطلب؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              User? user = FirebaseAuth.instance.currentUser;

              if (user != null) {
                DatabaseReference donorRef =
                    FirebaseDatabase.instance.ref("Donors/${user.uid}");

                final snapshot = await donorRef.get();

                if (snapshot.exists && snapshot.value is Map) {
                  final donorData =
                      Map<String, dynamic>.from(snapshot.value as Map);

                  int currentCount = int.tryParse(
                          donorData['donationCount']?.toString() ?? "0") ??
                      0;

                  await donorRef.update({
                    "donationCount": (currentCount + 1).toString(),
                    "lastDonation":
                        "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                  });
                }
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("تم تسجيل رغبتك بالتبرع بنجاح ✅")),
              );

              Navigator.pop(context);
            },
            child: const Text("تأكيد"),
          ),
        ],
      ),
    );
  }

  Widget customTextField(String hint, TextInputType type) {
    return TextField(
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
