import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
      // Ixcham iOS Navigation Bar
      appBar: CupertinoNavigationBar(
        middle: const Text("Bildirishnomalar",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
        backgroundColor: isDark
            ? Colors.black.withOpacity(0.7)
            : Colors.white.withOpacity(0.8),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.delete, size: 20),
          onPressed: () => _showClearConfirm(context, currentUserId),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.bell,
                      size: 40, color: Colors.grey.withOpacity(0.4)),
                  const SizedBox(height: 10),
                  Text("Bildirishnomalar yo'q",
                      style: TextStyle(
                          color: Colors.grey.withOpacity(0.6), fontSize: 15)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final String docId = docs[i].id;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildCompactNotificationCard(
                    context, data, docId, currentUserId, isDark),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCompactNotificationCard(BuildContext context,
      Map<String, dynamic> data, String docId, String userId, bool isDark) {
    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(userId, docId),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: CupertinoColors.systemRed,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(CupertinoIcons.trash, color: Colors.white, size: 18),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CupertinoColors.activeBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.bell_fill,
                  color: CupertinoColors.activeBlue, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        data['title'] ?? "Xabarnoma",
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        _formatTime(data['timestamp']),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data['body'] ?? "",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return "";
    DateTime date = (timestamp as Timestamp).toDate();
    return DateFormat('HH:mm').format(date);
  }

  void _deleteNotification(String userId, String docId) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(docId)
        .delete();
  }

  void _showClearConfirm(BuildContext context, String userId) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text("Tozalash"),
        message:
            const Text("Barcha bildirishnomalarni o'chirib tashlamoqchimisiz?"),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              _clearAllNotifications(userId);
              Navigator.pop(context);
            },
            child: const Text("Hammasini o'chirish"),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text("Bekor qilish"),
        ),
      ),
    );
  }

  void _clearAllNotifications(String userId) async {
    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications');
    final snapshots = await collection.get();
    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }
  }
}
