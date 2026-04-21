import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// صفحة إشعارات المتبرع
/// تقرأ من: Donors/{uid}/notifications/{pushKey}  ✅ يتراكم ولا يُمسح
class DonorNotificationsPage extends StatefulWidget {
  const DonorNotificationsPage({super.key});

  @override
  State<DonorNotificationsPage> createState() => _DonorNotificationsPageState();
}

class _DonorNotificationsPageState extends State<DonorNotificationsPage> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    _uid = FirebaseAuth.instance.currentUser?.uid;
    if (_uid == null) return;

    // ✅ نستمع للمسار الجديد notifications (جمع) بدل notification (مفرد)
    FirebaseDatabase.instance
        .ref("Donors/$_uid/notifications")
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
      final List<Map<String, dynamic>> temp = [];

      data.forEach((key, value) {
        if (value is Map) {
          final n = Map<String, dynamic>.from(value);
          n['_id'] = key;
          temp.add(n);
        }
      });

      // ترتيب: الأحدث أول
      temp.sort((a, b) {
        final aT = a['createdAt'] ?? 0;
        final bT = b['createdAt'] ?? 0;
        final aInt = aT is int ? aT : 0;
        final bInt = bT is int ? bT : 0;
        return bInt.compareTo(aInt);
      });

      setState(() {
        notifications = temp;
        isLoading = false;
      });
    });
  }

  Future<void> _markAsRead(String id) async {
    if (_uid == null) return;
    await FirebaseDatabase.instance
        .ref("Donors/$_uid/notifications/$id/isRead")
        .set(true);
  }

  Future<void> _markAllAsRead() async {
    if (_uid == null) return;
    final updates = <String, dynamic>{};
    for (final n in notifications) {
      if (n['isRead'] != true) {
        final id = n['_id']?.toString() ?? "";
        if (id.isNotEmpty) {
          updates["Donors/$_uid/notifications/$id/isRead"] = true;
        }
      }
    }
    if (updates.isNotEmpty) {
      await FirebaseDatabase.instance.ref().update(updates);
    }
  }

  Future<void> _deleteNotification(String id) async {
    if (_uid == null) return;
    await FirebaseDatabase.instance
        .ref("Donors/$_uid/notifications/$id")
        .remove();
  }

  int get _unreadCount =>
      notifications.where((n) => n['isRead'] != true).length;

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return "";
    try {
      if (ts is int) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        final day = dt.day.toString().padLeft(2, '0');
        final month = dt.month.toString().padLeft(2, '0');
        int hour = dt.hour;
        final minute = dt.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? "م" : "ص";
        hour = hour % 12;
        if (hour == 0) hour = 12;
        return "$day/$month/${dt.year} - ${hour.toString().padLeft(2, '0')}:$minute $period";
      }
      return ts.toString();
    } catch (_) {
      return "";
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'urgent':
        return Icons.warning_amber;
      case 'info':
        return Icons.info_outline;
      case 'success':
        return Icons.check_circle;
      case 'error':
        return Icons.cancel;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'urgent':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      case 'success':
        return Colors.green;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

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
              : Column(
                  children: [
                    // ── شريط غير المقروء ──
                    if (_unreadCount > 0)
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
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
                              icon: const Icon(Icons.done_all,
                                  size: 18, color: Colors.grey),
                              label: const Text("تحديد الكل كمقروء",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),

                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final n = notifications[index];
                          final id = n['_id']?.toString() ?? "";
                          final isRead = n['isRead'] == true;
                          final type = n['type']?.toString() ?? "";
                          final message = n['message']?.toString() ?? "";
                          final from = n['from']?.toString() ?? "";
                          final color = _typeColor(type);

                          return Dismissible(
                            key: Key(id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) => _deleteNotification(id),
                            child: GestureDetector(
                              onTap: () {
                                if (!isRead) _markAsRead(id);
                              },
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: isRead
                                        ? Colors.grey.shade200
                                        : color.withOpacity(0.4),
                                    width: isRead ? 1 : 1.5,
                                  ),
                                ),
                                color: isRead
                                    ? Colors.white
                                    : color.withOpacity(0.05),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(_typeIcon(type),
                                            color: color, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              message,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isRead
                                                    ? FontWeight.normal
                                                    : FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                if (from.isNotEmpty) ...[
                                                  Icon(Icons.local_hospital,
                                                      size: 12,
                                                      color:
                                                          Colors.grey.shade500),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    from,
                                                    style: TextStyle(
                                                        color: Colors
                                                            .grey.shade600,
                                                        fontSize: 12),
                                                  ),
                                                  const SizedBox(width: 10),
                                                ],
                                                Text(
                                                  _formatTimestamp(
                                                      n['createdAt']),
                                                  style: TextStyle(
                                                      color:
                                                          Colors.grey.shade500,
                                                      fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          width: 10,
                                          height: 10,
                                          margin: const EdgeInsets.only(top: 4),
                                          decoration: BoxDecoration(
                                            color: color,
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
                    ),
                  ],
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
