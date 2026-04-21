import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'city_helper.dart';
import 'donation_timer_service.dart';

class DonatePage extends StatefulWidget {
  final Map<String, dynamic>? requestData;
  const DonatePage({super.key, this.requestData});

  @override
  _DonatePageState createState() => _DonatePageState();
}

class _DonatePageState extends State<DonatePage> {
  List<Map<String, dynamic>> cityRequests = [];
  bool hasData = false;
  Set<String> donatedRequestIds = {};

  DateTime? lastDonationDate;
  bool canDonate = true;

  final TextEditingController _phoneController = TextEditingController();
  final Map<String, String?> _selectedArrivalTime = {};

  @override
  void initState() {
    super.initState();
    if (widget.requestData != null && widget.requestData!.isNotEmpty) {
      final status = widget.requestData!['status']?.toString() ?? '';
      if (status == 'مغلق' || status == 'ملغي' || status == 'مكتمل') {
        hasData = false;
      } else {
        cityRequests = [widget.requestData!];
        hasData = true;
      }
    } else {
      _loadCityRequests();
    }
    _loadDonorInfo();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadDonorInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap =
        await FirebaseDatabase.instance.ref("Donors/${user.uid}").get();
    if (snap.exists && snap.value is Map) {
      final donorData = Map<String, dynamic>.from(snap.value as Map);
      if (donorData['donations'] is Map) {
        donatedRequestIds =
            Map<String, dynamic>.from(donorData['donations'] as Map)
                .keys
                .toSet();
      }
      final lastStr = donorData['lastDonation']?.toString() ?? "";
      if (lastStr.isNotEmpty && lastStr != "غير محدد") {
        try {
          final parts = lastStr.split('/');
          if (parts.length == 3) {
            lastDonationDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
            final diff = DateTime.now().difference(lastDonationDate!).inDays;
            setState(() => canDonate = diff >= 120);
          }
        } catch (_) {
          setState(() => canDonate = true);
        }
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadCityRequests() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final donorSnap =
          await FirebaseDatabase.instance.ref("Donors/${user.uid}").get();
      if (!donorSnap.exists || donorSnap.value is! Map) return;
      final donorData = Map<String, dynamic>.from(donorSnap.value as Map);
      final donorCity = CityHelper.normalize(donorData['city']);
      final donorBlood = donorData['bloodType']?.toString().trim() ?? "";
      final reqSnap = await FirebaseDatabase.instance.ref("Requests").get();
      if (!reqSnap.exists || reqSnap.value is! Map) return;
      List<Map<String, dynamic>> temp = [];
      Map<String, dynamic>.from(reqSnap.value as Map).forEach((key, value) {
        final req = Map<String, dynamic>.from(value);
        final reqCity = CityHelper.normalize(req['city']);
        final reqBlood = req['bloodType']?.toString().trim() ?? "";
        final status = req['status']?.toString() ?? "";
        if (reqCity == donorCity &&
            reqBlood == donorBlood &&
            status != 'ملغي' &&
            status != 'مغلق' &&
            status != 'مكتمل') {
          req['requestId'] = key;
          temp.add(req);
        }
      });
      setState(() {
        cityRequests = temp;
        hasData = temp.isNotEmpty;
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  String _getRequestId(Map<String, dynamic> data) {
    if (data['requestId']?.toString().isNotEmpty == true)
      return data['requestId'].toString();
    if (data['_key']?.toString().isNotEmpty == true)
      return data['_key'].toString();
    return "";
  }

  int _daysRemaining() {
    if (lastDonationDate == null) return 0;
    final next = lastDonationDate!.add(const Duration(days: 120));
    final rem = next.difference(DateTime.now()).inDays;
    return rem > 0 ? rem : 0;
  }

  // ── عرض تعليمات ما بعد التبرع ──
  void _showPostDonationInstructions(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.favorite, color: Colors.red, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "شكراً لك! 🩸",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "تبرعك بالدم يمكن أن ينقذ حياة شخص!\nاتبع هذه التعليمات بعد التبرع:",
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              const SizedBox(height: 14),
              _postInstruction(
                  "🧃", "اشرب عصيراً أو مشروباً سكرياً مباشرة بعد التبرع"),
              _postInstruction(
                  "🍪", "تناول وجبة خفيفة فور الانتهاء (بسكويت أو تمر)"),
              _postInstruction(
                  "💧", "اشرب كميات وفيرة من الماء خلال اليوم (2-3 لتر)"),
              _postInstruction(
                  "🛋️", "استرح 10-15 دقيقة قبل المغادرة ولا تقم بسرعة"),
              _postInstruction("🚫", "تجنب المجهود البدني الشديد لمدة 24 ساعة"),
              _postInstruction(
                  "🚬", "لا تدخن لمدة ساعتين على الأقل بعد التبرع"),
              _postInstruction("🩹", "أبقِ الضمادة على ذراعك لمدة 4-6 ساعات"),
              _postInstruction(
                  "🏊", "تجنب السباحة أو الاستحمام الساخن لعدة ساعات"),
              _postInstruction(
                  "🔄", "يمكنك التبرع مجدداً بعد 4 أشهر (120 يوماً)"),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "إذا شعرت بدوار أو إغماء، اجلس فوراً وأخبر أحد الموظفين",
                        style: TextStyle(color: Colors.orange, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 45),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("فهمت، شكراً! ❤️",
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _postInstruction(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 14, height: 1.4),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  void confirmDialog(
      BuildContext context, Map<String, dynamic> data, String requestId) {
    final phone = _phoneController.text.trim();
    final selectedTime = _selectedArrivalTime[requestId];
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("يرجى إدخال رقم الهاتف"), backgroundColor: Colors.red));
      return;
    }
    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("يرجى اختيار وقت الوصول"),
          backgroundColor: Colors.red));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تأكيد التبرع"),
        content: const Text("هل أنت متأكد؟\nسيتم إبلاغ الموظف بأنك في الطريق."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _processDonation(context, data, requestId, selectedTime);
            },
            child: const Text("تأكيد", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _processDonation(
    BuildContext context,
    Map<String, dynamic> data,
    String requestId,
    String selectedTime,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || requestId.isEmpty) return;

    // تحقق إن ما أخذ حدا غيره الطلب
    final reqSnap =
        await FirebaseDatabase.instance.ref("Requests/$requestId").get();
    if (reqSnap.exists && reqSnap.value is Map) {
      final reqData = Map<String, dynamic>.from(reqSnap.value as Map);
      final existing = reqData['assignedDonorId']?.toString() ?? "";
      if (existing.isNotEmpty && existing != user.uid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("عذراً، تم التبرع من شخص آخر"),
              backgroundColor: Colors.red));
        }
        return;
      }
    }

    // تحقق إن ما تبرع لهاد الطلب من قبل
    final alreadySnap = await FirebaseDatabase.instance
        .ref("Donors/${user.uid}/donations/$requestId")
        .get();
    if (alreadySnap.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("لقد تبرعت لهذا الطلب مسبقاً ✅"),
            backgroundColor: Colors.orange));
        setState(() => donatedRequestIds.add(requestId));
      }
      return;
    }

    final now = DateTime.now();
    final dateStr = "${now.day}/${now.month}/${now.year}";
    final arrivalHours = double.tryParse(selectedTime) ?? 1.0;

    // 1. تحديث الطلب
    await FirebaseDatabase.instance.ref("Requests/$requestId").update({
      'assignedDonorId': user.uid,
      'status': 'مغلق',
      'donorPhone': _phoneController.text.trim(),
      'arrivalTimeHours': selectedTime,
      'confirmedAt': now.toIso8601String(),
      'confirmedByStaff': false,
    });

    // 2. جلب hospitalId
    final reqSnap2 =
        await FirebaseDatabase.instance.ref("Requests/$requestId").get();
    String donationHospitalId = "";
    if (reqSnap2.exists && reqSnap2.value is Map) {
      final rd = Map<String, dynamic>.from(reqSnap2.value as Map);
      donationHospitalId = rd['hospitalId']?.toString() ?? "";
    }

    // 3. بدء مؤقت Firebase
    await DonationTimerService.startTimer(
      requestId: requestId,
      hospitalId: donationHospitalId,
      hospitalName: data['hospitalName']?.toString() ?? "",
      bloodType: data['bloodType']?.toString() ?? "",
      arrivalHours: arrivalHours,
    );

    // 4. إشعار للمستشفى: متبرع في الطريق
    if (donationHospitalId.isNotEmpty) {
      await FirebaseDatabase.instance
          .ref("Notifications/$donationHospitalId")
          .push()
          .set({
        'title': "متبرع في الطريق 🚗",
        'message':
            "متبرع بفصيلة ${data['bloodType'] ?? ''} سيصل خلال ${DonationTimerService.arrivalLabel(selectedTime)} لقسم ${data['department'] ?? ''}.",
        'type': "donor_coming",
        'requestId': requestId,
        'donorId': user.uid,
        'isRead': false,
        'createdAt': ServerValue.timestamp,
      });
    }

    // 5. تحديث سجل المتبرع (بدون تحديث lastDonation - ده بيتحدث من الموظف)
    final donorRef = FirebaseDatabase.instance.ref("Donors/${user.uid}");
    await donorRef.update({
      if (donationHospitalId.isNotEmpty)
        "bloodTestHospitalId": donationHospitalId,
    });

    await donorRef.child("donations/$requestId").set({
      'hospitalName': data['hospitalName'] ?? 'غير محدد',
      'department': data['department'] ?? 'غير محدد',
      'bloodType': data['bloodType'] ?? 'غير محدد',
      'city': data['city'] ?? 'غير محدد',
      'date': dateStr,
      'confirmedAt': now.toIso8601String(),
      'confirmedByStaff': false,
    });

    if (mounted) {
      setState(() {
        donatedRequestIds.add(requestId);
        lastDonationDate = now;
        canDonate = false;
        final idx =
            cityRequests.indexWhere((r) => _getRequestId(r) == requestId);
        if (idx != -1) {
          cityRequests[idx]['assignedDonorId'] = user.uid;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            "تم تسجيل تبرعك ✅ توجّه للمستشفى خلال ${DonationTimerService.arrivalLabel(selectedTime)}"),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ));

      // تعليمات ما بعد التبرع
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showPostDonationInstructions(context);
      });
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
          ? _buildNoRequest()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cityRequests.length,
              itemBuilder: (context, index) {
                final data = cityRequests[index];
                final requestId = _getRequestId(data);
                final alreadyDonated = donatedRequestIds.contains(requestId);
                final isTaken =
                    data['assignedDonorId']?.toString().isNotEmpty == true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        infoRow(Icons.favorite,
                            "فصيلة الدم: ${data['bloodType'] ?? '-'}"),
                        infoRow(
                            Icons.local_hospital, data['hospitalName'] ?? "-"),
                        infoRow(Icons.location_on, data['city'] ?? "-"),
                        infoRow(
                            Icons.medical_services, data['department'] ?? "-"),
                        infoRow(Icons.water_drop,
                            "الوحدات: ${data['units'] ?? '-'}"),
                        const SizedBox(height: 20),
                        if (alreadyDonated || isTaken)
                          _statusBox(
                            color: Colors.green,
                            icon: Icons.check_circle,
                            title: "تم التبرع لهذا الطلب ✅",
                          )
                        else if (!canDonate)
                          _statusBox(
                            color: Colors.orange,
                            icon: Icons.timer,
                            title: "لا يمكنك التبرع الآن",
                            subtitle:
                                "باقي ${_daysRemaining()} يوم لاستكمال 4 أشهر",
                          )
                        else ...[
                          DropdownButtonFormField<String>(
                            value: _selectedArrivalTime[requestId],
                            decoration: InputDecoration(
                              labelText: "وقت الوصول للمستشفى",
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none),
                            ),
                            hint: const Text("اختر وقت الوصول"),
                            items: const [
                              DropdownMenuItem(
                                  value: "0.25", child: Text("خلال ربع ساعة")),
                              DropdownMenuItem(
                                  value: "0.5", child: Text("خلال نص ساعة")),
                              DropdownMenuItem(
                                  value: "1", child: Text("خلال ساعة")),
                              DropdownMenuItem(
                                  value: "2", child: Text("خلال ساعتين")),
                              DropdownMenuItem(
                                  value: "3", child: Text("خلال 3 ساعات")),
                            ],
                            onChanged: (v) => setState(
                                () => _selectedArrivalTime[requestId] = v),
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: "رقم الهاتف",
                              hintText: "05XXXXXXXX",
                              prefixIcon:
                                  const Icon(Icons.phone, color: Colors.red),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.info_outline,
                                      color: Colors.red, size: 22),
                                  const SizedBox(width: 8),
                                  Text("تعليمات قبل التبرع",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.red.shade800)),
                                ]),
                                const SizedBox(height: 12),
                                _instructionItem(
                                    "🍽️", "تناول وجبة خفيفة قبل التبرع"),
                                _instructionItem(
                                    "💧", "اشرب كميات كافية من الماء"),
                                _instructionItem(
                                    "🪪", "احضر الهوية الشخصية معك"),
                                _instructionItem(
                                    "⚖️", "وزنك لا يقل عن 50 كيلوغرام"),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.favorite,
                                  color: Colors.white),
                              label: const Text("تأكيد التبرع",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 18)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: () =>
                                  confirmDialog(context, data, requestId),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildNoRequest() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text("لا يوجد طلب حالي بمدينتك",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54)),
          const SizedBox(height: 8),
          const Text("شكراً لروحك الطيبة، سنوافيك بكل جديد",
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _statusBox(
      {required Color color,
      required IconData icon,
      required String title,
      String? subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Text(title,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Widget _instructionItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                  textAlign: TextAlign.right)),
        ],
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
              child: Text(text,
                  style: const TextStyle(fontSize: 15),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
