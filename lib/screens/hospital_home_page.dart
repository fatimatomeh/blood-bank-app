import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'hospital_donors_page.dart';
import 'hospital_create_request_page.dart';
import 'signin_page.dart';
import 'city_helper.dart';

class HospitalHomePage extends StatefulWidget {
  const HospitalHomePage({super.key});

  @override
  State<HospitalHomePage> createState() => _HospitalHomePageState();
}

class _HospitalHomePageState extends State<HospitalHomePage> {
  Map<String, dynamic> hospitalData = {};
  int totalRequests = 0;
  int openRequests = 0;
  int totalDonors = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ── جلب بيانات المستشفى ──────────────────────────────────────
    final hospSnap =
        await FirebaseDatabase.instance.ref("Hospitals/${user.uid}").get();

    if (hospSnap.exists && hospSnap.value is Map) {
      hospitalData = Map<String, dynamic>.from(hospSnap.value as Map);
    }

    final hospitalName = hospitalData['name']?.toString().trim() ?? "";
    // المدينة ممكن إنجليزي (Nablus) → نحولها عربي للمقارنة مع الدونورز
    final hospitalCityAr =
        CityHelper.normalize(hospitalData['city']?.toString());

    // ── طلبات المستشفى (مطابقة بالاسم) ──────────────────────────
    final reqSnap = await FirebaseDatabase.instance.ref("Requests").get();

    int total = 0;
    int open = 0;

    if (reqSnap.exists && reqSnap.value is Map) {
      final requests = Map<String, dynamic>.from(reqSnap.value as Map);
      requests.forEach((key, value) {
        final req = Map<String, dynamic>.from(value);
        // ✅ نطابق بـ hospitalId أولاً، لو مش موجود نرجع للمدينة للطلبات القديمة
        final byId = req['hospitalId']?.toString() == user.uid;
        final byCity =
            CityHelper.normalize(req['city']?.toString()) == hospitalCityAr;
        if (byId || (!req.containsKey('hospitalId') && byCity)) {
          total++;
          final status = req['status']?.toString() ?? "";
          if (status == "عاجل" || status == "open") open++;
        }
      });
    }

    // ── عدد المتبرعين في نفس المدينة ─────────────────────────────
    final donorsSnap = await FirebaseDatabase.instance.ref("Donors").get();

    int donorsCount = 0;

    if (donorsSnap.exists && donorsSnap.value is Map) {
      final donors = Map<String, dynamic>.from(donorsSnap.value as Map);
      donors.forEach((key, value) {
        final donor = Map<String, dynamic>.from(value);
        // مدينة المتبرع ممكن عربي → نوحدها ونقارن
        final donorCityAr = CityHelper.normalize(donor['city']?.toString());
        if (donorCityAr == hospitalCityAr) donorsCount++;
      });
    }

    setState(() {
      totalRequests = total;
      openRequests = open;
      totalDonors = donorsCount;
    });
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

  @override
  Widget build(BuildContext context) {
    // عرض اسم المدينة بالعربي دايماً
    final cityDisplay = CityHelper.normalize(hospitalData['city']?.toString());

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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // بطاقة المستشفى
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
                      hospitalData['name'] ?? "جاري التحميل...",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          cityDisplay,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              const Text("نظرة عامة",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      Icons.list_alt,
                      "$totalRequests",
                      "إجمالي الطلبات",
                      Colors.blue.shade50,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      Icons.warning_amber,
                      "$openRequests",
                      "طلبات مفتوحة",
                      Colors.orange.shade50,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _statCard(
                Icons.people,
                "$totalDonors",
                "متبرعون في مدينتك",
                Colors.green.shade50,
                Colors.green,
                fullWidth: true,
              ),

              const SizedBox(height: 25),

              const Text("الوصول السريع",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: _quickButton(
                      Icons.add_circle_outline,
                      "إنشاء طلب",
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HospitalCreateRequestPage(
                              hospitalData: hospitalData,
                            ),
                          ),
                        );
                        _loadData();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _quickButton(
                      Icons.people_outline,
                      "المتبرعون",
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HospitalDonorsPage(),
                        ),
                      ),
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

  Widget _statCard(
    IconData icon,
    String value,
    String label,
    Color bgColor,
    Color iconColor, {
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 30),
          const SizedBox(width: 12),
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
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.red, size: 30),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تسجيل الخروج"),
        content: const Text("هل أنت متأكد أنك تريد تسجيل الخروج؟"),
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
}
