import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'city_helper.dart';

class BloodBankDonorsPage extends StatefulWidget {
  const BloodBankDonorsPage({super.key});

  @override
  State<BloodBankDonorsPage> createState() => _BloodBankDonorsPageState();
}

class _BloodBankDonorsPageState extends State<BloodBankDonorsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> allDonors = [];
  List<Map<String, dynamic>> filteredDonors = [];
  List<Map<String, dynamic>> pendingTests = [];

  String staffHospitalId = "";
  String staffCity = "";
  String _testFilter = "معلق";
  String searchQuery = "";
  String? bloodFilter;
  bool showTodayOnly = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final staffSnap =
        await FirebaseDatabase.instance.ref("BloodBankStaff/$uid").get();
    if (staffSnap.exists && staffSnap.value is Map) {
      final data = Map<String, dynamic>.from(staffSnap.value as Map);
      staffHospitalId = data['hospitalId']?.toString() ?? "";
      staffCity = CityHelper.normalize(data['city']?.toString());
    }

    if (staffHospitalId.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    final reqSnap = await FirebaseDatabase.instance.ref("Requests").get();

    final Set<String> donorIdsFromRequests = {};
    if (reqSnap.exists && reqSnap.value is Map) {
      final requests = Map<String, dynamic>.from(reqSnap.value as Map);
      requests.forEach((key, value) {
        final req = Map<String, dynamic>.from(value);
        if (req['hospitalId']?.toString() == staffHospitalId) {
          final assignedDonor = req['assignedDonorId']?.toString() ?? "";
          if (assignedDonor.isNotEmpty) {
            donorIdsFromRequests.add(assignedDonor);
          }
        }
      });
    }

    FirebaseDatabase.instance.ref("Donors").onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) {
        setState(() => isLoading = false);
        return;
      }

      List<Map<String, dynamic>> donors = [];
      List<Map<String, dynamic>> tests = [];

      Map<String, dynamic>.from(data).forEach((key, value) {
        final donor = Map<String, dynamic>.from(value);
        donor['_uid'] = key;

        final donorCity = CityHelper.normalize(donor['city']?.toString());

        if (donorCity == staffCity || donorIdsFromRequests.contains(key)) {
          donors.add(donor);
        }

        if ((donorCity == staffCity || donorIdsFromRequests.contains(key)) &&
            donor['bloodTestProofUrl'] != null &&
            donor['bloodTestProofUrl'].toString().isNotEmpty) {
          tests.add(donor);
        }
      });

      setState(() {
        allDonors = donors;
        pendingTests = tests;
        isLoading = false;
        _applyDonorFilter();
      });
    });
  }

  String _todayStr() {
    final now = DateTime.now();
    return "${now.day}/${now.month}/${now.year}";
  }

  void _applyDonorFilter() {
    setState(() {
      filteredDonors = allDonors.where((d) {
        final name = d['fullName']?.toString().toLowerCase() ?? "";
        final blood = d['bloodType']?.toString() ?? "";
        final lastDon = d['lastDonation']?.toString() ?? "";

        final matchSearch =
            searchQuery.isEmpty || name.contains(searchQuery.toLowerCase());
        final matchBlood = bloodFilter == null || blood == bloodFilter;
        final matchToday = !showTodayOnly || lastDon == _todayStr();

        return matchSearch && matchBlood && matchToday;
      }).toList();
    });
  }

  List<Map<String, dynamic>> _getFilteredTests() {
    return pendingTests.where((d) {
      final status = d['bloodTestStatus']?.toString() ?? "معلق";
      if (_testFilter == "الكل") return true;
      return status == _testFilter;
    }).toList();
  }

  Future<void> _updateTestStatus(String uid, String status) async {
    final now = DateTime.now();
    final dateStr = "${now.day}/${now.month}/${now.year}";
    final updates = <String, dynamic>{
      'bloodTestStatus': status,
      'notification': {
        'message': status == "مكتمل"
            ? "✅ تم قبول صورة فحصك الدوري! يمكنك التبرع الآن."
            : "❌ تم رفض صورة فحصك الدوري. يرجى رفع صورة أوضح.",
        'isRead': false,
        'createdAt': dateStr,
        'type': status == "مكتمل" ? "success" : "error",
      },
    };

    if (status == "مكتمل") updates['lastBloodTest'] = dateStr;
    if (status == "مرفوض") updates['lastBloodTest'] = "غير محدد";

    await FirebaseDatabase.instance.ref("Donors/$uid").update(updates);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == "مكتمل"
            ? "✅ تم القبول وإشعار المتبرع"
            : "❌ تم الرفض وإشعار المتبرع"),
        backgroundColor: status == "مكتمل" ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _confirmDonation(
      String uid, String donorName, String requestId) async {
    String? selectedRequestId;
    bool isManual = requestId.startsWith("manual_");

    if (isManual) {
      final reqSnap = await FirebaseDatabase.instance.ref("Requests").get();
      List<Map<String, dynamic>> openRequests = [];

      if (reqSnap.exists && reqSnap.value is Map) {
        Map<String, dynamic>.from(reqSnap.value as Map).forEach((key, value) {
          final req = Map<String, dynamic>.from(value);
          final status = req['status']?.toString() ?? "";
          if (req['hospitalId']?.toString() == staffHospitalId &&
              (status == "عاجل" || status == "مفتوح")) {
            req['_key'] = key;
            openRequests.add(req);
          }
        });
      }

      if (openRequests.isNotEmpty && mounted) {
        selectedRequestId = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Row(children: [
              Icon(Icons.bloodtype, color: Colors.red),
              SizedBox(width: 8),
              Text("اختر الطلب"),
            ]),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: openRequests.length,
                itemBuilder: (ctx, i) {
                  final req = openRequests[i];
                  return ListTile(
                    leading: const Icon(Icons.water_drop, color: Colors.red),
                    title: Text(
                        "${req['bloodType'] ?? ''} — ${req['department'] ?? ''}"),
                    subtitle: Text(req['units']?.toString() ?? ""),
                    onTap: () =>
                        Navigator.pop(ctx, req['_key']?.toString() ?? ""),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text("بدون طلب محدد"),
              ),
            ],
          ),
        );
      }
    } else {
      selectedRequestId = requestId;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [
          Icon(Icons.bloodtype, color: Colors.red),
          SizedBox(width: 8),
          Text("تأكيد التبرع"),
        ]),
        content:
            Text("هل تأكد تبرع $donorName اليوم؟\nسيتم تحديث سجله تلقائياً."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("تأكيد", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final snap = await FirebaseDatabase.instance.ref("Donors/$uid").get();
    if (!snap.exists) return;

    final donor = Map<String, dynamic>.from(snap.value as Map);
    final currentCount =
        int.tryParse(donor['donationCount']?.toString() ?? "0") ?? 0;
    final dateStr = _todayStr();

    final donorUpdates = <String, dynamic>{
      'lastDonation': dateStr,
      'donationCount': currentCount + 1,
      'notification': {
        'message': "🩸 تم تسجيل تبرعك بتاريخ $dateStr. شكراً لك ❤️",
        'isRead': false,
        'createdAt': dateStr,
        'type': "success",
      },
    };

    final usedRequestId =
        selectedRequestId ?? "manual_${DateTime.now().millisecondsSinceEpoch}";

    donorUpdates['donations/$usedRequestId'] = {
      'date': dateStr,
      'confirmedByStaff': true,
      'hospitalId': staffHospitalId,
    };

    await FirebaseDatabase.instance.ref("Donors/$uid").update(donorUpdates);

    if (selectedRequestId != null && selectedRequestId.isNotEmpty) {
      await FirebaseDatabase.instance
          .ref("Requests/$selectedRequestId")
          .update({
        'assignedDonorId': uid,
        'status': 'مغلق',
        'donatedCount': ServerValue.increment(1),
        'confirmedByStaff': true,
        'staffConfirmedAt': dateStr,
      });

      await FirebaseDatabase.instance
          .ref("Notifications/$staffHospitalId")
          .push()
          .set({
        'title': "تبرع مسجّل يدوياً 🩸",
        'message':
            "قام موظف البنك بتسجيل تبرع $donorName لطلب الدم بتاريخ $dateStr.",
        'type': "manual_donation",
        'requestId': selectedRequestId,
        'isRead': false,
        'createdAt': ServerValue.timestamp,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("✅ تم تسجيل تبرع $donorName بنجاح"),
        backgroundColor: Colors.green,
      ));
    }
  }

  void _showNoteDialog(String uid, String currentNote) {
    final controller = TextEditingController(text: currentNote);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [
          Icon(Icons.edit_note, color: Colors.blue),
          SizedBox(width: 8),
          Text("ملاحظة الموظف"),
        ]),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: "اكتب ملاحظتك هنا...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              await FirebaseDatabase.instance
                  .ref("Donors/$uid")
                  .update({'staffNote': controller.text.trim()});
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ تم حفظ الملاحظة"),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
            },
            child: const Text("حفظ", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain,
              loadingBuilder: (ctx, child, prog) {
            if (prog == null) return child;
            return const SizedBox(
                height: 200,
                child: Center(
                    child: CircularProgressIndicator(color: Colors.white)));
          }),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "معلق":
        return Colors.orange;
      case "مكتمل":
        return Colors.green;
      case "مرفوض":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "معلق":
        return "معلق ⏳";
      case "مكتمل":
        return "مكتمل ✅";
      case "مرفوض":
        return "مرفوض ❌";
      default:
        return "غير محدد";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "المتبرعون",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 18),
                  SizedBox(width: 6),
                  Text("قائمة المتبرعين"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.science_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(
                      "الفحوصات${pendingTests.where((d) => (d['bloodTestStatus']?.toString() ?? 'معلق') == 'معلق').isNotEmpty ? ' 🔴' : ''}"),
                ],
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDonorsTab(),
                _buildTestsTab(),
              ],
            ),
    );
  }

  Widget _buildDonorsTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: (v) {
                  searchQuery = v;
                  _applyDonorFilter();
                },
                decoration: InputDecoration(
                  hintText: "ابحث باسم المتبرع...",
                  prefixIcon: const Icon(Icons.search, color: Colors.red),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => showTodayOnly = !showTodayOnly);
                      _applyDonorFilter();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: showTodayOnly
                            ? Colors.green.shade100
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: showTodayOnly
                              ? Colors.green
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        "📅 اليوم فقط",
                        style: TextStyle(
                          color: showTodayOnly
                              ? Colors.green
                              : Colors.grey.shade600,
                          fontWeight: showTodayOnly
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _bloodChip("الكل", null),
                          ...["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"]
                              .map((b) => _bloodChip(b, b)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              "${filteredDonors.length} متبرع",
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
        Expanded(
          child: filteredDonors.isEmpty
              ? const Center(child: Text("لا يوجد متبرعون"))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredDonors.length,
                  itemBuilder: (context, index) {
                    final donor = filteredDonors[index];
                    return _buildDonorCard(donor);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDonorCard(Map<String, dynamic> donor) {
    final uid = donor['_uid']?.toString() ?? "";
    final lastDon = donor['lastDonation']?.toString() ?? "لم يتبرع";
    final isToday = lastDon == _todayStr();
    final count = donor['donationCount']?.toString() ?? "0";
    final staffNote = donor['staffNote']?.toString() ?? "";

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.shade100,
          child: Text(
            donor['bloodType']?.toString() ?? "?",
            style: const TextStyle(
                color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        title: Text(
          donor['fullName'] ?? "غير محدد",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📞 ${donor['phone'] ?? 'غير محدد'}"),
            Row(
              children: [
                Text("آخر تبرع: $lastDon"),
                if (isToday) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text("اليوم",
                        style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _infoChip(Icons.favorite, "$count تبرع", Colors.red),
                    const SizedBox(width: 8),
                    _infoChip(
                        Icons.location_on, donor['city'] ?? "-", Colors.blue),
                  ],
                ),
                const SizedBox(height: 12),
                if (donor['donations'] != null &&
                    donor['donations'] is Map) ...[
                  const Text(
                    "📋 تاريخ التبرعات:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...Map<String, dynamic>.from(donor['donations'])
                      .entries
                      .map((e) {
                    final d = e.value is Map
                        ? Map<String, dynamic>.from(e.value)
                        : {};
                    final date = d['date']?.toString() ?? e.value.toString();
                    final confirmed = d['confirmedByStaff'] == true;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.circle,
                              size: 8,
                              color: confirmed ? Colors.green : Colors.grey),
                          const SizedBox(width: 6),
                          Text(date),
                          if (confirmed)
                            const Text(
                              " ✓ موظف",
                              style:
                                  TextStyle(color: Colors.green, fontSize: 12),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
                if (staffNote.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "📝 $staffNote",
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.bloodtype,
                            color: Colors.white, size: 16),
                        label: const Text("تسجيل تبرع",
                            style:
                                TextStyle(color: Colors.white, fontSize: 13)),
                        onPressed: () => _confirmDonation(
                          uid,
                          donor['fullName'] ?? "",
                          "manual_${DateTime.now().millisecondsSinceEpoch}",
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.edit_note,
                            color: Colors.white, size: 16),
                        label: const Text("ملاحظة",
                            style:
                                TextStyle(color: Colors.white, fontSize: 13)),
                        onPressed: () => _showNoteDialog(uid, staffNote),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestsTab() {
    final filtered = _getFilteredTests();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _testFilterChip("معلق", "معلق", Colors.orange),
              const SizedBox(width: 8),
              _testFilterChip("مكتمل", "مقبول", Colors.green),
              const SizedBox(width: 8),
              _testFilterChip("مرفوض", "مرفوض", Colors.red),
              const SizedBox(width: 8),
              _testFilterChip("الكل", "الكل", Colors.grey),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Colors.grey.shade400, size: 60),
                      const SizedBox(height: 15),
                      Text(
                        "لا يوجد فحوصات ${_statusLabel(_testFilter)}",
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final donor = filtered[index];
                    return _buildTestCard(donor);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTestCard(Map<String, dynamic> donor) {
    final uid = donor['_uid']?.toString() ?? "";
    final status = donor['bloodTestStatus']?.toString() ?? "معلق";
    final proofUrl = donor['bloodTestProofUrl']?.toString() ?? "";
    final submittedAt = donor['bloodTestSubmittedAt']?.toString() ?? "";

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
            color: _statusColor(status).withOpacity(0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donor['fullName'] ?? "مجهول",
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "🩸 ${donor['bloodType'] ?? '-'}   📞 ${donor['phone'] ?? '-'}",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    if (submittedAt.isNotEmpty)
                      Text(
                        "📅 أرسل: $submittedAt",
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12),
                      ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor(status)),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (proofUrl.isNotEmpty)
              GestureDetector(
                onTap: () => _showFullImage(proofUrl),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        proofUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 180,
                            color: Colors.grey.shade200,
                            child: const Center(
                                child: CircularProgressIndicator()),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text("اضغط للتكبير",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            if (status == "معلق")
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text("قبول",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      onPressed: () => _updateTestStatus(uid, "مكتمل"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text("رفض",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      onPressed: () => _updateTestStatus(uid, "مرفوض"),
                    ),
                  ),
                ],
              ),
            if (status != "معلق")
              Center(
                child: Text(
                  status == "مكتمل"
                      ? "✅ تم قبول هذا الفحص"
                      : "❌ تم رفض هذا الفحص",
                  style: TextStyle(
                      color: _statusColor(status), fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bloodChip(String label, String? value) {
    final isSelected = bloodFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => bloodFilter = value);
        _applyDonorFilter();
      },
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: isSelected ? Colors.red : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.red : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _testFilterChip(String value, String label, Color color) {
    final isSelected = _testFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _testFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? color : Colors.grey.shade300, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}