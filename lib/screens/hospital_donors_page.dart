import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'city_helper.dart';

class HospitalDonorsPage extends StatefulWidget {
  const HospitalDonorsPage({super.key});

  @override
  State<HospitalDonorsPage> createState() => _HospitalDonorsPageState();
}

class _HospitalDonorsPageState extends State<HospitalDonorsPage> {
  List<Map<String, dynamic>> donors = [];
  List<Map<String, dynamic>> filtered = [];
  String hospitalCityAr = "";
  bool isLoading = true;
  String searchQuery = "";
  String? selectedBloodFilter;

  Map<String, String> _requestHospitalMap = {};

  @override
  void initState() {
    super.initState();
    _loadDonors();
  }

  Future<void> _loadDonors() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final hospSnap =
        await FirebaseDatabase.instance.ref("Hospitals/${user.uid}").get();

    if (hospSnap.exists && hospSnap.value is Map) {
      final hospData = Map<String, dynamic>.from(hospSnap.value as Map);
      hospitalCityAr = CityHelper.normalize(hospData['city']?.toString());
    }

    final reqSnap = await FirebaseDatabase.instance.ref("Requests").get();
    if (reqSnap.exists && reqSnap.value is Map) {
      final reqData = Map<String, dynamic>.from(reqSnap.value as Map);
      reqData.forEach((key, value) {
        final req = Map<String, dynamic>.from(value);
        _requestHospitalMap[key] =
            req['hospitalName']?.toString() ?? "غير محدد";
      });
    }

    FirebaseDatabase.instance.ref("Donors").onValue.listen((event) {
      final data = event.snapshot.value;

      if (data is Map) {
        final donorsMap = Map<String, dynamic>.from(data);

        List<Map<String, dynamic>> temp = [];

        donorsMap.forEach((key, value) {
          final donor = Map<String, dynamic>.from(value);

          final donorCityAr = CityHelper.normalize(donor['city']?.toString());

          if (donorCityAr == hospitalCityAr) {
            donor['_key'] = key;

            final donations = donor['donations'];
            List<String> hospitals = [];

            if (donations is Map) {
              final donMap = Map<String, dynamic>.from(donations);

              donMap.keys.forEach((reqId) {
                final hospName = _requestHospitalMap[reqId];
                if (hospName != null && !hospitals.contains(hospName)) {
                  hospitals.add(hospName);
                }
              });
            }

            donor['_donatedHospitals'] = hospitals;
            temp.add(donor);
          }
        });

        setState(() {
          donors = temp;
          filtered = temp;
          isLoading = false;
        });
      }
    });
  }

  void _applyFilter() {
    setState(() {
      filtered = donors.where((d) {
        final name = d['fullName']?.toString().toLowerCase() ?? "";
        final blood = d['bloodType']?.toString() ?? "";

        final matchSearch =
            searchQuery.isEmpty || name.contains(searchQuery.toLowerCase());

        final matchBlood =
            selectedBloodFilter == null || blood == selectedBloodFilter;

        return matchSearch && matchBlood;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        title: Text(
          "المتبرعون${hospitalCityAr.isNotEmpty ? ' - $hospitalCityAr' : ''}",
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : Column(
              children: [
                _buildSearchAndFilter(),
                _buildCount(),
                Expanded(child: _buildDonorList()),
              ],
            ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            onChanged: (v) {
              searchQuery = v;
              _applyFilter();
            },
            decoration: InputDecoration(
              hintText: "ابحث باسم المتبرع...",
              prefixIcon: const Icon(Icons.search, color: Colors.red),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip("الكل", null),
                ...["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"]
                    .map((b) => _filterChip(b, b)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCount() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text("${filtered.length} متبرع"),
      ),
    );
  }

  Widget _buildDonorList() {
    if (filtered.isEmpty) {
      return const Center(child: Text("لا يوجد متبرعين"));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final donor = filtered[index];

        return Card(
          child: ListTile(
            title: Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: Colors.red),
                const SizedBox(width: 6),

                Expanded(
                  child: Text(
                    donor['fullName'] ?? "غير محدد",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),

                // 🩸 فصيلة الدم
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 253, 55, 85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    donor['bloodType'] ?? "?",
                    style: const TextStyle(
                      color: Color.fromARGB(255, 243, 175, 170),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  donor['city'] ?? "",
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            onTap: () => _showDonorCard(context, donor),
          ),
        );
      },
    );
  }

  Widget _filterChip(String label, String? value) {
    final isSelected = selectedBloodFilter == value;

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() => selectedBloodFilter = value);
          _applyFilter();
        },
      ),
    );
  }

  void _showDonorCard(BuildContext context, Map<String, dynamic> donor) {
    showDialog(
      context: context,
      builder: (_) => DonorCard(donor: donor),
    );
  }
}

/* =========================
        DONOR CARD
========================= */

class DonorCard extends StatefulWidget {
  final Map<String, dynamic> donor;

  const DonorCard({super.key, required this.donor});

  @override
  State<DonorCard> createState() => _DonorCardState();
}

class _DonorCardState extends State<DonorCard> {
  late TextEditingController phoneController;
  late TextEditingController diseaseController;
  late TextEditingController lastDonationController;
  late TextEditingController hospitalNoteController;

  @override
  void initState() {
    super.initState();

    phoneController = TextEditingController(text: widget.donor['phone'] ?? "");

    diseaseController = TextEditingController(
      text: widget.donor['diseaseName'] ?? widget.donor['diseaseDetails'] ?? "",
    );

    lastDonationController =
        TextEditingController(text: widget.donor['lastDonation'] ?? "");

    hospitalNoteController =
        TextEditingController(text: widget.donor['hospitalNote'] ?? "");
  }

  @override
  void dispose() {
    phoneController.dispose();
    diseaseController.dispose();
    lastDonationController.dispose();
    hospitalNoteController.dispose();
    super.dispose();
  }

  Widget _buildField(String title, TextEditingController controller,
      {TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            keyboardType: type,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> donatedHospitals =
        List<String>.from(widget.donor['_donatedHospitals'] ?? []);

    final hasDisease = widget.donor['hasDiseases'] == true ||
        widget.donor['hasDisease'] == true;

    bool eligibleByTime = true;

    if (widget.donor['lastDonation'] != null &&
        widget.donor['lastDonation'].toString().isNotEmpty) {
      try {
        final lastDate =
            DateTime.parse(widget.donor['lastDonation'].toString());

        final diffMonths =
            (DateTime.now().difference(lastDate).inDays / 30).floor();

        eligibleByTime = diffMonths >= 4;
      } catch (_) {
        eligibleByTime = true;
      }
    }

    final canDonate = !hasDisease && eligibleByTime;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      title: Text(widget.donor['fullName'] ?? "غير محدد"),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("🩸 فصيلة الدم: ${widget.donor['bloodType'] ?? '?'}"),
            Text("📍 المدينة: ${widget.donor['city'] ?? 'غير محدد'}"),
            Text("عدد التبرعات: ${widget.donor['donationCount'] ?? '0'}"),

            const SizedBox(height: 15),

            // ✅ مرتبين زي قبل
            _buildField("📞 رقم الهاتف", phoneController,
                type: TextInputType.phone),

            _buildField("🩺 الأمراض", diseaseController),

            _buildField("📅 آخر تبرع", lastDonationController),

            _buildField("📝 إضافة بيانات", hospitalNoteController),

            const SizedBox(height: 10),

            const Text(
              "🏥 المستشفيات التي تبرع فيها:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),

            donatedHospitals.isEmpty
                ? const Text("لم يتبرع بعد")
                : Wrap(
                    spacing: 10,
                    children: donatedHospitals
                        .map((h) => Chip(label: Text(h)))
                        .toList(),
                  ),

            const SizedBox(height: 10),

            Text(
              canDonate ? "✅ مؤهل للتبرع" : "❌ غير مؤهل للتبرع",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: canDonate ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("إغلاق"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            final key = widget.donor['_key'];

            await FirebaseDatabase.instance.ref("Donors/$key").update({
              "phone": phoneController.text,
              "diseaseName": diseaseController.text,
              "lastDonation": lastDonationController.text,
              "hospitalNote": hospitalNoteController.text,
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("تم حفظ التعديلات"),
              ),
            );

            Navigator.pop(context);
          },
          child: const Text("حفظ التعديلات"),
        ),
      ],
    );
  }
}