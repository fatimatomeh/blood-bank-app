import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'city_helper.dart';

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

            setState(() {
              canDonate = diff >= 120;
            });
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
      print("Error loading requests: $e");
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
                        infoRow(Icons.location_on,
                            data['city'] ?? "غير محدد"),
                        infoRow(Icons.medical_services,
                            data['department'] ?? "غير محدد"),
                        infoRow(Icons.water_drop,
                            "الوحدات: ${data['units'] ?? 'غير محدد'}"),
                        const SizedBox(height: 20),

                        if (alreadyDonated || isTaken)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Colors.green.shade200),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.green, size: 28),
                                SizedBox(width: 10),
                                Text(
                                  "تم التبرع لهذا الطلب ✅",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )

                        else if (_needsBloodTest)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Colors.purple.shade300),
                            ),
                            child: Column(
                              children: [
                                const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.science_outlined,
                                        color: Colors.purple, size: 28),
                                    SizedBox(width: 10),
                                    Text(
                                      "يجب إجراء فحص دوري أولاً",
                                      style: TextStyle(
                                        color: Colors.purple,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "حان موعد فحصك الدوري كل 4 أشهر.\nيرجى إجراء الفحص قبل التبرع.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.purple.shade700,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          )

                        else if (!canDonate)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Colors.orange.shade300),
                            ),
                            child: Column(
                              children: [
                                const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.timer,
                                        color: Colors.orange, size: 28),
                                    SizedBox(width: 10),
                                    Text(
                                      "لا يمكنك التبرع الآن",
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "يجب الانتظار 4 أشهر بين كل تبرع والآخر\nباقي ${_daysRemaining()} يوم",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.orange, fontSize: 14),
                                ),
                              ],
                            ),
                          )

                        else ...[
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
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
                                  value: "3",
                                  child: Text("خلال 3 ساعات")),
                            ],
                            onChanged: (value) {},
                          ),
                          const SizedBox(height: 15),
                          customTextField(
                              "رقم الهاتف", TextInputType.phone),
                          const SizedBox(height: 10),
                          customTextField(
                              "تأكيد رقم الهاتف", TextInputType.phone),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("تعليمات قبل التبرع",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    "• تناول وجبة خفيفة\n• اشرب ماء كافٍ\n• احضر الهوية الشخصية\n• يجب أن يكون العمر فوق 18 عاماً"),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: () =>
                                  confirmDialog(context, data, requestId),
                              child: const Text(
                                "تأكيد التبرع",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 18),
                              ),
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

  void confirmDialog(
      BuildContext context, Map<String, dynamic> data, String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد التبرع"),
        content: const Text("هل أنت متأكد من رغبتك بالتبرع لهذا الطلب؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              User? user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              if (requestId.isEmpty) return;

              if (_needsBloodTest) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          "يجب إجراء الفحص الدوري قبل التبرع 🔬"),
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
                final reqData =
                    Map<String, dynamic>.from(reqSnap.value as Map);
                final existingDonor =
                    reqData['assignedDonorId']?.toString() ?? "";

                if (existingDonor.isNotEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            "عذراً، تم التبرع لهذا الطلب من قبل شخص آخر"),
                        backgroundColor: Colors.red,
                      ),
                    );
                    setState(() {
                      final idx = cityRequests.indexWhere(
                          (r) => _getRequestId(r) == requestId);
                      if (idx != -1) {
                        cityRequests[idx]['assignedDonorId'] =
                            existingDonor;
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
                  "lastDonation":
                      "${now.day}/${now.month}/${now.year}",
                });

                await donorRef.child("donations/$requestId").set(true);

                setState(() {
                  donatedRequestIds.add(requestId);
                  lastDonationDate = now;
                  canDonate = false;
                  final idx = cityRequests.indexWhere(
                      (r) => _getRequestId(r) == requestId);
                  if (idx != -1) {
                    cityRequests[idx]['assignedDonorId'] = user.uid;
                  }
                });
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("تم تسجيل تبرعك بنجاح ✅")),
                );
              }
            },
            child: const Text("تأكيد"),
          ),
        ],
      ),
    );
  }

  Widget customTextField(String hint, TextInputType type) {
    return TextField(
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
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