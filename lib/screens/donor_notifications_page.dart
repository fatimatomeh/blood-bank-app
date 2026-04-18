import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// صفحة إشعارات المتبرع
/// تقرأ من: Donors/{uid}/notification  (إشعار واحد حالي)
class DonorNotificationsPage extends StatefulWidget {
  const DonorNotificationsPage({super.key});

  @override
  State<DonorNotificationsPage> createState() =>
      _DonorNotificationsPageState();
}

class _DonorNotificationsPageState extends State<DonorNotificationsPage> {
  // قائمة الإشعارات المعروضة (نبني منها list من الـ notification field)
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // نستمع للتغييرات على بيانات المتبرع
    FirebaseDatabase.instance
        .ref("Donors/$uid")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        setState(() => isLoading = false);
        return;
      }

      final data =
          Map<String, dynamic>.from(event.snapshot.value as Map);
      final List<Map<String, dynamic>> temp = [];

      // ── الإشعار الحالي المحفوظ كـ field ──────────────────
      final notif = data['notification'];
      if (notif is Map) {
        final n = Map<String, dynamic>.from(notif);
        n['_id'] = 'notification';
        temp.add(n);
      }

      // ── أرشيف الإشعارات إذا موجود ─────────────────────────
      final archive = data['notificationsArchive'];
      if (archive is Map) {
        Map<String, dynamic>.from(archive).forEach((key, value) {
          if (value is Map) {
            final n = Map<String, dynamic>.from(value);
            n['_id'] = key;
            temp.add(n);
          }
        });
      }

      // ترتيب: الأحدث أول
      temp.sort((a, b) {
        final aDate = a['createdAt']?.toString() ?? "";
        final bDate = b['createdAt']?.toString() ?? "";
        return bDate.compareTo(aDate);
      });

      setState(() {
        notifications = temp;
        isLoading = false;
      });
    });
  }

  Future<void> _markAsRead(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (id == 'notification') {
      await FirebaseDatabase.instance
          .ref("Donors/$uid/notification/isRead")
          .set(true);
    } else {
      await FirebaseDatabase.instance
          .ref("Donors/$uid/notificationsArchive/$id/isRead")
          .set(true);
    }
  }

  Future<void> _deleteNotification(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (id == 'notification') {
      await FirebaseDatabase.instance
          .ref("Donors/$uid/notification")
          .remove();
    } else {
      await FirebaseDatabase.instance
          .ref("Donors/$uid/notificationsArchive/$id")
          .remove();
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'success':
        return Icons.check_circle;
      case 'error':
        return Icons.cancel;
      case 'urgent':
        return Icons.warning_amber;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'success':
        return Colors.green;
      case 'error':
        return Colors.red;
      case 'urgent':
        return Colors.orange;
      case 'info':
        return Colors.blue;
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
        title: const Text("الإشعارات",
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.white),
              tooltip: "تعليم الكل مقروء",
              onPressed: () async {
                for (final n in notifications) {
                  if (n['isRead'] != true) {
                    await _markAsRead(n['_id']?.toString() ?? "");
                  }
                }
              },
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
                    final id = n['_id']?.toString() ?? "";
                    final isRead = n['isRead'] == true;
                    final type = n['type']?.toString() ?? "";
                    final message = n['message']?.toString() ?? "";
                    final date = n['createdAt']?.toString() ?? "";
                    final from = n['from']?.toString() ?? "";

                    return Dismissible(
                      key: Key(id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child:
                            const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteNotification(id),
                      child: GestureDetector(
                        onTap: () => _markAsRead(id),
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
                                            Text(
                                              "من: $from",
                                              style: TextStyle(
                                                  color:
                                                      Colors.grey.shade600,
                                                  fontSize: 12),
                                            ),
                                            const SizedBox(width: 10),
                                          ],
                                          if (date.isNotEmpty)
                                            Text(
                                              date,
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
          Icon(Icons.notifications_none,
              size: 70, color: Colors.grey.shade400),
          const SizedBox(height: 15),
          const Text("لا يوجد إشعارات",
              style: TextStyle(fontSize: 16, color: Colors.black54)),
        ],
      ),
    );
  }
}