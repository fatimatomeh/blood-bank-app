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

  final TextEditingController _phoneController = TextEditingController();
  final Map<String, String?> _selectedArrivalTime = {};
  final Map<String, int> _countdownSeconds = {};
  final Map<String, Timer> _countdownTimers = {};

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
    _checkPendingDonations();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (final t in _countdownTimers.values) t.cancel();
    super.dispose();
  }

  void _startCountdown(String requestId, int totalSeconds) {
    _countdownTimers[requestId]?.cancel();
    setState(() => _countdownSeconds[requestId] = totalSeconds);
    _countdownTimers[requestId] =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      final remaining = (_countdownSeconds[requestId] ?? 0) - 1;
      if (remaining <= 0) {
        timer.cancel();
        setState(() => _countdownSeconds.remove(requestId));
        _askArrival(requestId,
            double.tryParse(_selectedArrivalTime[requestId] ?? "1") ?? 1.0);
      } else {
        setState(() => _countdownSeconds[requestId] = remaining);
      }
    });
  }

  String _formatCountdown(int seconds) {
    if (seconds >= 3600) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      final s = seconds % 60;
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    }
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  Future<void> _checkPendingDonations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseDatabase.instance
        .ref("Donors/${user.uid}/donations")
        .get();
    if (!snap.exists || snap.value is! Map) return;
    final donations = Map<String, dynamic>.from(snap.value as Map);
    for (final entry in donations.entries) {
      final requestId = entry.key;
      final reqSnap =
          await FirebaseDatabase.instance.ref("Requests/$requestId").get();
      if (!reqSnap.exists || reqSnap.value is! Map) continue;
      final reqData = Map<String, dynamic>.from(reqSnap.value as Map);
      final confirmedAtStr = reqData['confirmedAt']?.toString() ?? "";
      final arrivalTimeStr = reqData['arrivalTimeHours']?.toString() ?? "1";
      final status = reqData['status']?.toString() ?? "";
      // ── إذا الموظف أكد التبرع، ما نحتاج countdown ──
      if (reqData['confirmedByStaff'] == true) continue;
      // ── إذا المتبرع قال وصل، ما نحتاج countdown ──
      if (reqData['donorArrived'] == true) continue;
      if (status != 'مغلق' || confirmedAtStr.isEmpty) continue;
      try {
        final confirmedAt = DateTime.parse(confirmedAtStr);
        final hours = double.tryParse(arrivalTimeStr) ?? 1.0;
        final deadline =
            confirmedAt.add(Duration(minutes: (hours * 60).round()));
        final now = DateTime.now();
        if (now.isAfter(deadline)) {
          if (mounted) _askArrival(requestId, hours);
        } else {
          final remaining = deadline.difference(now);
          _startCountdown(requestId, remaining.inSeconds);
        }
      } catch (_) {}
    }
  }

  Future<void> _askArrival(String requestId, double hours) async {
    if (!mounted) return;
    final arrived = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.local_hospital, color: Colors.red),
          SizedBox(width: 8),
          Text("هل وصلت المستشفى؟"),
        ]),
        content: Text(
            "مضى ${_hoursLabel(hours)} على تأكيد تبرعك.\nهل وصلت إلى المستشفى؟",
            style: const TextStyle(fontSize: 15)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.close, color: Colors.red),
            label: const Text("لا، لم أصل",
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text("نعم، وصلت",
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (arrived == true) {
      // ── المتبرع يقول وصل → نحفظ في Firebase وننتظر تأكيد الموظف ──
      await FirebaseDatabase.instance
          .ref("Requests/$requestId")
          .update({'donorArrived': true});

      // ── إشعار للموظف إن المتبرع وصل ──
      final reqSnap = await FirebaseDatabase.instance
          .ref("Requests/$requestId")
          .get();
      if (reqSnap.exists && reqSnap.value is Map) {
        final reqData = Map<String, dynamic>.from(reqSnap.value as Map);
        final hospitalId = reqData['hospitalId']?.toString() ?? "";
        final user = FirebaseAuth.instance.currentUser;
        String donorName = "";
        if (user != null) {
          final donorSnap = await FirebaseDatabase.instance
              .ref("Donors/${user.uid}")
              .get();
          if (donorSnap.exists && donorSnap.value is Map) {
            final d = Map<String, dynamic>.from(donorSnap.value as Map);
            donorName = d['fullName']?.toString() ?? "";
          }
        }
        if (hospitalId.isNotEmpty) {
          await FirebaseDatabase.instance
              .ref("Notifications/$hospitalId")
              .push()
              .set({
            'title': "🏥 متبرع وصل!",
            'message':
                "$donorName وصل للمستشفى وجاهز للتبرع. يرجى تأكيد التبرع.",
            'type': "donor_arrived",
            'requestId': requestId,
            'donorId': user?.uid ?? "",
            'isRead': false,
            'createdAt': ServerValue.timestamp,
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("✅ تم إبلاغ الموظف بوصولك، انتظر تأكيده"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ));
      }
    } else {
      await _reopenRequest(requestId);
    }
  }

  String _hoursLabel(double hours) {
    if (hours == 0.25) return 'ربع ساعة';
    if (hours == 0.5) return 'نص ساعة';
    if (hours == 1.0) return 'ساعة';
    if (hours == 2.0) return 'ساعتان';
    return '${hours.toInt()} ساعات';
  }

  String _timeLabel(String value) {
    switch (value) {
      case '0.25': return 'ربع ساعة';
      case '0.5': return 'نص ساعة';
      case '1': return 'ساعة';
      case '2': return 'ساعتين';
      case '3': return '3 ساعات';
      default: return '$value ساعات';
    }
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
                int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            final diff =
                DateTime.now().difference(lastDonationDate!).inDays;
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
      final reqSnap =
          await FirebaseDatabase.instance.ref("Requests").get();
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

  Future<void> _reopenRequest(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseDatabase.instance.ref("Requests/$requestId").update({
        'assignedDonorId': null,
        'status': 'مفتوح',
        'confirmedAt': null,
        'donorArrived': null,
        'confirmedByStaff': null,
      });
      await FirebaseDatabase.instance
          .ref("Donors/${user.uid}/donations/$requestId")
          .remove();

      final donorSnap =
          await FirebaseDatabase.instance.ref("Donors/${user.uid}").get();
      if (donorSnap.exists && donorSnap.value is Map) {
        final d = Map<String, dynamic>.from(donorSnap.value as Map);
        final count = int.tryParse(d['donationCount']?.toString() ?? "0") ?? 0;
        if (count > 0) {
          await FirebaseDatabase.instance
              .ref("Donors/${user.uid}")
              .update({'donationCount': count - 1});
        }
      }

      if (mounted) {
        setState(() {
          donatedRequestIds.remove(requestId);
          canDonate = true;
          _countdownSeconds.remove(requestId);
          _countdownTimers[requestId]?.cancel();
          _countdownTimers.remove(requestId);
          final idx =
              cityRequests.indexWhere((r) => _getRequestId(r) == requestId);
          if (idx != -1) cityRequests[idx].remove('assignedDonorId');
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("تم إلغاء تبرعك وإعادة فتح الطلب"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ));
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void confirmDialog(
      BuildContext context, Map<String, dynamic> data, String requestId) {
    final phone = _phoneController.text.trim();
    final selectedTime = _selectedArrivalTime[requestId];
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("يرجى إدخال رقم الهاتف"),
          backgroundColor: Colors.red));
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تأكيد التبرع"),
        content: const Text(
            "هل أنت متأكد؟\nسيتم إرسال إشعار للتحقق من وصولك."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final user = FirebaseAuth.instance.currentUser;
              if (user == null || requestId.isEmpty) return;

              final reqSnap = await FirebaseDatabase.instance
                  .ref("Requests/$requestId")
                  .get();
              if (reqSnap.exists && reqSnap.value is Map) {
                final reqData =
                    Map<String, dynamic>.from(reqSnap.value as Map);
                final existing =
                    reqData['assignedDonorId']?.toString() ?? "";
                if (existing.isNotEmpty && existing != user.uid) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("عذراً، تم التبرع من شخص آخر"),
                        backgroundColor: Colors.red));
                  }
                  return;
                }
              }

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

              await FirebaseDatabase.instance
                  .ref("Requests/$requestId")
                  .update({
                'assignedDonorId': user.uid,
                'status': 'مغلق',
                'donorPhone': phone,
                'arrivalTimeHours': selectedTime,
                'confirmedAt': now.toIso8601String(),
                'donorArrived': false,
                'confirmedByStaff': false,
                'donatedCount': ServerValue.increment(1),
              });

              final reqSnap2 = await FirebaseDatabase.instance
                  .ref("Requests/$requestId")
                  .get();
              String donationHospitalId = "";
              if (reqSnap2.exists && reqSnap2.value is Map) {
                final rd = Map<String, dynamic>.from(reqSnap2.value as Map);
                donationHospitalId = rd['hospitalId']?.toString() ?? "";
                if (donationHospitalId.isNotEmpty) {
                  await FirebaseDatabase.instance
                      .ref("Notifications/$donationHospitalId")
                      .push()
                      .set({
                    'title': "متبرع في الطريق 🚗",
                    'message':
                        "متبرع بفصيلة ${data['bloodType'] ?? ''} سيصل خلال ${_timeLabel(selectedTime)} لقسم ${data['department'] ?? ''}.",
                    'type': "donor_coming",
                    'requestId': requestId,
                    'donorId': user.uid,
                    'isRead': false,
                    'createdAt': ServerValue.timestamp,
                  });
                }
              }

              final donorRef =
                  FirebaseDatabase.instance.ref("Donors/${user.uid}");
              final donorSnap = await donorRef.get();
              if (donorSnap.exists && donorSnap.value is Map) {
                final donorData =
                    Map<String, dynamic>.from(donorSnap.value as Map);
                final currentCount =
                    int.tryParse(donorData['donationCount']?.toString() ?? "0") ?? 0;

                await donorRef.update({
                  "donationCount": currentCount + 1,
                  "lastDonation": dateStr,
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

                final hours = double.tryParse(selectedTime) ?? 1.0;
                _startCountdown(requestId, (hours * 3600).round());
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      "تم تسجيل تبرعك ✅ سيتحقق الموظف من وصولك خلال ${_timeLabel(selectedTime)}"),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 4),
                ));
              }
            },
            child: const Text("تأكيد",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
                final countdown = _countdownSeconds[requestId];

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
                        infoRow(Icons.local_hospital,
                            data['hospitalName'] ?? "-"),
                        infoRow(Icons.location_on, data['city'] ?? "-"),
                        infoRow(Icons.medical_services,
                            data['department'] ?? "-"),
                        infoRow(Icons.water_drop,
                            "الوحدات: ${data['units'] ?? '-'}"),
                        const SizedBox(height: 20),

                        if (countdown != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Column(
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.timer,
                                        color: Colors.red, size: 22),
                                    SizedBox(width: 8),
                                    Text("الوقت المتبقي للوصول",
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(_formatCountdown(countdown),
                                    style: const TextStyle(
                                        fontSize: 38,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                        letterSpacing: 4)),
                                const SizedBox(height: 6),
                                Text("توجه للمستشفى الآن 🏥",
                                    style: TextStyle(
                                        color: Colors.red.shade400,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if ((alreadyDonated || isTaken) && countdown == null)
                          _statusBox(
                            color: Colors.green,
                            icon: Icons.check_circle,
                            title: "تم التبرع لهذا الطلب ✅",
                          )
                        else if (!canDonate && countdown == null)
                          _statusBox(
                            color: Colors.orange,
                            icon: Icons.timer,
                            title: "لا يمكنك التبرع الآن",
                            subtitle:
                                "باقي ${_daysRemaining()} يوم لاستكمال 4 أشهر",
                          )
                        else if (countdown == null) ...[
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
                                  value: "0.25",
                                  child: Text("خلال ربع ساعة")),
                              DropdownMenuItem(
                                  value: "0.5",
                                  child: Text("خلال نص ساعة")),
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
                              prefixIcon: const Icon(Icons.phone,
                                  color: Colors.red),
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
                                padding: const EdgeInsets.symmetric(
                                    vertical: 15),
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
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
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