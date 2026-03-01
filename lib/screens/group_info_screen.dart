import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'user_info_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final String chatId;
  const GroupInfoScreen({Key? key, required this.chatId}) : super(key: key);

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
  bool _isUploading = false;

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _followFromInfo() async {
    HapticFeedback.mediumImpact();
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'users': FieldValue.arrayUnion([currentUserId]),
      });
      _showSnackBar("Guruhga obuna bo'ldingiz!");
    } catch (e) {
      _showSnackBar("Xatolik: $e", isError: true);
    }
  }

  void _editGroupName(String oldName) {
    final controller = TextEditingController(text: oldName);
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Guruh nomi"),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: controller,
            placeholder: "Yangi nom",
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Bekor qilish"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("Saqlash"),
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.chatId)
                    .update({'groupName': controller.text.trim()});
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _updateGroupAvatar() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('group_avatars/${widget.chatId}.jpg');

// Yuklashda metadata qo'shish (Xavfsizlik uchun yaxshi)
      await ref.putFile(
        File(image.path),
        SettableMetadata(customMetadata: {'uploaded_by': currentUserId}),
      );
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({'groupAvatar': url, 'chatAvatar': url});
      _showSnackBar("Guruh rasmi yangilandi!");
    } catch (e) {
      _showSnackBar("Xatolik: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _leaveGroupAction(Map<String, dynamic> data) async {
    bool confirm = await _showConfirmDialog(
      "Tark etish",
      "Haqiqatan ham guruhni tark etasizmi?",
    );
    if (!confirm) return;

    final docRef =
        FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    List users = List.from(data['users'] ?? []);
    List admins = List.from(data['admins'] ?? []);

    users.remove(currentUserId);
    admins.remove(currentUserId);

    if (users.isEmpty) {
      await docRef.delete();
    } else {
      Map<String, dynamic> updates = {'users': users, 'admins': admins};
      if (data['ownerId'] == currentUserId) {
        String nextOwner = users.first;
        updates['ownerId'] = nextOwner;
        if (!admins.contains(nextOwner)) admins.add(nextOwner);
        updates['admins'] = admins;
      }
      await docRef.update(updates);
    }
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              CupertinoDialogAction(
                child: const Text("Yo'q"),
                onPressed: () => Navigator.pop(context, false),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text("Ha"),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0E1621) : const Color(0xFFF1F5F9);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: bgColor,
            body: const Center(child: CupertinoActivityIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: bgColor,
            body: const Center(child: Text("Guruh topilmadi")),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final List memberIds = data['users'] ?? [];
        final List admins = data['admins'] ?? [];
        final String ownerId = data['ownerId'] ?? "";
        final bool isMember = memberIds.contains(currentUserId);
        final bool amIAdmin =
            admins.contains(currentUserId) || ownerId == currentUserId;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: bgColor,
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  _buildSliverHeader(data, amIAdmin, isDark),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        if (!isMember)
                          _buildFollowPrompt(isDark)
                        else
                          _buildMainActions(data, amIAdmin, isDark),
                        _buildInfoSection(isDark),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  if (isMember)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        child: Container(
                          color:
                              isDark ? const Color(0xFF17212B) : Colors.white,
                          child: TabBar(
                            dividerColor: Colors.transparent,
                            indicatorColor: Colors.blue,
                            labelColor: Colors.blue,
                            unselectedLabelColor: Colors.grey,
                            tabs: [
                              Tab(text: "A'zolar (${memberIds.length})"),
                              const Tab(text: "Media"),
                              const Tab(text: "Fayllar"),
                            ],
                          ),
                        ),
                      ),
                    ),
                ];
              },
              body: isMember
                  ? TabBarView(
                      children: [
                        _buildMembersList(
                          memberIds,
                          ownerId,
                          admins,
                          amIAdmin,
                          isDark,
                        ),
                        _buildMediaQuery('image'),
                        _buildMediaQuery('file'),
                      ],
                    )
                  : const Center(
                      child: Text(
                        "Media ko'rish uchun obuna bo'ling",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliverHeader(
    Map<String, dynamic> data,
    bool isAdmin,
    bool isDark,
  ) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      stretch: true,
      backgroundColor: isDark ? const Color(0xFF17212B) : Colors.blueAccent,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        title: Text(
          data['groupName'] ?? "Guruh",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
            shadows: [Shadow(blurRadius: 10, color: Colors.black)],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            data['groupAvatar'] != null && data['groupAvatar'] != ""
                ? CachedNetworkImage(
                    imageUrl: data['groupAvatar'],
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Colors.blueGrey,
                    child: const Icon(
                      Icons.group,
                      size: 80,
                      color: Colors.white24,
                    ),
                  ),
            if (_isUploading)
              Container(
                color: Colors.black45,
                child: const Center(child: CupertinoActivityIndicator()),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black26, Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editGroupName(data['groupName'] ?? ""),
          ),
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.photo_camera),
            onPressed: _updateGroupAvatar,
          ),
      ],
    );
  }

  Widget _buildFollowPrompt(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17212B) : Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Text(
            "Siz guruhga a'zo emassiz",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            color: Colors.blue,
            onPressed: _followFromInfo,
            child: const Text("Obuna bo'lish"),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActions(
    Map<String, dynamic> data,
    bool isAdmin,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17212B) : Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionIcon(
            CupertinoIcons.chat_bubble_fill,
            "Chat",
            Colors.blue,
            () => Navigator.pop(context),
          ),
          _actionIcon(
            CupertinoIcons.person_add_solid,
            "Qo'shish",
            Colors.green,
            isAdmin ? () => _showAddMember() : null,
          ),
          _actionIcon(
            CupertinoIcons.square_arrow_right_fill,
            "Tark etish",
            Colors.redAccent,
            () => _leaveGroupAction(data),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(
    IconData icon,
    String label,
    Color color,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.3 : 1.0,
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(bool isDark) {
    // Sizning yangi Hosting URL manzilingiz va guruhning maxsus ID-si
    // Bu havola har bir guruh uchun unikallar (takrorlanmas) bo'ladi
    final String shareLink =
        "https://safechat-7f27d.web.app/#/group?id=${widget.chatId}";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17212B) : Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: const Icon(CupertinoIcons.link, color: Colors.blue),
        title: Text(
          shareLink,
          style: const TextStyle(
            color: Colors.blue,
            fontSize:
                13, // Link uzun bo'lishi mumkinligi uchun shriftni biroz kichraytirdik
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis, // Link sig'masa oxiri nuqta-nuqta bo'ladi
        ),
        subtitle: const Text(
          "Guruhga taklif havolasi",
          style: TextStyle(fontSize: 12),
        ),
        onTap: () {
          // Endi bu guruhning aynan o'ziga tegishli linkni nusxalaydi
          Clipboard.setData(ClipboardData(text: shareLink));
          _showSnackBar("Guruh havolasi nusxalandi!");
        },
        trailing: const Icon(
          CupertinoIcons.doc_on_doc,
          size: 20,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildMembersList(
    List mIds,
    String oId,
    List admins,
    bool amIAdmin,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 10),
      itemCount: mIds.length,
      itemBuilder: (context, i) =>
          _memberTile(mIds[i], oId, admins, amIAdmin, isDark),
    );
  }

  Widget _memberTile(
    String mId,
    String oId,
    List admins,
    bool amIAdmin,
    bool isDark,
  ) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(mId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox();
        final user = snap.data!.data() as Map<String, dynamic>;
        bool isOwner = mId == oId;
        bool isAdmin = admins.contains(mId);

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(
              user['avatar'] ??
                  "https://ui-avatars.com/api/?name=${user['username']}",
            ),
          ),
          title: Text(
            user['username'] ?? "A'zo",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          subtitle: Text(
            user['online'] == true ? "onlayn" : "oflayn",
            style: TextStyle(
              color: user['online'] == true ? Colors.blue : Colors.grey,
              fontSize: 12,
            ),
          ),
          trailing: isOwner
              ? const Text(
                  "Ega",
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : (isAdmin
                  ? const Text("Admin", style: TextStyle(color: Colors.blue))
                  : null),
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => UserInfoScreen(userId: mId)),
          ),
          onLongPress: () {
            if (amIAdmin && mId != currentUserId && !isOwner) {
              _showMemberManagement(mId, isAdmin, user['username'] ?? "A'zo");
            }
          },
        );
      },
    );
  }

  void _showMemberManagement(String mId, bool isAdmin, String name) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(name),
        actions: [
          CupertinoActionSheetAction(
            child: Text(isAdmin ? "Admindan olish" : "Admin qilish"),
            onPressed: () {
              Navigator.pop(context);
              FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .update({
                'admins': isAdmin
                    ? FieldValue.arrayRemove([mId])
                    : FieldValue.arrayUnion([mId]),
              });
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text("Guruhdan chiqarish"),
            onPressed: () async {
              Navigator.pop(context);
              if (await _showConfirmDialog(
                "Haydash",
                "$name guruhdan chiqarilsinmi?",
              )) {
                FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.chatId)
                    .update({
                  'users': FieldValue.arrayRemove([mId]),
                  'admins': FieldValue.arrayRemove([mId]),
                });
              }
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text("Bekor qilish"),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildMediaQuery(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('type', isEqualTo: type)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty)
          return const Center(
            child: Text("Ma'lumot yo'q", style: TextStyle(color: Colors.grey)),
          );
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: snap.data!.docs.length,
          itemBuilder: (context, i) {
            final msg = snap.data!.docs[i].data() as Map<String, dynamic>;
            final url = msg['imageUrl'] ?? msg['mediaUrl'];
            if (url == null) return const SizedBox();
            return type == 'image'
                ? InkWell(
                    onTap: () => _showFullImage(url),
                    child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                  )
                : const Icon(
                    Icons.insert_drive_file,
                    size: 40,
                    color: Colors.grey,
                  );
          },
        );
      },
    );
  }

  void _showFullImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(child: CachedNetworkImage(imageUrl: url)),
          ),
        ),
      ),
    );
  }

  void _showAddMember() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddMemberSheet(chatId: widget.chatId),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverAppBarDelegate({required this.child});
  @override
  double get minExtent => 50;
  @override
  double get maxExtent => 50;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      child;
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class _AddMemberSheet extends StatefulWidget {
  final String chatId;
  const _AddMemberSheet({Key? key, required this.chatId}) : super(key: key);
  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  String _q = "";
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1621) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: CupertinoSearchTextField(
              placeholder: "Qidirish...",
              onChanged: (v) => setState(() => _q = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData)
                  return const Center(child: CupertinoActivityIndicator());
                final users = snap.data!.docs
                    .where(
                      (d) => (d['username'] as String? ?? "")
                          .toLowerCase()
                          .contains(_q),
                    )
                    .toList();
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, i) => ListTile(
                    leading: CircleAvatar(
                      backgroundImage: CachedNetworkImageProvider(
                        users[i]['avatar'] ??
                            "https://ui-avatars.com/api/?name=${users[i]['username']}",
                      ),
                    ),
                    title: Text(
                      users[i]['username'] ?? "Foydalanuvchi",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    trailing: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Text("Qo'shish"),
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('chats')
                            .doc(widget.chatId)
                            .update({
                          'users': FieldValue.arrayUnion([users[i].id]),
                        });
                        Navigator.pop(context);
                      },
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
}
