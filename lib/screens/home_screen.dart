import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
// Muhim: main.dart dagi kabi 'as custom' prefiksini ishlatamiz
import '../providers/auth_provider.dart' as custom;
import '../providers/theme_provider.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'group_chat_screen.dart';
import 'feed_screen.dart';
import '../widgets/verified_name.dart';
import 'create_group_screen.dart'; // Fayl nomini o'zingizda qanday bo'lsa shunday yozing
import 'package:flutter/services.dart';
import '../services/notification_service.dart';
import 'notifications_screen.dart';
import 'package:flutter/rendering.dart';
import 'create_post_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {};
  final PageController _pageController = PageController();
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  // --- YANGI QO'SHILGAN O'ZGARUVCHILAR ---
  final ScrollController _scrollController = ScrollController();
  bool _isFabVisible = true; // Tugmani ko'rinishi

  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateUserStatus(true);

    // --- SCROLLNI KUZATISH QISMI ---
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        // Pastga scroll bo'lganda tugmani yashirish
        if (_isFabVisible) setState(() => _isFabVisible = false);
      } else if (_scrollController.position.userScrollDirection ==
          ScrollDirection.forward) {
        // Tepaga scroll bo'lganda tugmani ko'rsatish
        if (!_isFabVisible) setState(() => _isFabVisible = true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.updateFCMToken();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _searchController.dispose();

    // --- CONTROLLERNI TOZALASH ---
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (currentUserId.isNotEmpty) {
      // Ilova yopilsa offline, ochilsa online qilish
      _updateUserStatus(state == AppLifecycleState.resumed);
    }
  }

  void _updateUserStatus(bool isOnline) {
    if (currentUserId.isEmpty) return;
    FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
      'online': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }).catchError((e) => debugPrint("Status update error: $e"));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    // AuthProvider'ni custom prefiksi bilan chaqiramiz
    final authProvider = Provider.of<custom.AuthProvider>(context);

    final bool isAdmin = authProvider.userData?['role'] == 'admin';
    final Color bgColor =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Column(
            children: [
              // 1. App Bar
              if (_selectedIndex != 3) _buildModernAppBar(isDark),

              // 2. Sahifalar
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _selectedIndex = index;
                      _isSearching = false;
                      _searchText = "";
                      _searchController.clear();
                    });
                  },
                  children: [
                    _buildChatList(isDark),
                    _buildNewsFeed(isDark),
                    _buildGroupList(isDark, isAdmin),
                    ProfileScreen(uid: currentUserId),
                  ],
                ),
              ),
            ],
          ),

          // 3. Navigation Bar
          _buildAnimatedBottomNav(context, isDark),
        ],
      ),
    );
  }

  // --- KOMPONENTLAR ---

  Widget _buildModernAppBar(bool isDark) {
    // --- 1. TANLASH REJIMI UCHUN APP BAR ---
    if (_isSelectionMode) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 10, // Tugma uchun biroz kichraytirildi
          right: 20,
          bottom: 15,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(CupertinoIcons.xmark,
                  color: isDark ? Colors.white : Colors.black),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedItems.clear();
              }),
            ),
            const SizedBox(width: 10),
            Text(
              "${_selectedItems.length} tanlandi",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const Spacer(),
            _headerIconButton(
              isDark,
              CupertinoIcons.trash_fill,
              _deleteSelectedItems, // O'chirish funksiyasi
            ),
          ],
        ),
      );
    }

    // --- 2. ODDIY REJIM (ESKI KODINGIZ) ---
    String title = ["Chatlar", "Yangiliklar", "Guruhlar"][_selectedIndex];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 15,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sarlavha (Qidiruv bo'lmagan holatda)
          if (!_isSearching)
            Text(title,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -1)),

          // Qidiruv maydoni
          if (_isSearching && (_selectedIndex == 0 || _selectedIndex == 2))
            Expanded(
              child: CupertinoSearchTextField(
                controller: _searchController,
                autofocus: true,
                backgroundColor:
                    isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                onChanged: (val) =>
                    setState(() => _searchText = val.toLowerCase()),
              ),
            ),

          Row(
            children: [
              // Bildirishnomalar
              if (_selectedIndex == 0 && !_isSearching)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _headerIconButton(
                    isDark,
                    CupertinoIcons.bell_fill,
                    () {
                      // Navigatsiyani shu yerga yozamiz
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                ),

              // Qidiruv tugmasi
              if (_selectedIndex == 0 || _selectedIndex == 2)
                _headerIconButton(
                  isDark,
                  _isSearching
                      ? CupertinoIcons.xmark_circle_fill
                      : CupertinoIcons.search,
                  () => setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) _searchController.clear();
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton(bool isDark, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child:
            Icon(icon, size: 22, color: isDark ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _buildChatList(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: _isSearching
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

        // --- QIDIRUV REJIMI ---
        if (_isSearching) {
          // 1. Agar qidiruv maydoni bo'sh bo'lsa, foydalanuvchilarni ko'rsatmaymiz
          if (_searchText.trim().isEmpty) {
            return _buildEmptyState(
                "Qidirish uchun foydalanuvchi ismini kiriting");
          }

          // 2. Bazadagi foydalanuvchilarni matn bo'yicha filtrlash
          final filteredUsers = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final username = (data['username'] ?? "").toString().toLowerCase();
            // O'zimizni qidiruvda chiqarmaymiz va ismga qarab qidiramiz
            return doc.id != currentUserId &&
                username.contains(_searchText.toLowerCase());
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
                onStartChat: _startChat,
              );
            },
          );
        }

        // --- ODDIY CHATLAR RO'YXATI REJIMI ---
        if (docs.isEmpty) return _buildEmptyState("Suhbatlar mavjud emas");

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final docId = docs[index].id;
            final data = docs[index].data() as Map<String, dynamic>;

            // Chatdagi ikkinchi foydalanuvchini aniqlash
            final List users = data['users'] ?? [];
            final otherId =
                users.firstWhere((id) => id != currentUserId, orElse: () => "");
            final bool isSelected = _selectedItems.contains(docId);

            return GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _isSelectionMode = true;
                  _selectedItems.add(docId);
                });
              },
              onTap: _isSelectionMode
                  ? () {
                      setState(() {
                        if (isSelected) {
                          _selectedItems.remove(docId);
                          if (_selectedItems.isEmpty) _isSelectionMode = false;
                        } else {
                          _selectedItems.add(docId);
                        }
                      });
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: isSelected
                    ? Colors.blueAccent.withOpacity(0.15)
                    : Colors.transparent,
                child: AbsorbPointer(
                  absorbing: _isSelectionMode,
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

  Widget _buildNewsFeed(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CupertinoActivityIndicator());
        final posts = snapshot.data!.docs;
        if (posts.isEmpty) return _buildEmptyState("Hozircha yangiliklar yo'q");

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final data = posts[index].data() as Map<String, dynamic>;
            final String docId = posts[index].id; // Hujjat ID sini olamiz

            return _EnhancedPostCard(
              post: data,
              postId: docId, // ID uzatiladi
              isDark: isDark,
              onTap: () {
                // Detal sahifasiga o'tish
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) =>
                        UnifiedPostDetail(post: data, postId: docId),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGroupList(bool isDark, bool isAdmin) {
    return Stack(
      children: [
        // 1. Guruhlar ro'yxati
        StreamBuilder<QuerySnapshot>(
          stream: _isSearching
              ? FirebaseFirestore.instance
                  .collection('chats')
                  .where('isGroup', isEqualTo: true)
                  .snapshots()
              : FirebaseFirestore.instance
                  .collection('chats')
                  .where('isGroup', isEqualTo: true)
                  .where('users', arrayContains: currentUserId)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Center(child: Text("Xatolik yuz berdi"));
            if (!snapshot.hasData)
              return const Center(child: CupertinoActivityIndicator());

            final docs = snapshot.data!.docs;

            if (_isSearching) {
              if (_searchText.trim().isEmpty)
                return _buildEmptyState("Guruh ismini kiriting...");
              final filteredGroups = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final gName =
                    (data['groupName'] ?? "").toString().toLowerCase();
                return gName.contains(_searchText.toLowerCase());
              }).toList();

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: filteredGroups
                    .map((doc) => _ModernGroupTile(
                          data: doc.data() as Map<String, dynamic>,
                          docId: doc.id,
                          isDark: isDark,
                        ))
                    .toList(),
              );
            }

            if (docs.isEmpty)
              return _buildEmptyState(
                  "Siz hali hech qanday guruhga a'zo emassiz");

            return ListView.builder(
              controller: _scrollController, // Scrollni kuzatish
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final docId = docs[index].id;
                final bool isSelected = _selectedItems.contains(docId);

                return GestureDetector(
                  onLongPress: () {
                    HapticFeedback.heavyImpact();
                    setState(() {
                      _isSelectionMode = true;
                      _selectedItems.add(docId);
                    });
                  },
                  onTap: _isSelectionMode
                      ? () {
                          setState(() {
                            if (isSelected) {
                              _selectedItems.remove(docId);
                              if (_selectedItems.isEmpty)
                                _isSelectionMode = false;
                            } else {
                              _selectedItems.add(docId);
                            }
                          });
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: isSelected
                          ? Colors.blueAccent.withOpacity(0.2)
                          : isDark
                              ? Colors.white.withOpacity(0.03)
                              : Colors.white,
                      border: Border.all(
                          color: isSelected
                              ? Colors.blueAccent
                              : isDark
                                  ? Colors.white10
                                  : Colors.black.withOpacity(0.05)),
                    ),
                    child: AbsorbPointer(
                      absorbing: _isSelectionMode,
                      child: _ModernGroupTile(
                        data: docs[index].data() as Map<String, dynamic>,
                        docId: docId,
                        isDark: isDark,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),

        // 2. Telegram uslubidagi suzuvchi tugma (O'ng pastki burchakda)
        if (!_isSearching && !_isSelectionMode)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn,
            bottom:
                _isFabVisible ? 110 : -70, // Scrollga qarab chiqadi/yashiriladi
            right: 20, // SKRINSHOTDAGIDEK O'NG TOMONGA O'TDI
            child: GestureDetector(
              onTap: () => _showCreateGroupSheet(isDark),
              child: Container(
                width: 56, // Dumaloq o'lcham
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF2EA6FF), // Telegram-style ko'k rang
                  shape: BoxShape.circle, // TO'LIQ DUMALOQ
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.add, // Telegramdagi kabi plus belgisi
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
      ],
    );
  }

// 1. Funksiya parametriga BuildContext context qo'shdik
  Widget _buildAnimatedBottomNav(BuildContext context, bool isDark) {
    return Positioned(
      bottom: 20,
      left: 15,
      right: 15,
      child: Row(
        children: [
          // --- CHAP TOMON (Kapsula) ---
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  height: 62,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _navItem(0, CupertinoIcons.chat_bubble_2_fill, "Chatlar",
                          isDark),
                      _navItem(1, CupertinoIcons.rocket_fill, "Lenta", isDark),

                      // BU YERDA: context argumentini qo'shib qo'ying
                      _buildAddPostButton(context, isDark),

                      _navItem(
                          2, CupertinoIcons.group_solid, "Guruhlar", isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // --- O'NG TOMONDAGI PROFIL BLOKI ---
          ClipRRect(
            borderRadius: BorderRadius.circular(31),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Center(
                  child: _navItem(3, CupertinoIcons.person_alt_circle_fill,
                      "Profil", isDark,
                      isProfile: true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPostButton(BuildContext context, bool isDark) {
    // BuildContext qo'shildi
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();

        // To'g'ridan-to'g'ri yangi sahifaga o'tish
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => const CreatePostScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
        ),
        child: const Icon(
          CupertinoIcons.add,
          color: Colors.blueAccent,
          size: 22,
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, bool isDark,
      {bool isProfile = false}) {
    bool isSelected = _selectedIndex == index;

    // AuthProvider orqali profil rasmiga kiramiz
    final authProvider = Provider.of<custom.AuthProvider>(context);
    String? userAvatar = authProvider.userData?['avatar'];

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 400),
          curve: Curves.fastOutSlowIn,
        );
        setState(() => _selectedIndex = index);
      },
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AGAR PROFIL TABI BO'LSA VA RASM BO'LSA
            if (isProfile)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.blueAccent : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 14, // Kichraytirilgan NavBarga mos o'lcham
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  backgroundImage: (userAvatar != null && userAvatar.isNotEmpty)
                      ? CachedNetworkImageProvider(userAvatar)
                      : null,
                  child: (userAvatar == null || userAvatar.isEmpty)
                      ? Icon(
                          CupertinoIcons.person_alt_circle_fill,
                          color: isSelected
                              ? Colors.blueAccent
                              : (isDark ? Colors.white54 : Colors.grey),
                          size: 28,
                        )
                      : null,
                ),
              )
            else
              // ODDIY TABLAR UCHUN IKONKA
              Icon(
                icon,
                color: isSelected
                    ? Colors.blueAccent
                    : (isDark ? Colors.white54 : Colors.grey),
                size: 22,
              ),

            if (!isProfile)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.blueAccent
                        : (isDark ? Colors.white38 : Colors.grey),
                    fontSize: 9,
                    fontWeight:
                        isSelected ? FontWeight.w800 : FontWeight.normal,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

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

  void _startChat(String otherId, String? name, String? avatar) async {
    String roomId = currentUserId.hashCode <= otherId.hashCode
        ? "${currentUserId}_$otherId"
        : "${otherId}_$currentUserId";

    await FirebaseFirestore.instance.collection('chats').doc(roomId).set({
      'users': [currentUserId, otherId],
      'isGroup': false,
      'lastTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
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

  void _deleteSelectedItems() async {
    // Tasdiqlash oynasi
    bool? confirm = await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Tasdiqlash"),
        content: Text(
            "Tanlangan ${_selectedItems.length} ta element bo'yicha amalni bajarishni xohlaysizmi?"),
        actions: [
          CupertinoDialogAction(
            child: const Text("Bekor qilish"),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Davom etish"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final firestore = FirebaseFirestore.instance;

      for (String id in _selectedItems) {
        try {
          // Chat ma'lumotlarini bazadan bir marta tekshirib olamiz
          DocumentSnapshot chatDoc =
              await firestore.collection('chats').doc(id).get();

          if (chatDoc.exists) {
            Map<String, dynamic> data = chatDoc.data() as Map<String, dynamic>;
            bool isGroup = data['isGroup'] ?? false;
            String ownerId = data['ownerId'] ?? "";

            if (isGroup) {
              // --- GURUH MANTIQI ---
              if (ownerId == currentUserId) {
                // Agar o'chirayotgan odam guruh egasi bo'lsa - hamma uchun o'chadi
                await firestore.collection('chats').doc(id).delete();
              } else {
                // Agar oddiy a'zo bo'lsa - faqat o'zini "users" arrayidan o'chiradi
                await firestore.collection('chats').doc(id).update({
                  'users': FieldValue.arrayRemove([currentUserId])
                });
              }
            } else {
              // --- ODDIY CHAT MANTIQI ---
              // Shaxsiy chatni o'chirish (Xohishga ko'ra butunlay yoki faqat o'zingizda)
              await firestore.collection('chats').doc(id).delete();
            }
          }
        } catch (e) {
          debugPrint("Amal bajarishda xato ($id): $e");
        }
      }

      // Rejimni yopish va tozalash
      setState(() {
        _isSelectionMode = false;
        _selectedItems.clear();
      });
    }
  }

  void _showCreateGroupSheet(bool isDark) {
    // ModalBottomSheet o'rniga yangi sahifaga o'tish (Navigation)
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const CreateGroupScreen(),
      ),
    );
  }
}

// --- SUB-WIDGETLAR (Cardlar va Tilelar) ---
class _EnhancedPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final String postId;
  final bool isDark;
  final VoidCallback onTap;

  const _EnhancedPostCard({
    required this.post,
    required this.postId,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rasm qismi + Hero Animation
            if (post['imageUrl'] != null && post['imageUrl'] != "")
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Hero(
                  tag: postId, // Detal sahifasi bilan bir xil bo'lishi shart
                  child: CachedNetworkImage(
                    imageUrl: post['imageUrl'],
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: isDark ? Colors.white10 : Colors.grey[200],
                      child: const Center(child: CupertinoActivityIndicator()),
                    ),
                  ),
                ),
              ),

            // Ma'lumot qismi
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kategoriya
                  Text(
                    (post['category'] ?? "Yangilik").toString().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Sarlavha
                  Text(
                    post['title'] ?? "Mavzu yo'q",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Qisqa tavsif
                  Text(
                    post['description'] ?? "",
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
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
}

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
                        otherAvatar: user['avatar'] ?? "",
                      ))),
          leading: Stack(
            children: [
              CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                      user['avatar'] != null && user['avatar'] != ""
                          ? CachedNetworkImageProvider(user['avatar'])
                          : null,
                  child: user['avatar'] == null || user['avatar'] == ""
                      ? const Icon(Icons.person, color: Colors.white)
                      : null),
              if (user['online'] == true)
                Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : Colors.white,
                                width: 2)))),
            ],
          ),

          // --- O'ZGARTIRILGAN QISM SHU YERDA ---
          title: VerifiedName(
            username: user['username'] ?? "Foydalanuvchi",
            isVerified:
                user['isVerified'] ?? false, // Bazadagi isVerified maydoni
            style: const TextStyle(fontWeight: FontWeight.bold),
            iconSize: 16,
          ),
          // -------------------------------------

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

class _ModernGroupTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isDark;
  const _ModernGroupTile(
      {required this.data, required this.docId, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: const CircleAvatar(
            backgroundColor: Colors.blueAccent,
            child: Icon(CupertinoIcons.group_solid, color: Colors.white)),
        title: Text(data['groupName'] ?? "Guruh",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text("Guruh suhbati", style: TextStyle(fontSize: 12)),
        onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(
                builder: (_) => GroupChatScreen(
                    roomId: docId, groupName: data['groupName']))),
      ),
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
