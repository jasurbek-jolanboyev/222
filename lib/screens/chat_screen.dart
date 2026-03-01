import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/verified_name.dart';
import '../providers/theme_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_background.dart';
import 'user_info_screen.dart';
// NotificationService'ni o'z yo'lingiz bo'yicha import qiling
import '../services/notification_service.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String otherUserId;
  final String otherUsername;
  final String otherAvatar;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.otherUserId,
    required this.otherUsername,
    required this.otherAvatar,
    this.isGroup = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;
  final ImagePicker _picker = ImagePicker();

  String? _editingMessageId;
  Map<String, dynamic>? _replyMessage;
  bool _isUploading = false;
  Set<String> _selectedMessageIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _ensureChatRoomExists();
    _markMessagesAsRead();

    // BİLDİRİSHNOMA FİLTRİNİ YOQISH
    NotificationService.currentOpenedChatId = widget.roomId;
  }

  @override
  void dispose() {
    // BİLDİRİSHNOMA FİLTRİNİ TOZALASH
    NotificationService.currentOpenedChatId = null;

    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 1. CHAT XONASI MAVJUDLIGINI TEKSHIRISH
  Future<void> _ensureChatRoomExists() async {
    final chatRef =
        FirebaseFirestore.instance.collection('chats').doc(widget.roomId);
    final doc = await chatRef.get();

    if (!doc.exists) {
      await chatRef.set({
        'isGroup': widget.isGroup,
        'users': [_currentUid, widget.otherUserId],
        'lastMessage': '',
        'lastTime': FieldValue.serverTimestamp(),
        'backgroundTheme': 'classic',
        'typing': {_currentUid: false, widget.otherUserId: false},
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // 2. MEDIA YUKLASH (STORAGE + FIRESTORE)
  Future<void> _uploadMedia(File file, String type) async {
    setState(() => _isUploading = true);
    try {
      String ext = file.path.split('.').last;
      String fileName = "${DateTime.now().millisecondsSinceEpoch}.$ext";

      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('chats/${widget.roomId}/$type/$fileName');

      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      _sendSpecialMessage(downloadUrl, type, fileName: fileName);
    } catch (e) {
      _showError("Yuklashda xatolik yuz berdi");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // 3. MEDIA TANLASH
  Future<void> _handleMediaSelection(String type) async {
    if (Navigator.canPop(context)) Navigator.pop(context);
    try {
      if (type == 'image' || type == 'video') {
        final XFile? pickedFile = type == 'image'
            ? await _picker.pickImage(
                source: ImageSource.gallery, imageQuality: 70)
            : await _picker.pickVideo(source: ImageSource.gallery);

        if (pickedFile != null) _uploadMedia(File(pickedFile.path), type);
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: type == 'audio' ? FileType.audio : FileType.any,
        );
        if (result != null) _uploadMedia(File(result.files.single.path!), type);
      }
    } catch (e) {
      _showError("Fayl tanlanmadi");
    }
  }

  // 4. JOY LASHUV YUBORISH
  Future<void> _sendLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError("GPS o'chiq. Iltimos, yoqing.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError("Ruxsat berilmadi.");
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      String locUrl =
          "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      _sendSpecialMessage(locUrl, 'location');

      if (Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      _showError("Xatolik yuz berdi: $e");
    }
  }

  // 5. MAXSUS XABARLAR (MEDIA, LOCATION)
  void _sendSpecialMessage(String url, String type, {String? fileName}) async {
    final chatRef =
        FirebaseFirestore.instance.collection('chats').doc(widget.roomId);
    final currentUserName =
        FirebaseAuth.instance.currentUser?.displayName ?? "Foydalanuvchi";

    String notificationBody = '';
    switch (type) {
      case 'image':
        notificationBody = '🖼 Rasm yubordi';
        break;
      case 'video':
        notificationBody = '🎥 Video yubordi';
        break;
      case 'file':
        notificationBody = '📁 Fayl yubordi';
        break;
      case 'location':
        notificationBody = '📍 Joylashuv yubordi';
        break;
      default:
        notificationBody = 'Yangi xabar';
    }

    final batch = FirebaseFirestore.instance.batch();
    final msgRef = chatRef.collection('messages').doc();

    batch.set(msgRef, {
      'text': notificationBody,
      'mediaUrl': url,
      'fileName': fileName,
      'type': type,
      'senderId': _currentUid,
      'senderName': currentUserName,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    batch.update(chatRef, {
      'lastMessage': type.toUpperCase(),
      'lastTime': FieldValue.serverTimestamp(),
    });

    final notifyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.otherUserId)
        .collection('notifications')
        .doc();

    batch.set(notifyRef, {
      'title': currentUserName,
      'body': notificationBody,
      'timestamp': FieldValue.serverTimestamp(),
      'senderId': _currentUid,
      'roomId': widget.roomId,
      'type': type,
    });

    await batch.commit();
  }

  // 6. ONLINE STATUS VA TYPING
  Widget _buildStatusText() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.roomId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Text("online", style: TextStyle(fontSize: 11));
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        bool isTyping = data?['typing']?[widget.otherUserId] ?? false;
        return Text(
          isTyping ? "yozmoqda..." : "online",
          style: TextStyle(
              fontSize: 12,
              color: isTyping ? Colors.greenAccent : Colors.white70,
              fontWeight: isTyping ? FontWeight.bold : FontWeight.normal),
        );
      },
    );
  }

  // 7. MATNLI XABAR YUBORISH
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _replyMessage == null) return;

    final chatRef =
        FirebaseFirestore.instance.collection('chats').doc(widget.roomId);
    final currentUserName =
        FirebaseAuth.instance.currentUser?.displayName ?? "Foydalanuvchi";

    if (_editingMessageId != null) {
      await chatRef.collection('messages').doc(_editingMessageId).update({
        'text': text,
        'isEdited': true,
      });
      setState(() => _editingMessageId = null);
    } else {
      final batch = FirebaseFirestore.instance.batch();
      final msgRef = chatRef.collection('messages').doc();

      batch.set(msgRef, {
        'text': text,
        'senderId': _currentUid,
        'senderName': currentUserName,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'text',
        'isRead': false,
        'replyTo': _replyMessage,
      });

      batch.update(chatRef, {
        'lastMessage': text,
        'lastTime': FieldValue.serverTimestamp(),
      });

      final notifyRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .collection('notifications')
          .doc();

      batch.set(notifyRef, {
        'title': currentUserName,
        'body': text,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': _currentUid,
        'roomId': widget.roomId,
        'type': 'text',
      });

      await batch.commit();
    }

    _messageController.clear();
    _onTyping("");
    if (_replyMessage != null) setState(() => _replyMessage = null);
  }

  void _onTyping(String value) {
    FirebaseFirestore.instance.collection('chats').doc(widget.roomId).update({
      'typing.$_currentUid': value.isNotEmpty,
    });
  }

  void _markMessagesAsRead() {
    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.roomId)
        .collection('messages')
        .where('senderId', isNotEqualTo: _currentUid)
        .where('isRead', isEqualTo: false)
        .get()
        .then((snap) {
      for (var doc in snap.docs) {
        doc.reference.update({'isRead': true});
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      appBar: _isSelectionMode
          ? _buildSelectionAppBar(isDark)
          : _buildAppBar(isDark),
      body: ChatBackground(
        isDark: isDark,
        child: Column(
          children: [
            if (_isUploading)
              const LinearProgressIndicator(
                  minHeight: 2, color: Colors.blueAccent),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.roomId)
                    .collection('messages')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData)
                    return const Center(child: CupertinoActivityIndicator());
                  final docs = snap.data!.docs;
                  return ListView.builder(
                    reverse: true,
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final msg = doc.data() as Map<String, dynamic>;
                      final messageId = doc.id;
                      final isMe = msg['senderId'] == _currentUid;
                      final isSelected =
                          _selectedMessageIds.contains(messageId);

                      return Container(
                        color: isSelected
                            ? Colors.blue.withOpacity(0.15)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => _isSelectionMode
                              ? _toggleSelection(messageId)
                              : _showMessageOptions(msg, messageId, isMe),
                          onLongPress: () {
                            if (!_isSelectionMode) {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _isSelectionMode = true;
                                _selectedMessageIds.add(messageId);
                              });
                            }
                          },
                          child: IgnorePointer(
                            ignoring: _isSelectionMode,
                            child: MessageBubble(
                              text: msg['text'] ?? '',
                              isMe: isMe,
                              type: msg['type'] ?? 'text',
                              mediaUrl: msg['mediaUrl'],
                              fileName: msg['fileName'],
                              timestamp:
                                  (msg['createdAt'] as Timestamp?)?.toDate() ??
                                      DateTime.now(),
                              senderName: msg['senderName'] ?? "User",
                              isRead: msg['isRead'] ?? false,
                              replyTo: msg['replyTo'],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (!_isSelectionMode) _buildMessageInput(isDark),
          ],
        ),
      ),
      bottomNavigationBar:
          _isSelectionMode ? _buildSelectionBottomBar(isDark) : null,
    );
  }

  // --- UI YORDAMCHI WIDGETLAR ---

  AppBar _buildAppBar(bool isDark) {
    return AppBar(
      elevation: 1,
      backgroundColor: isDark ? const Color(0xFF1B2733) : Colors.blueAccent,
      iconTheme: const IconThemeData(color: Colors.white),
      title: InkWell(
        onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(
                builder: (_) => UserInfoScreen(userId: widget.otherUserId))),
        child: Row(
          children: [
            CircleAvatar(
                radius: 18,
                backgroundImage:
                    CachedNetworkImageProvider(widget.otherAvatar)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VerifiedName(
                      username: widget.otherUsername,
                      isVerified: true,
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  _buildStatusText(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildSelectionAppBar(bool isDark) {
    return AppBar(
      elevation: 1,
      backgroundColor: isDark ? const Color(0xFF1B2733) : Colors.blueGrey,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => setState(() {
          _isSelectionMode = false;
          _selectedMessageIds.clear();
        }),
      ),
      title: Text("${_selectedMessageIds.length} tanlandi",
          style: const TextStyle(color: Colors.white, fontSize: 18)),
      actions: [
        if (_selectedMessageIds.length == 1)
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white),
            onPressed: () {
              // Nusxalash mantiqi (Ixtiyoriy: Firestore'dan matnni olib Clipboard'ga berish)
              _showError("Nusxalandi");
            },
          ),
      ],
    );
  }

  Widget _buildSelectionBottomBar(bool isDark) {
    return Container(
      height: 70 + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2733) : Colors.white,
        border: const Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _selectionActionItem(
              Icons.reply, "Forward", () => _showError("Tez kunda...")),
          _selectionActionItem(
              Icons.download, "Save", () => _showError("Saqlandi")),
          _selectionActionItem(
              Icons.delete, "Delete", () => _deleteSelectedMessages(),
              color: Colors.red),
        ],
      ),
    );
  }

  Widget _selectionActionItem(IconData icon, String label, VoidCallback onTap,
      {Color color = Colors.blueAccent}) {
    return InkWell(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ]),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          8, 4, 8, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B2733) : Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Column(
        children: [
          if (_replyMessage != null) _buildReplyPreview(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                  icon: const Icon(CupertinoIcons.paperclip,
                      color: Colors.blueAccent),
                  onPressed: () => _showAttachmentMenu(isDark)),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(22)),
                  child: TextField(
                    controller: _messageController,
                    onChanged: _onTyping,
                    maxLines: 5,
                    minLines: 1,
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: const InputDecoration(
                        hintText: "Xabar...", border: InputBorder.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.send, color: Colors.white, size: 20)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAttachmentMenu(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B2733) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            _attachmentItem(CupertinoIcons.photo, "Gallereya", Colors.purple,
                () => _handleMediaSelection('image')),
            _attachmentItem(CupertinoIcons.video_camera, "Video", Colors.pink,
                () => _handleMediaSelection('video')),
            _attachmentItem(CupertinoIcons.music_note, "Audio", Colors.orange,
                () => _handleMediaSelection('audio')),
            _attachmentItem(CupertinoIcons.doc, "Hujjat", Colors.blue,
                () => _handleMediaSelection('file')),
            _attachmentItem(
                CupertinoIcons.location, "Manzil", Colors.green, _sendLocation),
          ],
        ),
      ),
    );
  }

  Widget _attachmentItem(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(children: [
          CircleAvatar(
              radius: 25,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color)),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          border: const Border(
              left: BorderSide(color: Colors.blueAccent, width: 3)),
          color: Colors.blueAccent.withOpacity(0.05)),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 14, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  "${_replyMessage!['senderName']}: ${_replyMessage!['text']}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => setState(() => _replyMessage = null)),
        ],
      ),
    );
  }

  void _showMessageOptions(
      Map<String, dynamic> msg, String messageId, bool isMe) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _toggleSelection(messageId);
              setState(() => _isSelectionMode = true);
            },
            child: const Text("Tanlash (Select)"),
          ),
          if (msg['type'] == 'text')
            CupertinoActionSheetAction(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: msg['text']));
                Navigator.pop(context);
                _showError("Nusxalandi");
              },
              child: const Text("Nusxalash (Copy)"),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _replyMessage = msg);
            },
            child: const Text("Javob berish (Reply)"),
          ),
          if (isMe && msg['type'] == 'text')
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _messageController.text = msg['text'];
                setState(() => _editingMessageId = messageId);
              },
              child: const Text("Tahrirlash (Edit)"),
            ),
          if (isMe)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _deleteMessage(messageId);
              },
              child: const Text("O'chirish (Delete)"),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
            child: const Text("Bekor qilish"),
            onPressed: () => Navigator.pop(context)),
      ),
    );
  }

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  Future<void> _deleteMessage(String messageId) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.roomId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> _deleteSelectedMessages() async {
    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.roomId)
        .collection('messages');
    for (var id in _selectedMessageIds) {
      await chatRef.doc(id).delete();
    }
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
    _showError("Tanlangan xabarlar o'chirildi");
  }
}
