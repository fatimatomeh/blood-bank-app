import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'city_helper.dart';
import 'donate_page.dart';
import 'requests_page.dart';
import 'signin_page.dart';

class DonorsHomePage extends StatefulWidget {
  const DonorsHomePage({super.key});

  @override
  _DonorsHomePageState createState() => _DonorsHomePageState();
}

class _DonorsHomePageState extends State<DonorsHomePage> {
  StreamSubscription? _requestsSubscription;
  Map<String, dynamic> urgentData = {};
  Map<String, dynamic> donorData = {};
  bool alreadyDonated = false;
  bool canDonate = true;
  int daysRemaining = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot =
        await FirebaseDatabase.instance.ref("Donors/${user.uid}").get();

    if (!snapshot.exists || snapshot.value == null) return;

    final profile = Map<String, dynamic>.from(snapshot.value as Map);
    final city = profile['city'];
    final bloodType = profile['bloodType'];

    setState(() {
      donorData = profile;
    });

    _checkDonationPeriod(profile);

    if (city == null) return;

    final donorCity = CityHelper.normalize(city.toString());
    final donorBlood = bloodType?.toString().trim() ?? "";

    // ✅ إلغاء الـ listener القديم
    await _requestsSubscription?.cancel();

    _requestsSubscription =
        FirebaseDatabase.instance.ref("Requests").onValue.listen((event) {
      final data = event.snapshot.value;

      if (data == null || data is! Map) {
        setState(() {
          urgentData = {};
          alreadyDonated = false;
        });
        return;
      }

      List<Map<String, dynamic>> matched = [];

      data.forEach((key, value) {
        final request = Map<String, dynamic>.from(value);
        final reqCity = CityHelper.normalize(request['city']?.toString());
        final reqBlood = request['bloodType']?.toString().trim() ?? "";

        if (reqCity == donorCity && reqBlood == donorBlood) {
          request['requestId'] = key;
          matched.add(request);
        }
      });

      if (matched.isEmpty) {
        setState(() {
          urgentData = {};
          alreadyDonated = false;
        });
        return;
      }

      // ✅ ترتيب من الأحدث
      matched.sort((a, b) {
        final aTime = a['createdAt'] ?? 0;
        final bTime = b['createdAt'] ?? 0;
        return (bTime as int).compareTo(aTime as int);
      });

      final newUrgent = matched.first;
      final newRid = newUrgent['requestId']?.toString() ?? "";

      // ✅ إعادة ضبط alreadyDonated أولاً قبل التحقق
      setState(() {
        urgentData = newUrgent;
        alreadyDonated = false;
      });

      if (newRid.isNotEmpty) _checkIfDonated(newRid);
    });
  }

  void _checkDonationPeriod(Map<String, dynamic> profile) {
    final lastDonationStr = profile['lastDonation']?.toString() ?? "";

    if (lastDonationStr.isEmpty || lastDonationStr == "غير محدد") {
      setState(() {
        canDonate = true;
        daysRemaining = 0;
      });
      return;
    }

    try {
      final parts = lastDonationStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final lastDate = DateTime(year, month, day);
        final now = DateTime.now();
        final diff = now.difference(lastDate).inDays;
        final remaining = 90 - diff;

        setState(() {
          canDonate = diff >= 90;
          daysRemaining = remaining > 0 ? remaining : 0;
        });
      }
    } catch (e) {
      setState(() {
        canDonate = true;
        daysRemaining = 0;
      });
    }
  }

  Future<void> _checkIfDonated(String requestId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseDatabase.instance
        .ref("Donors/${user.uid}/donations/$requestId")
        .get();

    if (mounted) {
      setState(() {
        alreadyDonated = snap.exists;
      });
    }
  }

  Future<void> _refreshAfterDonate() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap =
        await FirebaseDatabase.instance.ref("Donors/${user.uid}").get();

    if (snap.exists && snap.value is Map) {
      final profile = Map<String, dynamic>.from(snap.value as Map);
      setState(() => donorData = profile);
      _checkDonationPeriod(profile);
    }

    final rid = urgentData['requestId']?.toString() ?? "";
    if (rid.isNotEmpty) _checkIfDonated(rid);
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
  void dispose() {
    _requestsSubscription?.cancel();
    super.dispose();
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
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: _showLogoutDialog,
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

                        // ✅ تبرع لهذا الطلب مسبقاً
                        if (alreadyDonated)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  "لقد تبرعت لهذا الطلب ✅",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          )

                        // ✅ ما مضت 3 أشهر
                        else if (!canDonate)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Column(
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.timer, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text(
                                      "لا يمكنك التبرع الآن",
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "يجب الانتظار 3 أشهر بين كل تبرع\nباقي $daysRemaining يوم",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.orange, fontSize: 13),
                                ),
                              ],
                            ),
                          )

                        // ✅ يقدر يتبرع
                        else
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
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DonatePage(
                                      requestData: urgentData,
                                    ),
                                  ),
                                );
                                // ✅ تحديث بدون إعادة listener
                                _refreshAfterDonate();
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
