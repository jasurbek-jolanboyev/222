import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _groupNameController = TextEditingController();
  final List<Map<String, dynamic>> _selectedUsers = [];
  String _searchQuery = "";
  File? _groupImage;
  bool _isLoading = false;

  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // 1. Qidiruv uchun kalit so'zlar yaratish (Firestore uchun)
  List<String> _generateSearchKeywords(String text) {
    List<String> keywords = [];
    String temp = "";
    for (var i = 0; i < text.length; i++) {
      temp += text[i].toLowerCase();
      keywords.add(temp);
    }
    return keywords;
  }

  // 2. Rasm tanlash (Xavfsizlik va o'lcham cheklovi bilan)
  Future<void> _pickGroupImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 40, // 20MB lik rasmni ham siqib yuboradi
        maxWidth: 600,
        maxHeight: 600,
      );
      if (pickedFile != null) {
        setState(() => _groupImage = File(pickedFile.path));
      }
    } catch (e) {
      _showError("Rasm tanlashda xatolik yuz berdi");
    }
  }

  // 3. Guruh yaratish (Atomic Set & Pentest Protection)
  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();

    // Validatsiya
    if (groupName.isEmpty) return _showError("Guruh nomini kiriting");
    if (groupName.length > 50) return _showError("Guruh nomi juda uzun");
    if (_selectedUsers.isEmpty) return _showError("Kamida bitta a'zo tanlang");
    if (_selectedUsers.length > 100)
      return _showError("Maksimal 100 ta a'zo qo'shish mumkin");

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact(); // UX tebranish

    try {
      final docRef = FirebaseFirestore.instance.collection('chats').doc();
      String imageUrl = "";

      // Rasm bo'lsa storagega yuklash (Pentest: Metadata bilan)
      if (_groupImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('group_avatars/${docRef.id}.jpg');
        final uploadTask = await storageRef.putFile(
          _groupImage!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        imageUrl = await uploadTask.ref.getDownloadURL();
      }

      // Member ID'larni yig'ish
      List<String> memberIds = [
        currentUserId,
        ..._selectedUsers.map((e) => e['uid'] as String)
      ];

      // Atomic Set: Ma'lumotlarni yaxlit bitta ob'ektda yuborish
      final Map<String, dynamic> groupData = {
        'chatId': docRef.id,
        'groupName': groupName,
        'groupAvatar': imageUrl,
        'chatAvatar': imageUrl,
        'ownerId': currentUserId,
        'admins': [currentUserId],
        'users': memberIds,
        'lastMessage': "Guruh yaratildi",
        'lastSenderId': currentUserId,
        'lastTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isGroup': true,
        'typing': {},
        'searchKeywords': _generateSearchKeywords(groupName), // Qidiruv uchun
      };

      await docRef.set(groupData);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError("Server bilan ulanishda xatolik: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F2F7);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          _buildHeader(cardColor, isDark),
          if (_selectedUsers.isNotEmpty) _buildSelectedUsersList(isDark),
          _buildSearchField(isDark),
          Expanded(child: _buildUsersList(isDark, cardColor)),
        ],
      ),
    );
  }

  // --- UI KOMPONENTLARI (Yangilangan) ---

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return CupertinoNavigationBar(
      border: null,
      backgroundColor: isDark
          ? const Color(0xFF1E293B).withOpacity(0.9)
          : Colors.white.withOpacity(0.9),
      middle: Text("Yangi guruh",
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold)),
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        child: const Text("Bekor qilish",
            style: TextStyle(color: Colors.redAccent)),
        onPressed: () => Navigator.pop(context),
      ),
      trailing: _isLoading
          ? const CupertinoActivityIndicator()
          : CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _createGroup,
              child: const Text("Yaratish",
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
    );
  }

  Widget _buildHeader(Color cardColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickGroupImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  backgroundImage:
                      _groupImage != null ? FileImage(_groupImage!) : null,
                  child: _groupImage == null
                      ? const Icon(CupertinoIcons.camera_fill,
                          size: 35, color: Colors.blue)
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.blue, shape: BoxShape.circle),
                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                )
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: CupertinoTextField(
              controller: _groupNameController,
              placeholder: "Guruh nomi",
              maxLength: 50,
              decoration: const BoxDecoration(color: Colors.transparent),
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedUsersList(bool isDark) {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: _selectedUsers.length,
        itemBuilder: (context, index) {
          final user = _selectedUsers[index];
          return Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage:
                          CachedNetworkImageProvider(user['avatar'] ?? ""),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 60,
                      child: Text(user['name'],
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center),
                    ),
                  ],
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedUsers.removeAt(index)),
                    child: Container(
                      decoration: const BoxDecoration(
                          color: Colors.grey, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white),
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 5, 15, 15),
      child: CupertinoSearchTextField(
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        placeholder: "A'zolarni qidirish...",
        borderRadius: BorderRadius.circular(12),
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
      ),
    );
  }

  Widget _buildUsersList(bool isDark, Color cardColor) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').limit(40).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CupertinoActivityIndicator());

        final users = snapshot.data!.docs.where((doc) {
          final name = (doc['username'] ?? "").toString().toLowerCase();
          return doc.id != currentUserId && name.contains(_searchQuery);
        }).toList();

        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 10),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;
              final String name = userData['username'] ?? 'User';
              final String avatar = userData['photoUrl'] ?? "";
              final isSelected =
                  _selectedUsers.any((element) => element['uid'] == userId);

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedUsers.removeWhere((e) => e['uid'] == userId);
                    } else if (_selectedUsers.length < 100) {
                      _selectedUsers
                          .add({'uid': userId, 'name': name, 'avatar': avatar});
                    }
                  });
                },
                leading: CircleAvatar(
                  radius: 25,
                  backgroundImage: avatar.isNotEmpty
                      ? CachedNetworkImageProvider(avatar)
                      : null,
                  child: avatar.isEmpty ? Text(name[0].toUpperCase()) : null,
                ),
                title: Text(name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black)),
                trailing: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isSelected
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    color:
                        isSelected ? Colors.blue : Colors.grey.withOpacity(0.5),
                    size: 28,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showError(String msg) {
    HapticFeedback.vibrate();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Diqqat"),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
              child: const Text("Tushunarli"),
              onPressed: () => Navigator.pop(context))
        ],
      ),
    );
  }
}
