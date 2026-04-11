import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'city_helper.dart';
import 'signin_page.dart';

class BloodBankHomePage extends StatefulWidget {
  const BloodBankHomePage({super.key});

  @override
  State<BloodBankHomePage> createState() => _BloodBankHomePageState();
}

class _BloodBankHomePageState extends State<BloodBankHomePage> {
  Map<String, dynamic> staffData = {};
  int totalDonors = 0;
  int pendingTests = 0;
  int todayDonors = 0;
  int openRequests = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // بيانات الموظف
    final staffSnap =
        await FirebaseDatabase.instance.ref("BloodBankStaff/$uid").get();
    if (staffSnap.exists && staffSnap.value is Map) {
      staffData = Map<String, dynamic>.from(staffSnap.value as Map);
    }

    // جلب اسم المستشفى من جدول Hospitals
    final hospitalId = staffData['hospitalId']?.toString() ?? "";
    if (hospitalId.isNotEmpty) {
      final hospSnap =
          await FirebaseDatabase.instance.ref("Hospitals/$hospitalId").get();
      if (hospSnap.exists && hospSnap.value is Map) {
        final hospData = Map<String, dynamic>.from(hospSnap.value as Map);
        staffData['hospitalName'] = hospData['hospitalName']?.toString() ?? "";
      }
    }

    final staffCity = CityHelper.normalize(staffData['city']?.toString());
    final today = _todayStr();

    // إحصاء المتبرعين والفحوصات
    final donorsSnap = await FirebaseDatabase.instance.ref("Donors").get();
    int donors = 0;
    int pending = 0;
    int todayCount = 0;

    if (donorsSnap.exists && donorsSnap.value is Map) {
      final map = Map<String, dynamic>.from(donorsSnap.value as Map);
      map.forEach((key, value) {
        final d = Map<String, dynamic>.from(value);
        final city = CityHelper.normalize(d['city']?.toString());
        if (city != staffCity) return;

        donors++;

        final status = d['bloodTestStatus']?.toString() ?? "";
        if (status == "pending") pending++;

        final lastDon = d['lastDonation']?.toString() ?? "";
        if (lastDon == today) todayCount++;
      });
    }

    // إحصاء الطلبات المفتوحة — بس طلبات مستشفى الموظف
    final reqSnap = await FirebaseDatabase.instance.ref("Requests").get();
    int openReq = 0;

    if (reqSnap.exists && reqSnap.value is Map) {
      final map = Map<String, dynamic>.from(reqSnap.value as Map);
      map.forEach((key, value) {
        final r = Map<String, dynamic>.from(value);
        final status = r['status']?.toString() ?? "";
        if (r['hospitalId']?.toString() == hospitalId &&
            (status == "عاجل" || status == "open")) {
          openReq++;
        }
      });
    }

    setState(() {
      totalDonors = donors;
      pendingTests = pending;
      todayDonors = todayCount;
      openRequests = openReq;
      isLoading = false;
    });
  }

  String _todayStr() {
    final now = DateTime.now();
    return "${now.day}/${now.month}/${now.year}";
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SignInPage()),
        (route) => false,
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تسجيل الخروج"),
        content: const Text("هل أنت متأكد؟"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء")),
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

  @override
  Widget build(BuildContext context) {
    final cityDisplay = CityHelper.normalize(staffData['city']?.toString());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        automaticallyImplyLeading: false,
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── بطاقة الترحيب ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.local_hospital,
                              color: Colors.white, size: 40),
                          const SizedBox(height: 10),
                          Text(
                            "أهلاً ${staffData['name'] ?? ''}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "موظف بنك الدم — $cityDisplay",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 15),
                          ),
                          if (staffData['hospitalName'] != null)
                            Text(
                              "🏥 ${staffData['hospitalName']}",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // ── تنبيه الفحوصات المعلّقة ──
                    if (pendingTests > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color: Colors.orange.shade300, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.science_outlined,
                                color: Colors.orange, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "يوجد $pendingTests فحص دم بانتظار مراجعتك!",
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Text(
                      "نظرة عامة",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),

                    // ── الإحصاءات ──
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            Icons.people,
                            "$totalDonors",
                            "متبرعو المدينة",
                            Colors.blue.shade50,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            Icons.science_outlined,
                            "$pendingTests",
                            "فحوص معلّقة",
                            Colors.orange.shade50,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            Icons.today,
                            "$todayDonors",
                            "تبرعوا اليوم",
                            Colors.green.shade50,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            Icons.warning_amber,
                            "$openRequests",
                            "طلبات مفتوحة",
                            Colors.red.shade50,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color bgColor,
      Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}
