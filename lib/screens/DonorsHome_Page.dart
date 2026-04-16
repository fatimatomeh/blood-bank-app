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

  // ── حالة رفع صورة الفحص ──
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
      _testImageStatus = profile['bloodTestStatus']?.toString() ?? "";
    });

    _checkDonationPeriod(profile);
    _checkPeriodicBloodTest(profile);

    if (city == null) return;

    final donorCity = CityHelper.normalize(city.toString());
    final donorBlood = bloodType?.toString().trim() ?? "";

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
        final reqStatus = request['status']?.toString() ?? "";

        if (reqStatus == 'مغلق' ||
            reqStatus == 'ملغي' ||
            reqStatus == 'closed' ||
            reqStatus == 'cancelled') return;

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

      matched.sort((a, b) {
        final aTime = a['createdAt'] ?? 0;
        final bTime = b['createdAt'] ?? 0;
        return (bTime as int).compareTo(aTime as int);
      });

      final newUrgent = matched.first;
      final newRid = newUrgent['requestId']?.toString() ?? "";

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
        final remaining = 120 - diff;

        setState(() {
          canDonate = diff >= 120;
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

  void _checkPeriodicBloodTest(Map<String, dynamic> profile) {
    final checkStr =
        (profile['lastBloodTest'] ?? profile['lastDonation'])?.toString() ?? "";

    if (checkStr.isEmpty || checkStr == "غير محدد") {
      final createdAtStr = profile['createdAt']?.toString() ?? "";
      if (createdAtStr.isNotEmpty) {
        try {
          final createdAt = DateTime.parse(createdAtStr);
          final daysSince = DateTime.now().difference(createdAt).inDays;
          setState(() {
            _showPeriodicCheckBanner = daysSince >= 120;
            _daysSinceLastCheck = daysSince;
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
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final lastCheck = DateTime(year, month, day);
        final days = DateTime.now().difference(lastCheck).inDays;

        setState(() {
          _daysSinceLastCheck = days;
          _showPeriodicCheckBanner = days >= 120;
        });
      }
    } catch (_) {
      setState(() => _showPeriodicCheckBanner = false);
    }
  }

  bool get _isEligibleToDonate {
    if (!canDonate) return false;
    if (_testImageStatus == "معلق") return false;
    if (_showPeriodicCheckBanner && _testImageStatus != "مكتمل") return false;
    if (alreadyDonated) return false;
    return true;
  }

  String _nextDonationDate(String lastDonation) {
    try {
      final parts = lastDonation.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final last = DateTime(year, month, day);
        final next = last.add(const Duration(days: 120));
        return "${next.day}/${next.month}/${next.year}";
      }
    } catch (_) {}
    return "غير محدد";
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
      setState(() {
        donorData = profile;
        _testImageStatus = profile['bloodTestStatus']?.toString() ?? "";
      });
      _checkDonationPeriod(profile);
      _checkPeriodicBloodTest(profile);
    }

    final rid = urgentData['requestId']?.toString() ?? "";
    if (rid.isNotEmpty) _checkIfDonated(rid);
  }

  // ── رفع صورة الفحص الدوري عبر Supabase ──
  Future<void> _uploadBloodTestImage() async {
    User? user = FirebaseAuth.instance.currentUser;
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

      await supabase.storage.from('blood_tests').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final downloadUrl =
          supabase.storage.from('blood_tests').getPublicUrl(fileName);

      await FirebaseDatabase.instance.ref("Donors/${user.uid}").update({
        'bloodTestProofUrl': downloadUrl,
        'bloodTestStatus': 'معلق',
        'bloodTestSubmittedAt': dateStr,
      });

      setState(() {
        _testImageStatus = "معلق";
        _showPeriodicCheckBanner = false;
        donorData['bloodTestProofUrl'] = downloadUrl;
        donorData['bloodTestStatus'] = 'معلق';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ تم إرسال صورة الفحص، انتظر مراجعة موظف البنك"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ في الرفع: $e"),
            backgroundColor: Colors.red,
          ),
        );
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
        MaterialPageRoute(builder: (context) => const SignInPage()),
        (route) => false,
      );
    }
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

  void _showAlreadyDonatedDialog() {
    final String? lastDonation = donorData['lastDonation']?.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("لقد تبرعت لهذا الطلب ✅"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("شكراً لمساعدتك ❤️"),
            const SizedBox(height: 10),
            if (lastDonation != null) Text("📅 تاريخ التبرع: $lastDonation"),
            const SizedBox(height: 5),
            if (lastDonation != null)
              Text(
                "🩸 يمكنك التبرع مجدداً بتاريخ: ${_nextDonationDate(lastDonation)}",
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("حسناً"),
          ),
        ],
      ),
    );
  }

  void _showCannotDonateDialog() {
    final String? lastDonation = donorData['lastDonation']?.toString();
    final bool hasLastDonation = lastDonation != null &&
        lastDonation.isNotEmpty &&
        lastDonation != "غير محدد";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text("لا يمكنك التبرع الآن"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("يجب الانتظار 4 أشهر بين كل تبرع"),
            const SizedBox(height: 10),
            Text(
              "باقي $daysRemaining يوم",
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (hasLastDonation) ...[
              const SizedBox(height: 10),
              Text("📅 آخر تبرع: $lastDonation"),
              const SizedBox(height: 5),
              Text(
                "🩸 يمكنك التبرع بتاريخ: ${_nextDonationDate(lastDonation!)}",
                style: const TextStyle(color: Colors.green),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("حسناً"),
          ),
        ],
      ),
    );
  }

  void _showPendingTestDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_top, color: Colors.orange),
            SizedBox(width: 8),
            Text("الفحص قيد المراجعة"),
          ],
        ),
        content: const Text(
          "صورة فحصك الدوري لا تزال قيد المراجعة من موظف البنك.\n"
          "يرجى الانتظار حتى يتم قبول الفحص قبل التبرع.",
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("حسناً"),
          ),
        ],
      ),
    );
  }

  void _showNeedBloodTestDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.science_outlined, color: Colors.purple),
            SizedBox(width: 8),
            Text("فحص دوري مطلوب"),
          ],
        ),
        content: Text(
          _daysSinceLastCheck > 0
              ? "مرّ $_daysSinceLastCheck يوماً على آخر فحص دوري.\n"
                  "يجب رفع صورة فحص دم حديث ليراجعها موظف البنك قبل التبرع."
              : "يُشترط إجراء فحص دم دوري كل 4 أشهر.\n"
                  "يرجى رفع صورة نتيجة الفحص أولاً.",
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("لاحقاً"),
          ),
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
      MaterialPageRoute(
        builder: (context) => DonatePage(requestData: urgentData),
      ),
    ).then((_) => _refreshAfterDonate());
  }

  String _formatDateTime(dynamic ts) {
    if (ts == null) return "غير متوفر";
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts as int);
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      int hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      String period = "ص";
      if (hour >= 12) period = "م";
      hour = hour % 12;
      if (hour == 0) hour = 12;
      final hourStr = hour.toString().padLeft(2, '0');
      return "$day/$month/$year - $hourStr:$minute $period";
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
    final String? lastDonation = donorData['lastDonation']?.toString();

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

            // ── بانر الفحص الدوري ──
            if (_showPeriodicCheckBanner) ...[
              const SizedBox(height: 15),
              _buildBloodTestBanner(),
            ],

            // ── حالة الفحص المرفوع ──
            if (!_showPeriodicCheckBanner && _testImageStatus == "pending") ...[
              const SizedBox(height: 15),
              _buildTestStatusCard(
                color: Colors.orange,
                icon: Icons.hourglass_top,
                message:
                    "صورة فحصك قيد المراجعة من موظف البنك ⏳\nلا يمكنك التبرع حتى يتم القبول.",
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
                : AnimatedBuilder(
                    animation: _blinkAnimation,
                    builder: (context, child) {
                      return Opacity(
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
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bloodtype, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              "🚨 طلب دم عاجل",
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
                        if (urgentData['createdAt'] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            "📅 تاريخ الطلب: ${_formatDateTime(urgentData['createdAt'])}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
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
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _onDonateTap,
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

            // ── زر عرض جميع الطلبات ──
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

            // ── الإحصائيات ──
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

  // ── بانر الفحص الدوري ──
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
          Row(
            children: [
              const Icon(Icons.science_outlined,
                  color: Colors.purple, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "⏰ حان موعد فحصك الدوري!",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _daysSinceLastCheck == 0
                          ? "يُنصح بإجراء فحص دم دوري كل 4 أشهر قبل التبرع."
                          : "مرّ $_daysSinceLastCheck يوماً على آخر فحص.",
                      style: TextStyle(
                          fontSize: 13, color: Colors.purple.shade700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "⚠️ لا يمكنك التبرع قبل إتمام الفحص وقبوله.",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple.shade900,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
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
                  onPressed:
                      _isUploadingTestImage ? null : _uploadBloodTestImage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "ارفع صورة نتيجة فحص الدم ليراجعها موظف البنك ويؤكد أهليتك للتبرع.",
            style: TextStyle(fontSize: 11, color: Colors.purple),
          ),
        ],
      ),
    );
  }

  // ── بطاقة حالة الفحص ──
  Widget _buildTestStatusCard({
    required Color color,
    required IconData icon,
    required String message,
    bool showRetry = false,
  }) {
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
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          if (showRetry) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isUploadingTestImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  _isUploadingTestImage ? "جاري الرفع..." : "إعادة الرفع",
                  style: const TextStyle(color: Colors.white),
                ),
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
