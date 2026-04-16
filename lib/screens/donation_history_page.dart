import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class DonationHistoryPage extends StatefulWidget {
  const DonationHistoryPage({super.key});

  @override
  State<DonationHistoryPage> createState() => _DonationHistoryPageState();
}

class _DonationHistoryPageState extends State<DonationHistoryPage> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseDatabase.instance
        .ref("Donors/${user.uid}/donations")
        .get();

    if (!snap.exists || snap.value is! Map) {
      setState(() => _loading = false);
      return;
    }

    final donations = Map<String, dynamic>.from(snap.value as Map);
    List<Map<String, dynamic>> temp = [];

    for (final entry in donations.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is Map) {
        final item = Map<String, dynamic>.from(value);
        item['requestId'] = key;

        // ── تبرع يدوي من الستاف ───────────────────────
        if (key.startsWith('manual_') || item['confirmedByStaff'] == true) {
          item['isManual'] = true;
        } else {
          item['isManual'] = false;
        }

        temp.add(item);
      } else if (value == true) {
        // ── تبرع قديم محفوظ كـ true ──────────────────
        final reqSnap =
            await FirebaseDatabase.instance.ref("Requests/$key").get();

        if (reqSnap.exists && reqSnap.value is Map) {
          final reqData = Map<String, dynamic>.from(reqSnap.value as Map);
          temp.add({
            'requestId': key,
            'hospitalName': reqData['hospitalName'] ?? 'غير محدد',
            'department': reqData['department'] ?? 'غير محدد',
            'bloodType': reqData['bloodType'] ?? 'غير محدد',
            'city': reqData['city'] ?? 'غير محدد',
            'date': 'غير محدد',
            'confirmedAt': reqData['confirmedAt'] ?? '',
            'isManual': false,
          });
        } else {
          temp.add({
            'requestId': key,
            'hospitalName': 'غير متوفر',
            'department': 'غير متوفر',
            'bloodType': 'غير متوفر',
            'city': 'غير متوفر',
            'date': 'غير متوفر',
            'confirmedAt': '',
            'isManual': false,
          });
        }
      }
    }

    // ترتيب من الأحدث للأقدم
    temp.sort((a, b) {
      final aDate = a['confirmedAt']?.toString() ?? "";
      final bDate = b['confirmedAt']?.toString() ?? "";
      return bDate.compareTo(aDate);
    });

    setState(() {
      _history = temp;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        title: const Text(
          "سجل تبرعاتي",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _history.isEmpty
              ? _buildEmpty()
              : Column(
                  children: [
                    // ── ملخص عدد التبرعات ──────────────────────
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite,
                              color: Colors.white, size: 36),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${_history.length}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                "إجمالي تبرعاتك",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          return _buildDonationCard(item, index + 1);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildDonationCard(Map<String, dynamic> item, int number) {
    final bool isManual = item['isManual'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── رقم التبرع ──────────────────────────────────
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isManual ? Colors.blue : Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  "$number",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // ── شارة "تبرع خارجي" للتبرعات اليدوية ────
                  if (isManual)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "تبرع خارج التطبيق",
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.verified, color: Colors.blue, size: 14),
                        ],
                      ),
                    ),

                  if (!isManual) ...[
                    Text(
                      item['hospitalName'] ?? 'غير محدد',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 6),
                    _detailRow(Icons.medical_services,
                        item['department'] ?? 'غير محدد'),
                    _detailRow(Icons.location_on, item['city'] ?? 'غير محدد'),
                    _detailRow(
                        Icons.water_drop, item['bloodType'] ?? 'غير محدد'),
                  ],

                  _detailRow(Icons.calendar_today, item['date'] ?? 'غير محدد'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(width: 6),
          Icon(icon, color: Colors.red, size: 16),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            "لا يوجد تبرعات سابقة",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "تبرعاتك القادمة ستظهر هنا 🩸",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}