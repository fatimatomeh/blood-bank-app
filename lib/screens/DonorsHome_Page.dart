import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'donate_page.dart';
import 'requests_page.dart';
import 'signin_page.dart';

class DonorsHomePage extends StatefulWidget {
  const DonorsHomePage({super.key});

  @override
  _DonorsHomePageState createState() => _DonorsHomePageState();
}

class _DonorsHomePageState extends State<DonorsHomePage> {
  late DatabaseReference requestsRef;
  Map<String, dynamic> urgentData = {};
  Map<String, dynamic> donorData = {};

  // خريطة تحويل بين الإنجليزي والعربي
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

  String normalizeCity(String? city) {
    if (city == null) return "";
    return cityMap[city.toLowerCase()] ?? city;
  }

  @override
  void initState() {
    super.initState();

    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String uid = user.uid;

      DatabaseReference profileRef =
          FirebaseDatabase.instance.ref("Donors/$uid");

      profileRef.get().then((snapshot) {
        if (snapshot.exists && snapshot.value != null) {
          final profile = Map<String, dynamic>.from(snapshot.value as Map);
          final city = profile['city'];

          setState(() {
            donorData = profile;
          });

          if (city == null) {
            print("❌ City is null");
            return;
          }

          // قراءة كل الطلبات ومراقبة التغييرات
          requestsRef = FirebaseDatabase.instance.ref("Requests");

          requestsRef.onValue.listen((event) {
            final data = event.snapshot.value;

            if (data != null && data is Map) {
              bool found = false;

              data.forEach((key, value) {
                final request = Map<String, dynamic>.from(value);

                if (normalizeCity(request['city'].toString().trim()) ==
                    normalizeCity(city.toString().trim())) {
                  setState(() {
                    urgentData = request;
                  });
                  found = true;
                }
              });

              if (!found) {
                setState(() {
                  urgentData = {};
                });
              }
            } else {
              setState(() {
                urgentData = {};
              });
            }
          });
        }
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _showLogoutDialog();
          },
        ),
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
          children: [
            // رسالة الترحيب
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

            // --- قسم طلب الدم ---
            urgentData.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_turned_in_outlined,
                            color: Colors.green.shade400, size: 50),
                        const SizedBox(height: 15),
                        const Text(
                          "لا يوجد طلب حالي بمدينتك",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "شكراً لك، سنقوم بإشعارك عند وجود حالة طارئة قريبة منك",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : Container(
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
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "المستشفى: ${urgentData['hospitalName'] ?? 'غير محدد'}",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                        Text(
                          "الفصيلة المطلوبة: ${urgentData['bloodType'] ?? 'غير محدد'}",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                        Text(
                          "الوحدات المطلوبة: ${urgentData['units']?.toString() ?? '0'}",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DonatePage(requestData: urgentData),
                                ),
                              );
                            },
                            child: const Text(
                              "تبرع الآن",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RequestsPage(),
                    ),
                  );
                },
                child: const Text(
                  "عرض جميع الطلبات",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "إحصائياتك",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                statCard(
                  Icons.favorite,
                  donorData['donationCount']?.toString() ?? "0",
                  "عدد التبرعات",
                ),
                statCard(
                  Icons.calendar_today,
                  donorData['lastDonation'] ?? "غير محدد",
                  "آخر تبرع",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تسجيل الخروج"),
        content: const Text("هل أنت متأكد أنك تريد العودة لصفحة تسجيل الدخول؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text("تأكيد", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget statCard(IconData icon, String value, String label) {
    return Container(
      width: (MediaQuery.of(context).size.width / 2) - 30,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.red),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
