import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:math';
import 'city_helper.dart';
import 'donate_page.dart';
import 'requests_page.dart';
import 'signin_page.dart';
import 'donation_timer_service.dart';

class DonorsHomePage extends StatefulWidget {
  const DonorsHomePage({super.key});

  @override
  _DonorsHomePageState createState() => _DonorsHomePageState();
}

class _DonorsHomePageState extends State<DonorsHomePage>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _requestsSubscription;
  StreamSubscription? _timerSubscription;
  Timer? _localTicker;

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

  // ── مؤقت التبرع ──
  Map<String, dynamic>? _activeTimer;
  int _remainingSeconds = 0;

  String _generateRefNumber() {
    final now = DateTime.now();
    final rand = Random();
    final part1 = (1000 + rand.nextInt(9000)).toString();
    final part2 = (1000 + rand.nextInt(9000)).toString();
    return "REF-${now.year}-$part1-$part2";
  }

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
    _listenToTimer();
  }

  // ── الاستماع للمؤقت من Firebase - يضل شغّال حتى لو غيّر الصفحة ──
  void _listenToTimer() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _timerSubscription = FirebaseDatabase.instance
        .ref("Donors/$uid/activeTimer")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        if (mounted) {
          setState(() {
            _activeTimer = null;
            _remainingSeconds = 0;
          });
        }
        _localTicker?.cancel();
        return;
      }

      final data =
          Map<String, dynamic>.from(event.snapshot.value as Map);
      final status = data['status']?.toString() ?? '';
      final remaining = DonationTimerService.getRemainingSeconds(data);

      if (mounted) {
        setState(() {
          _activeTimer = data;
          _remainingSeconds = remaining;
        });
      }

      if (status == 'في الطريق') {
        if (remaining > 0) {
          _startLocalTicker(uid, data);
        } else {
          // الوقت انتهى → غيّر الحالة لقيد الوصول (ينتظر الموظف)
          _localTicker?.cancel();
          DonationTimerService.markAsArriving(uid);
        }
      } else {
        // قيد الوصول أو تم التبرع → وقّف التيك المحلي
        _localTicker?.cancel();
      }
    });
  }

  void _startLocalTicker(String uid, Map<String, dynamic> timerData) {
    _localTicker?.cancel();
    _localTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = DonationTimerService.getRemainingSeconds(timerData);
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remainingSeconds = remaining);
      if (remaining <= 0) {
        t.cancel();
        DonationTimerService.markAsArriving(uid);
      }
    });
  }

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseDatabase.instance
        .ref("Donors/${user.uid}")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return;
      final profile =
          Map<String, dynamic>.from(event.snapshot.value as Map);
      if (mounted) {
        setState(() {
          donorData = profile;
          _testImageStatus = profile['bloodTestStatus']?.toString() ?? "";
        });
      }
      _checkDonationPeriod(profile);
      _checkPeriodicBloodTest(profile);
    });

    final snapshot =
        await FirebaseDatabase.instance.ref("Donors/${user.uid}").get();
    if (!snapshot.exists || snapshot.value == null) return;

    final profile =
        Map<String, dynamic>.from(snapshot.value as Map);
    final city = profile['city'];
    final bloodType = profile['bloodType'];

    if (mounted) {
      setState(() {
        donorData = profile;
        _testImageStatus = profile['bloodTestStatus']?.toString() ?? "";
      });
    }
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
    _requestsSubscription = FirebaseDatabase.instance
        .ref("Requests")
        .onValue
        .listen((event) {
      _rebuildUrgent(user.uid, donorCity, donorBlood);
    });
  }

  Future<void> _rebuildUrgent(
      String uid, String donorCity, String donorBlood) async {
    final reqSnap =
        await FirebaseDatabase.instance.ref("Requests").get();
    final donSnap = await FirebaseDatabase.instance
        .ref("Donors/$uid/donations")
        .get();

    final Set<String> myDonations = {};
    if (donSnap.exists && donSnap.value is Map) {
      myDonations
          .addAll(Map<String, dynamic>.from(donSnap.value as Map).keys);
    }

    if (!reqSnap.exists || reqSnap.value is! Map) {
      if (mounted) {
        setState(() {
          urgentData = {};
          alreadyDonated = false;
        });
      }
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
      if (mounted) {
        setState(() {
          urgentData = {};
          alreadyDonated = false;
        });
      }
      return;
    }

    matched.sort((a, b) => ((b['createdAt'] ?? 0) as int)
        .compareTo((a['createdAt'] ?? 0) as int));

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

    if (mounted) {
      setState(() {
        urgentData = chosen!;
        alreadyDonated = donated;
      });
    }
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
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
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
        (profile['lastBloodTest'] ?? profile['lastDonation'])?.toString() ??
            "";
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
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
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
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _isUploadingTestImage = true);
    try {
      final now = DateTime.now();
      final dateStr = "${now.day}/${now.month}/${now.year}";
      final bytes = await picked.readAsBytes();
      final fileName = "${user.uid}/${now.millisecondsSinceEpoch}.jpg";
      final supabase = Supabase.instance.client;
      await supabase.storage.from('blood_tests').uploadBinary(
          fileName, bytes,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true));
      final downloadUrl =
          supabase.storage.from('blood_tests').getPublicUrl(fileName);

      final refNumber = _generateRefNumber();
      final testHospitalId = urgentData['hospitalId']?.toString() ?? "";

      await FirebaseDatabase.instance.ref("Donors/${user.uid}").update({
        'bloodTestProofUrl': downloadUrl,
        'bloodTestStatus': 'معلق',
        'bloodTestSubmittedAt': dateStr,
        'bloodTestRefNumber': refNumber,
        if (testHospitalId.isNotEmpty) 'bloodTestHospitalId': testHospitalId,
      });

      if (testHospitalId.isNotEmpty) {
        final donorName = donorData['fullName']?.toString() ?? "متبرع";
        await FirebaseDatabase.instance
            .ref("Notifications/$testHospitalId")
            .push()
            .set({
          'title': "فحص دم جديد 🔬",
          'message':
              "$donorName رفع صورة فحصه الدوري بتاريخ $dateStr. رقم الريفرنس: $refNumber",
          'type': "new_test",
          'donorId': user.uid,
          'refNumber': refNumber,
          'isRead': false,
          'createdAt': ServerValue.timestamp,
        });
      }

      setState(() {
        _testImageStatus = "معلق";
        _showPeriodicCheckBanner = false;
      });

      if (mounted) _showRefNumberDialog(refNumber);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploadingTestImage = false);
    }
  }

  void _showRefNumberDialog(String refNumber) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green, size: 28),
          SizedBox(width: 10),
          Text("تم إرسال الفحص ✅",
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "تم إرسال صورة الفحص بنجاح!\nاحتفظ برقم الريفرنس التالي:",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.indigo.shade300, width: 2),
              ),
              child: Column(
                children: [
                  const Text("رقم الريفرنس",
                      style: TextStyle(
                          color: Colors.indigo,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(refNumber,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "⚠️ يمكن لوزارة الصحة والمستشفى التحقق من هذا الرقم. احتفظ به.",
                style: TextStyle(color: Colors.orange, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("حسناً",
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    _localTicker?.cancel();
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
      MaterialPageRoute(
          builder: (_) => DonatePage(requestData: urgentData)),
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
            Text(
                "🩸 يمكنك التبرع مجدداً: ${_nextDonationDate(lastDonation)}"),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15)),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple),
            icon: const Icon(Icons.upload_file, color: Colors.white),
            label: const Text("رفع الآن",
                style: TextStyle(color: Colors.white)),
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
            child:
                const Text("تأكيد", style: TextStyle(color: Colors.red)),
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
    _timerSubscription?.cancel();
    _localTicker?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // ── بانر المؤقت النشط (يضل ظاهر في كل الصفحات) ──
  // ─────────────────────────────────────────────
  Widget _buildActiveTimerBanner() {
    if (_activeTimer == null) return const SizedBox.shrink();

    final status = _activeTimer!['status']?.toString() ?? '';
    final hospitalName =
        _activeTimer!['hospitalName']?.toString() ?? 'المستشفى';

    // ── في الطريق: العداد شغّال ──
    if (status == 'في الطريق') {
      final totalSeconds =
          _activeTimer!['durationSeconds'] as int? ?? 900;
      final pct = totalSeconds > 0 ? _remainingSeconds / totalSeconds : 0.0;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade700, Colors.red.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.red.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_walk,
                    color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text("في الطريق إلى $hospitalName",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    strokeWidth: 7,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DonationTimerService.formatTime(_remainingSeconds),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace'),
                    ),
                    const Text("متبقي",
                        style: TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "⏳ توجّه إلى المستشفى قبل انتهاء الوقت",
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // ── قيد الوصول: الوقت انتهى، ينتظر تأكيد الموظف ──
    if (status == 'قيد الوصول') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.green.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.local_hospital,
                color: Colors.white, size: 36),
            const SizedBox(height: 10),
            const Text(
              "🏥 اتجه الآن إلى المستشفى",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _instructionRow(
                      "🪪", "أحضر هويتك الشخصية أو بطاقة التبرع"),
                  const SizedBox(height: 6),
                  _instructionRow(
                      "🍽️", "تأكد أنك أكلت جيداً وشربت ماء كافياً"),
                  const SizedBox(height: 6),
                  _instructionRow(
                      "👕", "ارتدِ ملابس مريحة وذراع قابلة للكشف"),
                  const SizedBox(height: 6),
                  _instructionRow("🏥",
                      "توجّه مباشرة إلى قسم التبرع في $hospitalName"),
                  const SizedBox(height: 6),
                  _instructionRow(
                      "📢", "أبلغ موظف البنك باسمك وأنك قادم للتبرع"),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "⏳ في انتظار تأكيد موظف البنك...",
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    // ── تم التبرع: أكّد الموظف ──
    if (status == 'تم التبرع') {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade600, Colors.teal.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            const Icon(Icons.volunteer_activism,
                color: Colors.white, size: 50),
            const SizedBox(height: 12),
            const Text(
              "✅ تم التبرع بنجاح!",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "شكراً لك ❤️\nتبرعك قد ينقذ حياة",
              style: TextStyle(color: Colors.white70, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.teal,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 30, vertical: 12),
              ),
              onPressed: () => DonationTimerService.clearTimer(uid),
              child: const Text("إغلاق",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _instructionRow(String emoji, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style:
                  const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveTimer = _activeTimer != null;

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

            // ── بانر المؤقت (يضل ظاهر دائماً لو في مؤقت نشط) ──
            if (hasActiveTimer) ...[
              const SizedBox(height: 15),
              _buildActiveTimerBanner(),
            ],

            // ── بانرات الفحص (تظهر فقط لو ما في مؤقت نشط) ──
            if (!hasActiveTimer) ...[
              if (_showPeriodicCheckBanner) ...[
                const SizedBox(height: 15),
                _buildBloodTestBanner(),
              ],
              if (!_showPeriodicCheckBanner &&
                  _testImageStatus == "معلق") ...[
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
                  message:
                      "تم رفض صورة فحصك. يرجى إعادة الرفع بصورة أوضح.",
                  showRetry: true,
                ),
              ],
            ],

            const SizedBox(height: 20),

            // ── بطاقة الطلب العاجل + زر عرض الكل (يختفيان لو في مؤقت نشط) ──
            if (!hasActiveTimer) ...[
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
                                  fontSize: 14,
                                  color: Colors.grey.shade600)),
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
                            border: Border.all(
                                color: Colors.white, width: 3),
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
                              Icon(Icons.bloodtype,
                                  color: Colors.white),
                              SizedBox(width: 8),
                              Text("🚨 طلب دم عاجل",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text(
                              "المستشفى: ${urgentData['hospitalName'] ?? '-'}",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16)),
                          Text(
                              "الفصيلة: ${urgentData['bloodType'] ?? '-'}",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16)),
                          Text(
                              "الوحدات: ${urgentData['units'] ?? '-'}",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16)),
                          if (urgentData['createdAt'] != null) ...[
                            const SizedBox(height: 6),
                            Text(
                                "📅 ${_formatDateTime(urgentData['createdAt'])}",
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13)),
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
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              onPressed: _onDonateTap,
                              child: Text(
                                alreadyDonated
                                    ? "تبرعت لهذا الطلب ✅"
                                    : "تبرع الآن",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
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
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RequestsPage())),
                  child: const Text("عرض جميع الطلبات",
                      style: TextStyle(
                          fontSize: 18, color: Colors.white)),
                ),
              ),
            ],

            const SizedBox(height: 30),
            const Text("إحصائياتك",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
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
                    child: statCard(
                        Icons.calendar_today,
                        donorData['lastDonation'] ?? "غير محدد",
                        "آخر تبرع")),
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
            const Icon(Icons.science_outlined,
                color: Colors.purple, size: 28),
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
                    style: TextStyle(
                        fontSize: 13, color: Colors.purple.shade700),
                  ),
                  Text(
                      "⚠️ لا يمكنك التبرع قبل إتمام الفحص وقبوله.",
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
                _isUploadingTestImage
                    ? "جاري الرفع..."
                    : "رفع صورة الفحص",
                style:
                    const TextStyle(color: Colors.white, fontSize: 13),
              ),
              onPressed:
                  _isUploadingTestImage ? null : _uploadBloodTestImage,
            ),
          ),
        ],
      ),
    );
  }

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
          Row(children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
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
                    _isUploadingTestImage
                        ? "جاري الرفع..."
                        : "إعادة الرفع",
                    style: const TextStyle(color: Colors.white)),
                onPressed:
                    _isUploadingTestImage ? null : _uploadBloodTestImage,
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
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}