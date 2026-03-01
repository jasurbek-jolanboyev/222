import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/verified_name.dart';
// To'g'ri import yo'llari
import '../providers/chat_provider.dart';
import 'chat_screen.dart';
// import 'group_chat_screen.dart'; // Agar guruh faylingiz tayyor bo'lsa yoqing

class UserInfoScreen extends StatefulWidget {
  final String userId;

  const UserInfoScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  // ---------------- VAQTNI FORMATLASH ----------------
  String _formatLastSeen(dynamic lastSeen, bool isOnline) {
    if (isOnline) return "onlayn";
    try {
      if (lastSeen == null) return "yaqinda bo'lgan";
      final DateTime date =
          lastSeen is Timestamp ? lastSeen.toDate() : lastSeen as DateTime;
      final diff = DateTime.now().difference(date);

      if (diff.inMinutes < 1) return "hozirgina";
      if (diff.inMinutes < 60) return "${diff.inMinutes} daqiqa oldin";
      if (diff.inHours < 24) return "${diff.inHours} soat oldin";
      return "oxirgi marta: ${DateFormat('dd.MM.yyyy HH:mm').format(date)}";
    } catch (_) {
      return "yaqinda bo'lgan";
    }
  }

  // ---------------- FONNI ALMASHTIRISH ----------------
  void _showThemePicker() {
    final provider = Provider.of<ChatProvider>(context, listen: false);

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text("Chat fonini tanlang"),
        actions: [
          _themeOption("Klassik", ChatThemeType.classic, provider),
          _themeOption("Kiber (Neon)", ChatThemeType.cyber, provider),
          _themeOption("Matritsa", ChatThemeType.matrix, provider),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text("Bekor qilish"),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _themeOption(String title, ChatThemeType type, ChatProvider provider) {
    return CupertinoActionSheetAction(
      child: Text(title),
      onPressed: () async {
        provider.updateChatTheme(type);
        // Firebase'ga saqlash (ixtiyoriy, chat xonasi ID si kerak bo'ladi)
        Navigator.pop(context);
        _showSnackBar("Mavzu o'zgartirildi: $title");
      },
    );
  }

  // ---------------- ASOSIY FUNKSIYALAR ----------------

  Future<void> _handleCall(String phone) async {
    if (phone.isEmpty || phone == "Kiritilmagan") {
      _showSnackBar("Telefon raqami mavjud emas", isError: true);
      return;
    }
    final Uri uri = Uri.parse("tel:${phone.replaceAll(RegExp(r'[^\d+]'), '')}");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnackBar("Qo'ng'iroqni amalga oshirib bo'lmadi", isError: true);
      }
    } catch (e) {
      _showSnackBar("Xatolik: $e", isError: true);
    }
  }

  void _shareProfile(String name) {
    HapticFeedback.lightImpact();
    Share.share(
        "Cyber Com foydalanuvchisi: $name\nProfil: https://cybercom.uz/u/$name");
  }

  Future<void> _toggleBlock(bool isAlreadyBlocked) async {
    HapticFeedback.mediumImpact();
    final DocumentReference myDoc =
        FirebaseFirestore.instance.collection("users").doc(currentUserId);
    try {
      if (isAlreadyBlocked) {
        await myDoc.update({
          "blockedUsers": FieldValue.arrayRemove([widget.userId])
        });
        _showSnackBar("Foydalanuvchi blokdan chiqarildi");
      } else {
        await myDoc.update({
          "blockedUsers": FieldValue.arrayUnion([widget.userId])
        });
        _showSnackBar("Foydalanuvchi bloklandi", isError: true);
      }
    } catch (e) {
      _showSnackBar("Amaliyot bajarilmadi", isError: true);
    }
  }

  void _goToChat(Map<String, dynamic> userData) {
    HapticFeedback.selectionClick();
    String roomId = currentUserId.hashCode <= widget.userId.hashCode
        ? "${currentUserId}_${widget.userId}"
        : "${widget.userId}_$currentUserId";

    Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => ChatScreen(
            roomId: roomId,
            otherUserId: widget.userId,
            otherUsername: userData["username"] ?? "User",
            otherAvatar: userData["avatar"] ?? "",
          ),
        ));
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: isError ? Colors.redAccent : Colors.blueAccent,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(widget.userId)
          .snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData || !userSnap.data!.exists) {
          return const Scaffold(
              body: Center(child: CupertinoActivityIndicator()));
        }

        final userData = userSnap.data!.data() as Map<String, dynamic>;
        final String name = userData["username"] ?? "User";
        final String? avatar = userData["avatar"];
        final bool isOnline = userData["online"] ?? false;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("users")
              .doc(currentUserId)
              .snapshots(),
          builder: (context, meSnap) {
            final myData = meSnap.data?.data() as Map<String, dynamic>? ?? {};
            final bool isBlocked =
                List.from(myData["blockedUsers"] ?? []).contains(widget.userId);

            return Scaffold(
              backgroundColor:
                  isDark ? const Color(0xFF0E1621) : const Color(0xFFF1F5F9),
              body: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(
                      name, avatar, isOnline, userData, isBlocked, isDark),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _quickAction(CupertinoIcons.chat_bubble_fill, "Xabar",
                              Colors.blue, () => _goToChat(userData)),
                          _quickAction(
                              CupertinoIcons.phone_fill,
                              "Qo'ng'iroq",
                              Colors.green,
                              () => _handleCall(userData['phone'] ?? "")),
                          _quickAction(CupertinoIcons.paintbrush_fill, "Mavzu",
                              Colors.purple, _showThemePicker),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF17212B) : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10)
                        ],
                      ),
                      child: Column(
                        children: [
                          _infoTile(
                              userData['phone'] ?? "Kiritilmagan",
                              "Mobil raqam",
                              CupertinoIcons.phone,
                              isDark, onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: userData['phone'] ?? ""));
                            _showSnackBar("Raqam nusxalandi");
                          }),
                          const Divider(height: 1, indent: 60),
                          _infoTile("@$name", "Foydalanuvchi nomi",
                              CupertinoIcons.at, isDark, onTap: () {
                            Clipboard.setData(ClipboardData(text: "@$name"));
                            _showSnackBar("Username nusxalandi");
                          }),
                          const Divider(height: 1, indent: 60),
                          _infoTile(
                              userData['bio'] ?? "Cyber security ishqibozi",
                              "Tarjimayi hol",
                              CupertinoIcons.info_circle,
                              isDark),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 25, 20, 10),
                      child: Text("YARATILGAN GURUHLAR",
                          style: TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.2)),
                    ),
                  ),
                  _buildUserCreatedGroups(isDark),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSliverAppBar(String name, String? url, bool online,
      Map<String, dynamic> data, bool isBlocked, bool isDark) {
    return SliverAppBar(
      expandedHeight: 350,
      pinned: true,
      stretch: true,
      backgroundColor: isDark ? const Color(0xFF17212B) : Colors.blueAccent,
      actions: [
        IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => _shareProfile(name)),
        IconButton(
            icon: Icon(isBlocked ? Icons.lock_open : Icons.block,
                color: Colors.redAccent),
            onPressed: () => _toggleBlock(isBlocked)),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground
        ],
        titlePadding: const EdgeInsetsDirectional.only(start: 60, bottom: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start, // Chapga tekislash
          mainAxisSize: MainAxisSize.min,
          children: [
            VerifiedName(
              username: name,
              isVerified: data['isVerified'] ?? false,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white),
              iconSize: 16,
            ),
            Text(_formatLastSeen(data["lastSeen"], online),
                style: TextStyle(
                    fontSize: 11,
                    color: online ? Colors.blue[100] : Colors.white70)),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url ?? "",
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                  color: Colors.blueGrey,
                  child: const Icon(Icons.person,
                      size: 80, color: Colors.white24)),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.6, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCreatedGroups(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('ownerId', isEqualTo: widget.userId)
          .where('isGroup', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const SliverToBoxAdapter(child: SizedBox());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color:
                      isDark ? Colors.white10 : Colors.black.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(15)),
              child: const Center(
                  child: Text("Hali guruhlar yaratmagan",
                      style: TextStyle(color: Colors.grey, fontSize: 13))),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final group = docs[index].data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF17212B) : Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: group['groupAvatar'] != null
                        ? CachedNetworkImageProvider(group['groupAvatar'])
                        : null,
                    child: group['groupAvatar'] == null
                        ? const Icon(Icons.group)
                        : null,
                  ),
                  title: Text(group['groupName'] ?? "Guruh",
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text("${(group['users'] as List).length} a'zo",
                      style: const TextStyle(
                          fontSize: 12, color: Colors.blueAccent)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    // Navigator.push(context, CupertinoPageRoute(builder: (_) => GroupChatScreen(roomId: docs[index].id, groupName: group['groupName'])));
                  },
                ),
              );
            },
            childCount: docs.length,
          ),
        );
      },
    );
  }

  Widget _quickAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Column(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _infoTile(String title, String subtitle, IconData icon, bool isDark,
      {VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.blueAccent, size: 22),
      title: Text(title,
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 11)),
      trailing: onTap != null
          ? const Icon(Icons.copy_rounded, size: 16, color: Colors.grey)
          : null,
    );
  }
}
