import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'city_helper.dart';

class BloodBankBroadcastPage extends StatefulWidget {
  const BloodBankBroadcastPage({super.key});

  @override
  State<BloodBankBroadcastPage> createState() => _BloodBankBroadcastPageState();
}

class _BloodBankBroadcastPageState extends State<BloodBankBroadcastPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String staffCity = "";
  String staffHospitalId = "";
  String staffHospitalName = "";
  bool isLoading = true;
  bool isSending = false;

  String? selectedBloodType;
  final TextEditingController _messageController = TextEditingController();
  String _urgencyLevel = "urgent";
  int _estimatedRecipients = 0;

  List<Map<String, dynamic>> _notifications = [];
  bool _notifLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStaffData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadStaffData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final staffSnap =
        await FirebaseDatabase.instance.ref("BloodBankStaff/$uid").get();
    if (staffSnap.exists && staffSnap.value is Map) {
      final data = Map<String, dynamic>.from(staffSnap.value as Map);
      staffCity = CityHelper.normalize(data['city']?.toString());
      staffHospitalId = data['hospitalId']?.toString() ?? "";

      if (staffHospitalId.isNotEmpty) {
        final hospSnap = await FirebaseDatabase.instance
            .ref("Hospitals/$staffHospitalId")
            .get();
        if (hospSnap.exists && hospSnap.value is Map) {
          final hospData = Map<String, dynamic>.from(hospSnap.value as Map);
          staffHospitalName = hospData['hospitalName']?.toString() ?? "";
        }
      }
    }

    await _countRecipients();
    setState(() => isLoading = false);

    _listenToNotifications();
  }

  void _listenToNotifications() {
    if (staffHospitalId.isEmpty) return;

    FirebaseDatabase.instance
        .ref("Notifications/$staffHospitalId")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        setState(() {
          _notifications = [];
          _unreadCount = 0;
          _notifLoading = false;
        });
        return;
      }

      final map = Map<String, dynamic>.from(event.snapshot.value as Map);
      final list = map.entries.map((e) {
        final n = Map<String, dynamic>.from(e.value as Map);
        n['_key'] = e.key;
        return n;
      }).toList();

      list.sort((a, b) {
        final aT = a['createdAt'] ?? 0;
        final bT = b['createdAt'] ?? 0;
        return (bT is int ? bT : 0).compareTo(aT is int ? aT : 0);
      });

      setState(() {
        _notifications = list;
        _unreadCount = list.where((n) => n['isRead'] == false).length;
        _notifLoading = false;
      });
    });
  }

  Future<void> _markAsRead(String key) async {
    await FirebaseDatabase.instance
        .ref("Notifications/$staffHospitalId/$key")
        .update({'isRead': true});
  }

  Future<void> _markAllAsRead() async {
    final updates = <String, dynamic>{};
    for (final n in _notifications) {
      if (n['isRead'] == false) {
        updates["Notifications/$staffHospitalId/${n['_key']}/isRead"] = true;
      }
    }
    if (updates.isNotEmpty) {
      await FirebaseDatabase.instance.ref().update(updates);
    }
  }

  Future<void> _countRecipients() async {
    final donorsSnap = await FirebaseDatabase.instance.ref("Donors").get();
    if (!donorsSnap.exists || donorsSnap.value is! Map) return;

    int count = 0;
    Map<String, dynamic>.from(donorsSnap.value as Map).forEach((key, value) {
      final donor = Map<String, dynamic>.from(value);
      final city = CityHelper.normalize(donor['city']?.toString());
      final blood = donor['bloodType']?.toString() ?? "";

      if (city != staffCity) return;
      if (selectedBloodType != null && blood != selectedBloodType) return;
      count++;
    });

    setState(() => _estimatedRecipients = count);
  }

  Future<void> _sendBroadcast() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("يرجى كتابة رسالة الإشعار"),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.broadcast_on_personal, color: Colors.red),
          SizedBox(width: 8),
          Text("تأكيد الإرسال"),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                "سيصل هذا الإشعار لـ $_estimatedRecipients متبرع في $staffCity"
                "${selectedBloodType != null ? ' (فصيلة $selectedBloodType فقط)' : ''}."),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _messageController.text.trim(),
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("إرسال الآن",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => isSending = true);

    try {
      final donorsSnap = await FirebaseDatabase.instance.ref("Donors").get();
      if (!donorsSnap.exists || donorsSnap.value is! Map) return;

      final message = _messageController.text.trim();
      final now = DateTime.now().millisecondsSinceEpoch;
      int sentCount = 0;
      final updates = <String, dynamic>{};

      Map<String, dynamic>.from(donorsSnap.value as Map).forEach((key, value) {
        final donor = Map<String, dynamic>.from(value);
        final city = CityHelper.normalize(donor['city']?.toString());
        final blood = donor['bloodType']?.toString() ?? "";

        if (city != staffCity) return;
        if (selectedBloodType != null && blood != selectedBloodType) return;

        final pushKey = FirebaseDatabase.instance
            .ref("Donors/$key/notifications")
            .push()
            .key;

        updates["Donors/$key/notifications/$pushKey"] = {
          'message': _urgencyLevel == "urgent"
              ? "🚨 [عاجل] $message"
              : "📢 $message",
          'isRead': false,
          'createdAt': now,
          'type': _urgencyLevel == "urgent" ? "urgent" : "info",
          'from': staffHospitalName,
        };
        sentCount++;
      });

      if (updates.isNotEmpty) {
        await FirebaseDatabase.instance.ref().update(updates);
      }

      await FirebaseDatabase.instance
          .ref("Hospitals/$staffHospitalId/broadcastHistory")
          .push()
          .set({
        'message': message,
        'sentAt': now,
        'recipientsCount': sentCount,
        'bloodType': selectedBloodType ?? 'الكل',
        'urgency': _urgencyLevel,
        'city': staffCity,
      });

      if (mounted) {
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ تم إرسال الإشعار لـ $sentCount متبرع"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  IconData _notifIcon(String type) {
    switch (type) {
      case "donor_arrived":
        return Icons.directions_walk;
      case "donation_confirmed":
        return Icons.bloodtype;
      case "new_test":
        return Icons.science_outlined;
      case "manual_donation":
        return Icons.edit_note;
      case "new_request":
        return Icons.add_circle_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _notifColor(String type) {
    switch (type) {
      case "donor_arrived":
        return Colors.green;
      case "donation_confirmed":
        return Colors.red;
      case "new_test":
        return Colors.orange;
      case "manual_donation":
        return Colors.blue;
      case "new_request":
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _notifTypeLabel(String type) {
    switch (type) {
      case "donor_arrived":
        return "متبرع وصل";
      case "donation_confirmed":
        return "تبرع مؤكد";
      case "new_test":
        return "فحص جديد";
      case "manual_donation":
        return "تبرع يدوي";
      case "new_request":
        return "طلب جديد";
      default:
        return "إشعار";
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return "";
    try {
      if (ts is int) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        return "${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      }
      return ts.toString();
    } catch (_) {
      return "";
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
        title: const Text("الإشعارات",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                  Icon(Icons.broadcast_on_personal, size: 18),
                  SizedBox(width: 6),
                  Text("إرسال إشعار"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox, size: 18),
                  const SizedBox(width: 6),
                  Text("الوارد${_unreadCount > 0 ? ' 🔴' : ''}"),
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
                _buildSendTab(),
                _buildInboxTab(),
              ],
            ),
    );
  }

  Widget _buildSendTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.broadcast_on_personal,
                        color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text("إرسال إشعار جماعي",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "المدينة: $staffCity — المستشفى: $staffHospitalName",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text("فصيلة الدم المستهدفة",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _bloodChip("الكل 🩸", null),
              ...["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"]
                  .map((b) => _bloodChip(b, b)),
            ],
          ),

          const SizedBox(height: 20),

          const Text("مستوى الأولوية",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              _urgencyChip("urgent", "عاجل 🚨", Colors.red),
              const SizedBox(width: 10),
              _urgencyChip("normal", "عادي 📢", Colors.blue),
            ],
          ),

          const SizedBox(height: 20),

          const Text("نص الرسالة",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: _messageController,
            maxLines: 4,
            maxLength: 200,
            decoration: InputDecoration(
              hintText:
                  "مثال: نحتاج متبرعين عاجلاً لفصيلة O+ في قسم الطوارئ...",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  "سيصل الإشعار لـ $_estimatedRecipients متبرع",
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.white),
              label: Text(
                isSending ? "جاري الإرسال..." : "إرسال الإشعار",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
              onPressed: isSending ? null : _sendBroadcast,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInboxTab() {
    if (_notifLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, color: Colors.grey.shade300, size: 70),
            const SizedBox(height: 14),
            Text("لا يوجد إشعارات",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_unreadCount > 0)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$_unreadCount غير مقروء",
                    style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _markAllAsRead,
                  icon:
                      const Icon(Icons.done_all, size: 18, color: Colors.grey),
                  label: const Text("تحديد الكل كمقروء",
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ],
            ),
          ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _notifications.length,
            itemBuilder: (context, index) {
              final n = _notifications[index];
              final type = n['type']?.toString() ?? "";
              final isRead = n['isRead'] == true;
              final key = n['_key']?.toString() ?? "";
              final color = _notifColor(type);

              return GestureDetector(
                onTap: () {
                  if (!isRead) _markAsRead(key);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isRead
                          ? Colors.grey.shade200
                          : color.withOpacity(0.4),
                      width: isRead ? 1 : 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_notifIcon(type), color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _notifTypeLabel(type),
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (!isRead) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              n['title']?.toString() ?? "",
                              style: TextStyle(
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              n['message']?.toString() ?? "",
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatTimestamp(n['createdAt']),
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _bloodChip(String label, String? value) {
    final isSelected = selectedBloodType == value;
    return GestureDetector(
      onTap: () async {
        setState(() => selectedBloodType = value);
        await _countRecipients();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? Colors.red : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.red : Colors.black87,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _urgencyChip(String value, String label, Color color) {
    final isSelected = _urgencyLevel == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _urgencyLevel = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
                width: isSelected ? 2 : 1),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: isSelected ? color : Colors.grey,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15)),
          ),
        ),
      ),
    );
  }
}