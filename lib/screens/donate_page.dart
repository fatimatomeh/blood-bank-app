import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'city_helper.dart';
import 'dart:async';

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
  bool _needsBloodTest = false;

  // ── حقل الرقم ──────────────────────────────────────────────
  final TextEditingController _phoneController = TextEditingController();

  // ── الوقت المختار لكل طلب ──────────────────────────────────
  final Map<String, String?> _selectedArrivalTime = {};

  @override
  void initState() {
    super.initState();
    if (widget.requestData != null && widget.requestData!.isNotEmpty) {
      cityRequests = [widget.requestData!];
      hasData = true;
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

  // ── تحميل بيانات المتبرع ───────────────────────────────────
  Future<void> _loadDonorInfo() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap =
        await FirebaseDatabase.instance.ref("Donors/${user.uid}").get();

    if (snap.exists && snap.value is Map) {
      final donorData = Map<String, dynamic>.from(snap.value as Map);

      if (donorData['donations'] != null && donorData['donations'] is Map) {
        final donated =
            Map<String, dynamic>.from(donorData['donations'] as Map);
        donatedRequestIds = donated.keys.toSet();
      }

      final lastDonationStr = donorData['lastDonation']?.toString() ?? "";
      if (lastDonationStr.isNotEmpty && lastDonationStr != "غير محدد") {
        try {
          final parts = lastDonationStr.split('/');
          if (parts.length == 3) {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            lastDonationDate = DateTime(year, month, day);
            final now = DateTime.now();
            final diff = now.difference(lastDonationDate!).inDays;
            setState(() => canDonate = diff >= 120);
          }
        } catch (e) {
          setState(() => canDonate = true);
        }
      }

      _checkIfNeedsBloodTest(donorData);
      if (mounted) setState(() {});
    }
  }

  void _checkIfNeedsBloodTest(Map<String, dynamic> profile) {
    final checkStr =
        (profile['lastBloodTest'] ?? profile['lastDonation'])?.toString() ?? "";

    if (checkStr.isEmpty || checkStr == "غير محدد") {
      final createdAtStr = profile['createdAt']?.toString() ?? "";
      if (createdAtStr.isNotEmpty) {
        try {
          final createdAt = DateTime.parse(createdAtStr);
          final days = DateTime.now().difference(createdAt).inDays;
          setState(() => _needsBloodTest = days >= 120);
          return;
        } catch (_) {}
      }
      setState(() => _needsBloodTest = false);
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
        setState(() => _needsBloodTest = days >= 120);
      }
    } catch (_) {
      setState(() => _needsBloodTest = false);
    }
  }

  Future<void> _loadCityRequests() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final donorSnap =
          await FirebaseDatabase.instance.ref("Donors/${user.uid}").get();

      if (donorSnap.exists && donorSnap.value is Map) {
        final donorData = Map<String, dynamic>.from(donorSnap.value as Map);
        final donorCity = CityHelper.normalize(donorData['city']);
        final donorBlood = donorData['bloodType']?.toString().trim() ?? "";

        final reqSnap = await FirebaseDatabase.instance.ref("Requests").get();

        if (reqSnap.exists && reqSnap.value is Map) {
          final requests = Map<String, dynamic>.from(reqSnap.value as Map);
          List<Map<String, dynamic>> temp = [];

          requests.forEach((key, value) {
            final request = Map<String, dynamic>.from(value);
            final reqCity = CityHelper.normalize(request['city']);
            final reqBlood = request['bloodType']?.toString().trim() ?? "";
            final status = request['status']?.toString() ?? "";

            if (reqCity == donorCity &&
                reqBlood == donorBlood &&
                status != 'cancelled') {
              request['requestId'] = key;
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
      debugPrint("Error loading requests: $e");
    }
  }

  String _getRequestId(Map<String, dynamic> data) {
    if (data['requestId'] != null && data['requestId'].toString().isNotEmpty) {
      return data['requestId'].toString();
    }
    if (data['_key'] != null && data['_key'].toString().isNotEmpty) {
      return data['_key'].toString();
    }
    return "";
  }

  int _daysRemaining() {
    if (lastDonationDate == null) return 0;
    final nextAllowed = lastDonationDate!.add(const Duration(days: 120));
    final remaining = nextAllowed.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  // ── التايمر: بعد الوقت المحدد يسأل "هل وصلت؟" ─────────────
  void _startArrivalTimer(String requestId, int hours) {
    final duration = Duration(hours: hours);

    Timer(duration, () async {
      if (!mounted) return;

      // سؤال للمتبرع: هل وصلت؟
      final arrived = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.local_hospital, color: Colors.red),
              SizedBox(width: 8),
              Text("هل وصلت المستشفى؟"),
            ],
          ),
          content: Text(
            "مضى ${hours == 1 ? 'ساعة' : hours == 2 ? 'ساعتان' : '$hours ساعات'} على تأكيد تبرعك.\nهل وصلت إلى المستشفى؟",
            style: const TextStyle(fontSize: 15),
            textAlign: TextAlign.right,
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.close, color: Colors.red),
              label:
                  const Text("لا، لم أصل", style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text("نعم، وصلت",
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );

      if (arrived == true) {
        // تأكيد الوصول — لا يحتاج تغيير، الطلب مغلق بالفعل
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("رائع! شكراً لك على تبرعك 🩸"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        // المتبرع لم يصل — أعد فتح الطلب وأزل تسجيله
        await _reopenRequest(requestId);
      }
    });
  }

  // ── إعادة فتح الطلب لما المتبرع ما وصل ───────────────────
  Future<void> _reopenRequest(String requestId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // إعادة فتح الطلب
      await FirebaseDatabase.instance.ref("Requests/$requestId").update({
        'assignedDonorId': null,
        'status': 'open',
      });

      // إزالة التبرع من سجل المتبرع
      await FirebaseDatabase.instance
          .ref("Donors/${user.uid}/donations/$requestId")
          .remove();

      if (mounted) {
        setState(() {
          donatedRequestIds.remove(requestId);
          canDonate = true;
          final idx =
              cityRequests.indexWhere((r) => _getRequestId(r) == requestId);
          if (idx != -1) {
            cityRequests[idx].remove('assignedDonorId');
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم إلغاء تبرعك وإعادة فتح الطلب لمتبرع آخر"),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error reopening request: $e");
    }
  }

  // ── واجهة لا يوجد طلبات ───────────────────────────────────
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

  // ── تأكيد التبرع ──────────────────────────────────────────
  void confirmDialog(
      BuildContext context, Map<String, dynamic> data, String requestId) {
    final phone = _phoneController.text.trim();
    final selectedTime = _selectedArrivalTime[requestId];

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("يرجى إدخال رقم الهاتف أولاً"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("يرجى اختيار وقت الوصول أولاً"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تأكيد التبرع"),
        content: const Text(
            "هل أنت متأكد من رغبتك بالتبرع لهذا الطلب؟\nسيتم إرسال إشعار بعد الوقت المحدد للتحقق من وصولك."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);

              User? user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              if (requestId.isEmpty) return;

              if (_needsBloodTest) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("يجب إجراء الفحص الدوري قبل التبرع 🔬"),
                      backgroundColor: Colors.purple,
                    ),
                  );
                }
                return;
              }

              final reqSnap = await FirebaseDatabase.instance
                  .ref("Requests/$requestId")
                  .get();

              if (reqSnap.exists && reqSnap.value is Map) {
                final reqData = Map<String, dynamic>.from(reqSnap.value as Map);
                final existingDonor =
                    reqData['assignedDonorId']?.toString() ?? "";

                if (existingDonor.isNotEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text("عذراً، تم التبرع لهذا الطلب من قبل شخص آخر"),
                        backgroundColor: Colors.red,
                      ),
                    );
                    setState(() {
                      final idx = cityRequests
                          .indexWhere((r) => _getRequestId(r) == requestId);
                      if (idx != -1) {
                        cityRequests[idx]['assignedDonorId'] = existingDonor;
                      }
                    });
                  }
                  return;
                }
              }

              final alreadySnap = await FirebaseDatabase.instance
                  .ref("Donors/${user.uid}/donations/$requestId")
                  .get();

              if (alreadySnap.exists) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("لقد تبرعت لهذا الطلب مسبقاً ✅"),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  setState(() => donatedRequestIds.add(requestId));
                }
                return;
              }

              await FirebaseDatabase.instance
                  .ref("Requests/$requestId")
                  .update({
                'assignedDonorId': user.uid,
                'status': 'closed',
                'donorPhone': phone,
                'arrivalTimeHours': selectedTime,
              });

              final donorRef =
                  FirebaseDatabase.instance.ref("Donors/${user.uid}");
              final snapshot = await donorRef.get();

              if (snapshot.exists && snapshot.value is Map) {
                final donorData =
                    Map<String, dynamic>.from(snapshot.value as Map);
                int currentCount = int.tryParse(
                        donorData['donationCount']?.toString() ?? "0") ??
                    0;
                final now = DateTime.now();

                await donorRef.update({
                  "donationCount": currentCount + 1,
                  "lastDonation": "${now.day}/${now.month}/${now.year}",
                });

                await donorRef.child("donations/$requestId").set(true);

                setState(() {
                  donatedRequestIds.add(requestId);
                  lastDonationDate = now;
                  canDonate = false;
                  final idx = cityRequests
                      .indexWhere((r) => _getRequestId(r) == requestId);
                  if (idx != -1) {
                    cityRequests[idx]['assignedDonorId'] = user.uid;
                  }
                });

                // ── ابدأ التايمر بعد التأكيد ──────────────────
                final hours = int.tryParse(selectedTime) ?? 1;
                _startArrivalTimer(requestId, hours);
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        "تم تسجيل تبرعك ✅ سنتحقق من وصولك خلال ${selectedTime == '1' ? 'ساعة' : selectedTime == '2' ? 'ساعتين' : '$selectedTime ساعات'}"),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            child: const Text("تأكيد", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── الواجهة الرئيسية ──────────────────────────────────────
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
                            "فصيلة الدم: ${data['bloodType'] ?? 'غير محدد'}"),
                        infoRow(Icons.local_hospital,
                            data['hospitalName'] ?? "غير محدد"),
                        infoRow(Icons.location_on, data['city'] ?? "غير محدد"),
                        infoRow(Icons.medical_services,
                            data['department'] ?? "غير محدد"),
                        infoRow(Icons.water_drop,
                            "الوحدات: ${data['units'] ?? 'غير محدد'}"),
                        const SizedBox(height: 20),

                        // ── حالة: تبرع مسبق ──────────────────
                        if (alreadyDonated || isTaken)
                          _statusBox(
                            color: Colors.green,
                            icon: Icons.check_circle,
                            title: "تم التبرع لهذا الطلب ✅",
                          )

                        // ── حالة: يحتاج فحص ──────────────────
                        else if (_needsBloodTest)
                          _statusBox(
                            color: Colors.purple,
                            icon: Icons.science_outlined,
                            title: "يجب إجراء فحص دوري أولاً",
                            subtitle:
                                "حان موعد فحصك الدوري كل 4 أشهر.\nيرجى إجراء الفحص قبل التبرع.",
                          )

                        // ── حالة: لا يستطيع التبرع بعد ────────
                        else if (!canDonate)
                          _statusBox(
                            color: Colors.orange,
                            icon: Icons.timer,
                            title: "لا يمكنك التبرع الآن",
                            subtitle:
                                "يجب الانتظار 4 أشهر بين كل تبرع والآخر\nباقي ${_daysRemaining()} يوم",
                          )

                        // ── حالة: يمكن التبرع ─────────────────
                        else ...[
                          // اختيار وقت الوصول
                          DropdownButtonFormField<String>(
                            value: _selectedArrivalTime[requestId],
                            decoration: InputDecoration(
                              labelText: "وقت الوصول للمستشفى",
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
                            onChanged: (value) => setState(
                                () => _selectedArrivalTime[requestId] = value),
                          ),
                          const SizedBox(height: 15),

                          // ── خانة رقم الهاتف (واحدة بس) ───────
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
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── تعليمات قبل التبرع (خط أكبر) ─────
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
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline,
                                        color: Colors.red, size: 22),
                                    const SizedBox(width: 8),
                                    Text(
                                      "تعليمات قبل التبرع",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.red.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _instructionItem(
                                    "🍽️", "تناول وجبة خفيفة قبل التبرع"),
                                _instructionItem(
                                    "💧", "اشرب كميات كافية من الماء"),
                                _instructionItem(
                                    "🪪", "احضر الهوية الشخصية معك"),
                                _instructionItem(
                                    "🔞", "يجب أن يكون عمرك فوق 18 عاماً"),
                                _instructionItem(
                                    "⚖️", "وزنك لا يقل عن 50 كيلوغرام"),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // زر تأكيد التبرع
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.favorite,
                                  color: Colors.white),
                              label: const Text(
                                "تأكيد التبرع",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 18),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
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

  // ── مساعد: بوكس الحالة ────────────────────────────────────
  Widget _statusBox({
    required Color color,
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  // ── مساعد: سطر تعليمات ───────────────────────────────────
  Widget _instructionItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                height: 1.4,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ── ويدجت صف المعلومات ─────────────────────────────────────
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
