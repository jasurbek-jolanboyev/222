import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/verified_name.dart';
import '../chat_screen.dart';

class ChatTab extends StatelessWidget {
  final bool isSearching;
  final String searchText;
  final bool isSelectionMode;
  final Set<String> selectedItems;
  final Function(bool mode, String docId) onLongPress;
  final Function(String docId) onTap;

  const ChatTab({
    super.key,
    required this.isSearching,
    required this.searchText,
    required this.isSelectionMode,
    required this.selectedItems,
    required this.onLongPress,
    required this.onTap,
  });

  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: isSearching
          ? FirebaseFirestore.instance.collection('users').snapshots()
          : FirebaseFirestore.instance
              .collection('chats')
              .where('users', arrayContains: currentUserId)
              .where('isGroup', isEqualTo: false)
              .orderBy('lastTime', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text("Xatolik yuz berdi"));
        if (!snapshot.hasData)
          return const Center(child: CupertinoActivityIndicator());

        final docs = snapshot.data!.docs;

        if (isSearching) {
          if (searchText.trim().isEmpty)
            return _buildEmptyState("Qidirish uchun ism kiriting");
          final filteredUsers = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final username = (data['username'] ?? "").toString().toLowerCase();
            return doc.id != currentUserId &&
                username.contains(searchText.toLowerCase());
          }).toList();

          if (filteredUsers.isEmpty)
            return _buildEmptyState("Foydalanuvchi topilmadi");

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final data = filteredUsers[index].data() as Map<String, dynamic>;
              return _ModernUserSearchTile(
                userData: data,
                userId: filteredUsers[index].id,
                isDark: isDark,
                onStartChat: (id, name, avatar) =>
                    _startChat(context, id, name, avatar),
              );
            },
          );
        }

        if (docs.isEmpty) return _buildEmptyState("Suhbatlar mavjud emas");

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final docId = docs[index].id;
            final data = docs[index].data() as Map<String, dynamic>;
            final List users = data['users'] ?? [];
            final otherId =
                users.firstWhere((id) => id != currentUserId, orElse: () => "");
            final bool isSelected = selectedItems.contains(docId);

            return GestureDetector(
              onLongPress: () => onLongPress(true, docId),
              onTap: isSelectionMode ? () => onTap(docId) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: isSelected
                    ? Colors.blueAccent.withOpacity(0.15)
                    : Colors.transparent,
                child: AbsorbPointer(
                  absorbing: isSelectionMode,
                  child: _ModernChatTile(
                    otherUserId: otherId,
                    lastMessage: data['lastMessage'] ?? "Suhbatni boshlang",
                    roomId: docId,
                    lastTime: data['lastTime'],
                    isDark: isDark,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Yordamchi metodlar va Sub-widgetlar (HomeScreen'dan olingan)
  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.tray, size: 50, color: Colors.grey),
          const SizedBox(height: 10),
          Text(msg, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _startChat(BuildContext context, String otherId, String? name,
      String? avatar) async {
    String roomId = currentUserId.hashCode <= otherId.hashCode
        ? "${currentUserId}_$otherId"
        : "${otherId}_$currentUserId";

    await FirebaseFirestore.instance.collection('chats').doc(roomId).set({
      'users': [currentUserId, otherId],
      'isGroup': false,
      'lastTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!context.mounted) return;
    Navigator.push(
        context,
        CupertinoPageRoute(
            builder: (_) => ChatScreen(
                  roomId: roomId,
                  otherUserId: otherId,
                  otherUsername: name ?? "Foydalanuvchi",
                  otherAvatar: avatar ?? "",
                )));
  }
}

// _ModernChatTile va _ModernUserSearchTile larni ham shu yerga pastdan qo'shib qo'ying...
// ... ChatTab klassidan keyin
class _ModernChatTile extends StatelessWidget {
  final String otherUserId, lastMessage, roomId;
  final dynamic lastTime;
  final bool isDark;
  const _ModernChatTile(
      {required this.otherUserId,
      required this.lastMessage,
      required this.roomId,
      this.lastTime,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final user = snap.data!.data() as Map<String, dynamic>? ?? {};
        return ListTile(
          onTap: () => Navigator.push(
              context,
              CupertinoPageRoute(
                  builder: (_) => ChatScreen(
                      roomId: roomId,
                      otherUserId: otherUserId,
                      otherUsername: user['username'] ?? "Foydalanuvchi",
                      otherAvatar: user['avatar'] ?? ""))),
          leading: CircleAvatar(
            backgroundImage: user['avatar'] != null && user['avatar'] != ""
                ? CachedNetworkImageProvider(user['avatar'])
                : null,
            child: user['avatar'] == null || user['avatar'] == ""
                ? const Icon(Icons.person)
                : null,
          ),
          title: VerifiedName(
              username: user['username'] ?? "Foydalanuvchi",
              isVerified: user['isVerified'] ?? false),
          subtitle:
              Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(
              lastTime != null
                  ? DateFormat('HH:mm').format((lastTime as Timestamp).toDate())
                  : "",
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        );
      },
    );
  }
}

class _ModernUserSearchTile extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String userId;
  final bool isDark;
  final Function onStartChat;
  const _ModernUserSearchTile(
      {required this.userData,
      required this.userId,
      required this.isDark,
      required this.onStartChat});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
          backgroundImage:
              CachedNetworkImageProvider(userData['avatar'] ?? "")),
      title: Text(userData['username'] ?? "Noma'lum"),
      trailing:
          const Icon(CupertinoIcons.chat_bubble_fill, color: Colors.blueAccent),
      onTap: () =>
          onStartChat(userId, userData['username'], userData['avatar']),
    );
  }
}
