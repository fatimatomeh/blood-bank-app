import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// صفحة إشعارات المستشفى
/// تقرأ من: Notifications/{hospitalId}/{pushKey}
class HospitalNotificationsPage extends StatefulWidget {
  const HospitalNotificationsPage({super.key});

  @override
  State<HospitalNotificationsPage> createState() =>
      _HospitalNotificationsPageState();
}

class _HospitalNotificationsPageState extends State<HospitalNotificationsPage> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  String hospitalId = "";

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    hospitalId = uid;

    FirebaseDatabase.instance
        .ref("Notifications/$hospitalId")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        setState(() {
          notifications = [];
          isLoading = false;
        });
        return;
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      List<Map<String, dynamic>> temp = [];

      data.forEach((key, value) {
        if (value is Map) {
          final n = Map<String, dynamic>.from(value);
          n['_key'] = key;
          temp.add(n);
        }
      });

      // ترتيب: الأحدث أول (createdAt timestamp)
      temp.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];
        if (aTime is int && bTime is int) return bTime.compareTo(aTime);
        return 0;
      });

      setState(() {
        notifications = temp;
        isLoading = false;
      });
    });
  }

  Future<void> _markAsRead(String key) async {
    await FirebaseDatabase.instance
        .ref("Notifications/$hospitalId/$key/isRead")
        .set(true);
  }

  Future<void> _deleteNotification(String key) async {
    await FirebaseDatabase.instance
        .ref("Notifications/$hospitalId/$key")
        .remove();
  }

  Future<void> _markAllAsRead() async {
    for (final n in notifications) {
      if (n['isRead'] != true) {
        final key = n['_key']?.toString() ?? "";
        if (key.isNotEmpty) await _markAsRead(key);
      }
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'donation_confirmed':
        return Icons.favorite;
      case 'new_request':
        return Icons.add_circle;
      case 'manual_donation':
        return Icons.bloodtype;
      case 'urgent':
        return Icons.warning_amber;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'donation_confirmed':
        return Colors.green;
      case 'new_request':
        return Colors.blue;
      case 'manual_donation':
        return Colors.red;
      case 'urgent':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return "";
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
      return "";
    }
  }

  int get _unreadCount =>
      notifications.where((n) => n['isRead'] != true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.red,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("الإشعارات",
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$_unreadCount",
                  style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.white),
              tooltip: "تعليم الكل مقروء",
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : notifications.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    final key = n['_key']?.toString() ?? "";
                    final isRead = n['isRead'] == true;
                    final type = n['type']?.toString() ?? "";
                    final title = n['title']?.toString() ?? "";
                    final message = n['message']?.toString() ?? "";
                    final createdAt = n['createdAt'];

                    return Dismissible(
                      key: Key(key),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteNotification(key),
                      child: GestureDetector(
                        onTap: () {
                          if (!isRead) _markAsRead(key);
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          color: isRead ? Colors.white : Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _typeColor(type).withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(_typeIcon(type),
                                      color: _typeColor(type), size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (title.isNotEmpty)
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: isRead
                                                ? FontWeight.w600
                                                : FontWeight.bold,
                                          ),
                                        ),
                                      if (message.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          message,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatTimestamp(createdAt),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 70, color: Colors.grey.shade400),
          const SizedBox(height: 15),
          const Text("لا يوجد إشعارات",
              style: TextStyle(fontSize: 16, color: Colors.black54)),
        ],
      ),
    );
  }
}
