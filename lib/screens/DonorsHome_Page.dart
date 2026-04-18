import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:image_picker/image_picker.dart';
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

class _DonorsHomePageState extends State<DonorsHomePage>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _requestsSubscription;

  Map<String, dynamic> urgentData = {};
  Map<String, dynamic> donorData = {};
  bool alreadyDonated = false;
  bool canDonate = true;
  int daysRemaining = 0;

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  bool _showPeriodicCheckBanner = false;
  int _daysSinceLastCheck = 0;

  bool _isUploadingTestImage = false;
  String _testImageStatus = "";

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _blinkAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _init();
  }

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseDatabase.instance.ref("Donors/${user.uid}").onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return;
      final profile = Map<String, dynamic>.from(event.snapshot.value as Map);
      setState(() {
        donorData = profile;
        _testImageStatus = profile['bloodTestStatus']?.toString() ?? "";
      });
      _checkDonationPeriod(profile);
      _checkPeriodicBloodTest(profile);
    });

    final snapshot =
        await FirebaseDatabase.instance.ref("Donors/${user.uid}").get();
    if (!snapshot.exists || snapshot.value == null) return;

    final profile = Map<String, dynamic>.from(snapshot.value as Map);
    final city = profile['city'];
    final bloodType = profile['bloodType'];

    setState(() {
      donorData = profile;
      _testImageStatus = profile['bloodTestStatus']?.toString() ?? "";
    });
    _checkDonationPeriod(profile);
    _checkPeriodicBloodTest(profile);

    if (city == null) return;
    final donorCity = CityHelper.normalize(city.toString());
    final donorBlood = bloodType?.toString().trim() ?? "";

    FirebaseDatabase.instance
        .ref("Donors/${user.uid}/donations")
        .onValue
        .listen((event) {
      _rebuildUrgent(user.uid, donorCity, donorBlood);
    });

    await _requestsSubscription?.cancel();
    _requestsSubscription =
        FirebaseDatabase.instance.ref("Requests").onValue.listen((event) {
      _rebuildUrgent(user.uid, donorCity, donorBlood);
    });
  }

  Future<void> _rebuildUrgent(
      String uid, String donorCity, String donorBlood) async {
    final reqSnap = await FirebaseDatabase.instance.ref("Requests").get();
    final donSnap =
        await FirebaseDatabase.instance.ref("Donors/$uid/donations").get();

    final Set<String> myDonations = {};
    if (donSnap.exists && donSnap.value is Map) {
      myDonations.addAll(Map<String, dynamic>.from(donSnap.value as Map).keys);
    }

    if (!reqSnap.exists || reqSnap.value is! Map) {
      if (mounted)
        setState(() {
          urgentData = {};
          alreadyDonated = false;
        });
      return;
    }

    List<Map<String, dynamic>> matched = [];
    Map<String, dynamic>.from(reqSnap.value as Map).forEach((key, value) {
      final req = Map<String, dynamic>.from(value);
      final reqCity = CityHelper.normalize(req['city']?.toString());
      final reqBlood = req['bloodType']?.toString().trim() ?? "";
      final status = req['status']?.toString() ?? "";

      if (reqCity == donorCity &&
          reqBlood == donorBlood &&
          (status == 'عاجل' || status == 'مفتوح' || status == 'بانتظار')) {
        req['requestId'] = key;
        matched.add(req);
      }
    });

    if (matched.isEmpty) {
      if (mounted)
        setState(() {
          urgentData = {};
          alreadyDonated = false;
        });
      return;
    }

    matched.sort((a, b) =>
        ((b['createdAt'] ?? 0) as int).compareTo((a['createdAt'] ?? 0) as int));

    Map<String, dynamic>? chosen;
    bool donated = false;

    for (final req in matched) {
      final rid = req['requestId']?.toString() ?? "";
      if (!myDonations.contains(rid)) {
        chosen = req;
        donated = false;
        break;
      }
    }

    if (chosen == null) {
      chosen = matched.first;
      donated = true;
    }

    if (mounted)
      setState(() {
        urgentData = chosen!;
        alreadyDonated = donated;
      });
  }

  void _checkDonationPeriod(Map<String, dynamic> profile) {
    final lastStr = profile['lastDonation']?.toString() ?? "";
    if (lastStr.isEmpty || lastStr == "غير محدد") {
      setState(() {
        canDonate = true;
        daysRemaining = 0;
      });
      return;
    }
    try {
      final parts = lastStr.split('/');
      if (parts.length == 3) {
        final last = DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        final diff = DateTime.now().difference(last).inDays;
        setState(() {
          canDonate = diff >= 120;
          daysRemaining = diff < 120 ? 120 - diff : 0;
        });
      }
    } catch (_) {
      setState(() {
        canDonate = true;
        daysRemaining = 0;
      });
    }
  }

  void _checkPeriodicBloodTest(Map<String, dynamic> profile) {
    final checkStr =
        (profile['lastBloodTest'] ?? profile['lastDonation'])?.toString() ?? "";
    if (checkStr.isEmpty || checkStr == "غير محدد") {
      final createdAtStr = profile['createdAt']?.toString() ?? "";
      if (createdAtStr.isNotEmpty) {
        try {
          final createdAt = DateTime.parse(createdAtStr);
          final days = DateTime.now().difference(createdAt).inDays;
          setState(() {
            _showPeriodicCheckBanner = days >= 120;
            _daysSinceLastCheck = days;
          });
          return;
        } catch (_) {}
      }
      setState(() => _showPeriodicCheckBanner = false);
      return;
    }
    try {
      final parts = checkStr.split('/');
      if (parts.length == 3) {
        final last = DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        final days = DateTime.now().difference(last).inDays;
        setState(() {
          _daysSinceLastCheck = days;
          _showPeriodicCheckBanner = days >= 120;
        });
      }
    } catch (_) {
      setState(() => _showPeriodicCheckBanner = false);
    }
  }

  String _nextDonationDate(String lastDonation) {
    try {
      final p = lastDonation.split('/');
      if (p.length == 3) {
        final last =
            DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
        final next = last.add(const Duration(days: 120));
        return "${next.day}/${next.month}/${next.year}";
      }
    } catch (_) {}
    return "غير محدد";
  }

  Future<void> _uploadBloodTestImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _isUploadingTestImage = true);
    try {
      final now = DateTime.now();
      final dateStr = "${now.day}/${now.month}/${now.year}";
      final bytes = await picked.readAsBytes();
      final fileName = "${user.uid}/${now.millisecondsSinceEpoch}.jpg";
      final supabase = Supabase.instance.client;
      await supabase.storage.from('blood_tests').uploadBinary(fileName, bytes,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true));
      final downloadUrl =
          supabase.storage.from('blood_tests').getPublicUrl(fileName);

      // ── جيب hospitalId من الطلب العاجل الحالي إن وجد ──
      final testHospitalId = urgentData['hospitalId']?.toString() ?? "";

      await FirebaseDatabase.instance.ref("Donors/${user.uid}").update({
        'bloodTestProofUrl': downloadUrl,
        'bloodTestStatus': 'معلق',
        'bloodTestSubmittedAt': dateStr,
        // إذا في طلب محدد احفظ المستشفى، وإلا ما تحفظ شي
        if (testHospitalId.isNotEmpty) 'bloodTestHospitalId': testHospitalId,
      });

      setState(() {
        _testImageStatus = "معلق";
        _showPeriodicCheckBanner = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("✅ تم إرسال صورة الفحص، انتظر مراجعة موظف البنك"),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploadingTestImage = false);
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SignInPage()),
          (route) => false);
    }
  }

  void _onDonateTap() {
    if (alreadyDonated) {
      _showAlreadyDonatedDialog();
      return;
    }
    if (!canDonate) {
      _showCannotDonateDialog();
      return;
    }
    if (_testImageStatus == "معلق") {
      _showPendingTestDialog();
      return;
    }
    if (_showPeriodicCheckBanner && _testImageStatus != "مكتمل") {
      _showNeedBloodTestDialog();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DonatePage(requestData: urgentData)),
    );
  }

  void _showAlreadyDonatedDialog() {
    final lastDonation = donorData['lastDonation']?.toString();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("لقد تبرعت لهذا الطلب ✅"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("شكراً لمساعدتك ❤️"),
          if (lastDonation != null) ...[
            const SizedBox(height: 10),
            Text("📅 تاريخ التبرع: $lastDonation"),
            Text("🩸 يمكنك التبرع مجدداً: ${_nextDonationDate(lastDonation)}"),
          ],
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("حسناً"))
        ],
      ),
    );
  }

  void _showCannotDonateDialog() {
    final lastDonation = donorData['lastDonation']?.toString();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text("لا يمكنك التبرع الآن"),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("يجب الانتظار 4 أشهر بين كل تبرع"),
          const SizedBox(height: 10),
          Text("باقي $daysRemaining يوم",
              style: const TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.bold)),
          if (lastDonation != null && lastDonation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text("📅 آخر تبرع: $lastDonation"),
            Text("🩸 يمكنك التبرع: ${_nextDonationDate(lastDonation)}",
                style: const TextStyle(color: Colors.green)),
          ],
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("حسناً"))
        ],
      ),
    );
  }

  void _showPendingTestDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.hourglass_top, color: Colors.orange),
          SizedBox(width: 8),
          Text("الفحص قيد المراجعة"),
        ]),
        content: const Text(
            "صورة فحصك الدوري لا تزال قيد المراجعة.\nيرجى الانتظار حتى القبول."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("حسناً"))
        ],
      ),
    );
  }

  void _showNeedBloodTestDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.science_outlined, color: Colors.purple),
          SizedBox(width: 8),
          Text("فحص دوري مطلوب"),
        ]),
        content: Text(_daysSinceLastCheck > 0
            ? "مرّ $_daysSinceLastCheck يوماً على آخر فحص.\nيجب رفع صورة فحص."
            : "يُشترط إجراء فحص دم كل 4 أشهر قبل التبرع."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("لاحقاً")),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            icon: const Icon(Icons.upload_file, color: Colors.white),
            label:
                const Text("رفع الآن", style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context);
              _uploadBloodTestImage();
            },
          ),
        ],
      ),
    );
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

  String _formatDateTime(dynamic ts) {
    if (ts == null) return "غير متوفر";
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts as int);
      int h = dt.hour;
      final p = h >= 12 ? "م" : "ص";
      h = h % 12;
      if (h == 0) h = 12;
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}"
          " - ${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $p";
    } catch (_) {
      return "غير متوفر";
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _requestsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: _showLogoutDialog,
        ),
        title: Text("VivaLink",
            style: GoogleFonts.atma(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── بانر الترحيب ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.waving_hand, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "أهلاً ${donorData['fullName'] ?? ''} ! تبرعك قد ينقذ حياة",
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            if (_showPeriodicCheckBanner) ...[
              const SizedBox(height: 15),
              _buildBloodTestBanner(),
            ],

            if (!_showPeriodicCheckBanner && _testImageStatus == "معلق") ...[
              const SizedBox(height: 15),
              _buildTestStatusCard(
                color: Colors.orange,
                icon: Icons.hourglass_top,
                message:
                    "صورة فحصك قيد المراجعة من موظف البنك ⏳\nلا يمكنك التبرع حتى القبول.",
              ),
            ] else if (!_showPeriodicCheckBanner &&
                _testImageStatus == "مرفوض") ...[
              const SizedBox(height: 15),
              _buildTestStatusCard(
                color: Colors.red,
                icon: Icons.cancel,
                message: "تم رفض صورة فحصك. يرجى إعادة الرفع بصورة أوضح.",
                showRetry: true,
              ),
            ],

            const SizedBox(height: 20),

            // ── بطاقة الطلب العاجل ──
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
                        const Text("لا يوجد طلب مفتوح بمدينتك",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        const SizedBox(height: 8),
                        Text("شكراً لك، سنوافيك بكل جديد",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : AnimatedBuilder(
                    animation: _blinkAnimation,
                    builder: (context, child) => Opacity(
                      opacity: _blinkAnimation.value,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.red.withOpacity(0.7),
                                blurRadius: 20,
                                spreadRadius: 4)
                          ],
                        ),
                        child: child,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bloodtype, color: Colors.white),
                            SizedBox(width: 8),
                            Text("🚨 طلب دم عاجل",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text("المستشفى: ${urgentData['hospitalName'] ?? '-'}",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                        Text("الفصيلة: ${urgentData['bloodType'] ?? '-'}",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                        Text("الوحدات: ${urgentData['units'] ?? '-'}",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                        if (urgentData['createdAt'] != null) ...[
                          const SizedBox(height: 6),
                          Text("📅 ${_formatDateTime(urgentData['createdAt'])}",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
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
                            onPressed: _onDonateTap,
                            child: Text(
                              alreadyDonated
                                  ? "تبرعت لهذا الطلب ✅"
                                  : "تبرع الآن",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
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
                      borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RequestsPage())),
                child: const Text("عرض جميع الطلبات",
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 30),
            const Text("إحصائياتك",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                    child: statCard(
                        Icons.favorite,
                        donorData['donationCount']?.toString() ?? "0",
                        "عدد التبرعات")),
                const SizedBox(width: 10),
                Expanded(
                    child: statCard(Icons.calendar_today,
                        donorData['lastDonation'] ?? "غير محدد", "آخر تبرع")),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodTestBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purple.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.science_outlined, color: Colors.purple, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("⏰ حان موعد فحصك الدوري!",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.purple)),
                  const SizedBox(height: 4),
                  Text(
                    _daysSinceLastCheck == 0
                        ? "يُنصح بإجراء فحص كل 4 أشهر."
                        : "مرّ $_daysSinceLastCheck يوماً على آخر فحص.",
                    style:
                        TextStyle(fontSize: 13, color: Colors.purple.shade700),
                  ),
                  Text("⚠️ لا يمكنك التبرع قبل إتمام الفحص وقبوله.",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple.shade900,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isUploadingTestImage
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.upload_file, color: Colors.white),
              label: Text(
                _isUploadingTestImage ? "جاري الرفع..." : "رفع صورة الفحص",
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              onPressed: _isUploadingTestImage ? null : _uploadBloodTestImage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestStatusCard(
      {required Color color,
      required IconData icon,
      required String message,
      bool showRetry = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Row(children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ]),
          if (showRetry) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                icon: _isUploadingTestImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                    _isUploadingTestImage ? "جاري الرفع..." : "إعادة الرفع",
                    style: const TextStyle(color: Colors.white)),
                onPressed: _isUploadingTestImage ? null : _uploadBloodTestImage,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget statCard(IconData icon, String value, String label) {
    return Container(
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
