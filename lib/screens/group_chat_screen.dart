import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'group_info_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String roomId;
  final String groupName;

  const GroupChatScreen(
      {super.key, required this.roomId, required this.groupName});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
  void _showContextMenu(
      BuildContext context, Map<String, dynamic> msg, String msgId, bool isMe) {
    HapticFeedback.heavyImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Row(children: [
              Icon(CupertinoIcons.reply),
              SizedBox(width: 10),
              Text("Javob berish")
            ]),
            onPressed: () {
              Navigator.pop(context);
              setState(() => _replyMessage = msg);
            },
          ),
          CupertinoActionSheetAction(
            child: const Row(children: [
              Icon(CupertinoIcons.doc_on_doc),
              SizedBox(width: 10),
              Text("Nusxa olish")
            ]),
            onPressed: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: msg['text'] ?? ""));
            },
          ),
          if (isMe)
            CupertinoActionSheetAction(
              child: const Row(children: [
                Icon(CupertinoIcons.pencil),
                SizedBox(width: 10),
                Text("Tahrirlash")
              ]),
              onPressed: () {
                Navigator.pop(context);
                _messageController.text = msg['text'] ?? "";
                // Tahrirlash rejimini yoqish uchun msgId ni saqlab qo'ying
              },
            ),
          if (msg['imageUrl'] != null || msg['mediaUrl'] != null)
            CupertinoActionSheetAction(
              child: const Row(children: [
                Icon(CupertinoIcons.cloud_download),
                SizedBox(width: 10),
                Text("Galereyaga saqlash")
              ]),
              onPressed: () {
                Navigator.pop(context); /* Gallery saving logic */
              },
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Row(children: [
              Icon(CupertinoIcons.trash),
              SizedBox(width: 10),
              Text("O'chirish")
            ]),
            onPressed: () {
              Navigator.pop(context);
              FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.roomId)
                  .collection('messages')
                  .doc(msgId)
                  .delete();
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

  Map<String, dynamic>? _replyMessage;
  bool _isUploading = false;

  // --- FOLLOW FUNKSIYASI ---
  Future<void> _followGroup() async {
    HapticFeedback.mediumImpact();
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.roomId)
        .update({
      'users': FieldValue.arrayUnion([currentUserId])
    });
  }

  // --- MEDIA YUKLASH ---
  Future<void> _pickMedia(String type) async {
    Navigator.pop(context);
    File? file;
    if (type == 'image' || type == 'video') {
      final picker = ImagePicker();
      final XFile? media = type == 'image'
          ? await picker.pickImage(source: ImageSource.gallery)
          : await picker.pickVideo(source: ImageSource.gallery);
      if (media != null) file = File(media.path);
    } else {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) file = File(result.files.single.path!);
    }

    if (file != null) {
      setState(() => _isUploading = true);
      try {
        String fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}";
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('groups/${widget.roomId}/$fileName');
        await ref.putFile(file);
        String url = await ref.getDownloadURL();
        _handleSend(
            imageUrl: type == 'image' ? url : null,
            mediaUrl: type != 'image' ? url : null,
            type: type);
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  // --- XABAR YUBORISH ---
  Future<void> _handleSend(
      {String? imageUrl, String? mediaUrl, String type = 'text'}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && imageUrl == null && mediaUrl == null) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.roomId)
        .collection('messages')
        .add({
      'senderId': currentUserId,
      'senderName': FirebaseAuth.instance.currentUser?.displayName ?? "User",
      'text': text,
      'imageUrl': imageUrl,
      'mediaUrl': mediaUrl,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'replyTo': _replyMessage,
      'isRead': false,
    });

    _messageController.clear();
    if (_replyMessage != null) setState(() => _replyMessage = null);
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0E1621) : const Color(0xFFE7EBF0);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.roomId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
              body: Center(child: CupertinoActivityIndicator()));
        }
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final List members = data['users'] ?? [];
        final bool isMember = members.contains(currentUserId);

        return Scaffold(
          backgroundColor: bgColor,
          appBar: _buildAppBar(data, isDark),
          body: Column(
            children: [
              if (_isUploading)
                const LinearProgressIndicator(minHeight: 2, color: Colors.blue),
              Expanded(child: _buildMessagesList(isDark)),
              isMember ? _buildInputArea(isDark) : _buildFollowArea(isDark),
            ],
          ),
        );
      },
    );
  }

  // --- SCREENSHOTDAGI KABI APPBAR ---
  PreferredSizeWidget _buildAppBar(Map<String, dynamic> data, bool isDark) {
    return AppBar(
      elevation: 1,
      backgroundColor: isDark ? const Color(0xFF17212B) : Colors.white,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context)),
      title: InkWell(
        onTap: () {
          if (widget.roomId.isNotEmpty) {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) =>
                    GroupInfoScreen(chatId: widget.roomId.trim()),
              ),
            );
          }
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: data['groupAvatar'] != null
                  ? CachedNetworkImageProvider(data['groupAvatar'])
                  : null,
              child: data['groupAvatar'] == null
                  ? const Icon(Icons.group, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['groupName'] ?? widget.groupName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text("${(data['users'] as List? ?? []).length} ta a'zo",
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- XABARLAR RO'YXATI ---
  Widget _buildMessagesList(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.roomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CupertinoActivityIndicator());
        return ListView.builder(
          reverse: true,
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          itemCount: snap.data!.docs.length,
          itemBuilder: (context, i) {
            final msg = snap.data!.docs[i].data() as Map<String, dynamic>;
            return _TelegramBubble(
              data: msg,
              msgId: snap.data!.docs[i].id,
              isMe: msg['senderId'] == currentUserId,
              isDark: isDark,
              onReply: () => setState(() => _replyMessage = msg),
              onLongPress: _showContextMenu, // Yangi funksiya ulandi
            );
          },
        );
      },
    );
  }

  // --- OBUNA BO'LISH TUGMASI ---
  Widget _buildFollowArea(bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration:
          BoxDecoration(color: isDark ? const Color(0xFF17212B) : Colors.white),
      child: CupertinoButton(
        color: Colors.blueAccent,
        onPressed: _followGroup,
        child: const Text("Guruhga obuna bo'lish",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          8, 4, 8, MediaQuery.of(context).padding.bottom + 6),
      decoration:
          BoxDecoration(color: isDark ? const Color(0xFF17212B) : Colors.white),
      child: Column(
        children: [
          if (_replyMessage != null) _buildReplyPreview(isDark),
          Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.grey),
                  onPressed: () => _showMediaMenu(isDark)),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  onChanged: (val) =>
                      setState(() {}), // Tugmani o'zgarishi uchun
                  maxLines: 5,
                  minLines: 1,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: const InputDecoration(
                      hintText: "Xabar",
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey)),
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined,
                      color: Colors.grey),
                  onPressed: () {}),

              // --- TUGMA O'ZGARTIRILDI ---
              GestureDetector(
                onTap: () => _handleSend(),
                child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue,
                    child: Icon(
                        _messageController.text.trim().isEmpty
                            ? Icons.mic // Agar matn bo'sh bo'lsa mikrofon
                            : Icons.send, // Matn yozilsa yuborish tugmasi
                        color: Colors.white,
                        size: 20)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMediaMenu(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF17212B) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20))),
        child: Wrap(
          spacing: 20,
          children: [
            _mediaIcon(
                Icons.image, "Rasm", Colors.purple, () => _pickMedia('image')),
            _mediaIcon(Icons.description, "Fayl", Colors.blue,
                () => _pickMedia('file')),
            _mediaIcon(Icons.location_on, "Manzil", Colors.green, () {}),
          ],
        ),
      ),
    );
  }

  Widget _mediaIcon(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Column(children: [
      InkWell(
          onTap: onTap,
          child: CircleAvatar(
              radius: 25,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color))),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(fontSize: 12))
    ]);
  }

  Widget _buildReplyPreview(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Colors.blue, width: 2))),
      child: Row(
        children: [
          Expanded(
              child: Text(_replyMessage!['text'] ?? "Media",
                  style: const TextStyle(color: Colors.blue, fontSize: 13),
                  maxLines: 1)),
          IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => setState(() => _replyMessage = null)),
        ],
      ),
    );
  }
}

class _TelegramBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final String msgId;
  final bool isMe, isDark;
  final VoidCallback onReply;
  final Function(BuildContext, Map<String, dynamic>, String, bool) onLongPress;

  const _TelegramBubble({
    required this.data,
    required this.msgId,
    required this.isMe,
    required this.isDark,
    required this.onReply,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final time = data['timestamp'] != null
        ? DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate())
        : "";

    return GestureDetector(
      onHorizontalDragEnd: (_) => onReply(),
      onLongPress: () => onLongPress(context, data, msgId, isMe),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) _buildSenderAvatar(data['senderId']),
            const SizedBox(width: 8),
            _buildMessageBody(context, time),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderAvatar(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final userData = snap.data?.data() as Map<String, dynamic>?;
        return CircleAvatar(
          radius: 16,
          backgroundImage: userData?['avatar'] != null
              ? CachedNetworkImageProvider(userData!['avatar'])
              : null,
          child: userData?['avatar'] == null
              ? const Icon(Icons.person, size: 18)
              : null,
        );
      },
    );
  }

  Widget _buildMessageBody(BuildContext context, String time) {
    return Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe
            ? (isDark ? const Color(0xFF2B5278) : const Color(0xFFEFFDDE))
            : (isDark ? const Color(0xFF182533) : Colors.white),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(15),
          topRight: const Radius.circular(15),
          bottomLeft: Radius.circular(isMe ? 15 : 2),
          bottomRight: Radius.circular(isMe ? 2 : 15),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) _buildSenderHeader(data['senderId']),
          if (data['replyTo'] != null) _buildReplyBox(),
          if (data['imageUrl'] != null)
            ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(imageUrl: data['imageUrl'])),
          Text(data['text'] ?? "",
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black, fontSize: 15)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Spacer(),
              Text(time,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              if (isMe)
                const Icon(Icons.done_all, size: 14, color: Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSenderHeader(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final userData = snap.data?.data() as Map<String, dynamic>?;
        final bool isVerified = userData?['isVerified'] ?? false;
        final String role = userData?['role'] ?? 'user'; // admin, owner (ega)

        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(userData?['username'] ?? "User",
                style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            if (isVerified)
              const Icon(Icons.verified, color: Colors.blue, size: 12),
            if (role == 'admin')
              const Text(" admin",
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            if (role == 'owner')
              const Text(" ega",
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
          ],
        );
      },
    );
  }

  Widget _buildReplyBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.all(5),
      decoration: const BoxDecoration(
          color: Colors.black12,
          border: Border(left: BorderSide(color: Colors.blue, width: 3))),
      child: Text(data['replyTo']['text'] ?? "Media",
          style: const TextStyle(fontSize: 12, color: Colors.blue),
          maxLines: 1),
    );
  }
}
