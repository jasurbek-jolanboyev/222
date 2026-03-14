import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Provayderlar
import '../providers/auth_provider.dart' as custom;
import '../providers/theme_provider.dart';

// Servislar va Ekranlar
import '../services/notification_service.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'create_post_screen.dart';

// Yangi Tablar (Eslatma: 'tabs/group_tab.dart' ikki marta import qilingan edi, bittasini qoldirdik)
import 'tabs/chat_tab.dart';
import 'tabs/feed_tab.dart';
import 'tabs/group_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // --- STATE O'ZGARUVCHILARI ---
  int _selectedIndex = 0;
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {};
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  bool _isFabVisible = true;

  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateUserStatus(true);

    // Scroll bo'lganda FAB ni yashirish mantiqi
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (_isFabVisible) setState(() => _isFabVisible = false);
      } else if (_scrollController.position.userScrollDirection ==
          ScrollDirection.forward) {
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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (currentUserId.isNotEmpty) {
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

  // --- ASOSIY BUILD ---
  @override
  Widget build(BuildContext context) {
    final bool isDark = Provider.of<ThemeProvider>(context).isDarkMode;
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
              // Profil tabida AppBar ko'rinmaydi
              if (_selectedIndex != 3) _buildModernAppBar(isDark),
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
                      _isSelectionMode = false;
                      _selectedItems.clear();
                    });
                  },
                  children: [
                    // 1. CHAT TAB
                    ChatTab(
                      isSearching: _isSearching,
                      searchText: _searchText,
                      isSelectionMode: _isSelectionMode,
                      selectedItems: _selectedItems,
                      onLongPress: (mode, id) => setState(() {
                        _isSelectionMode = mode;
                        _selectedItems.add(id);
                      }),
                      onTap: (id) => _handleItemTap(id),
                    ),
                    // 2. LENTA TAB
                    FeedTab(isDark: isDark),
                    // 3. GURUH TAB
                    GroupTab(
                      isSearching: _isSearching,
                      searchText: _searchText,
                      isSelectionMode: _isSelectionMode,
                      selectedItems: _selectedItems,
                      isFabVisible: _isFabVisible,
                      scrollController: _scrollController,
                      isDark: isDark,
                      onLongPress: (mode, id) => setState(() {
                        _isSelectionMode = mode;
                        _selectedItems.add(id);
                      }),
                      onTap: (id) => _handleItemTap(id),
                    ),
                    // 4. PROFIL TAB
                    ProfileScreen(uid: currentUserId),
                  ],
                ),
              ),
            ],
          ),
          _buildAnimatedBottomNav(context, isDark),
        ],
      ),
    );
  }

  // --- QO'SHIMCHA METODLAR ---

  void _handleItemTap(String id) {
    if (!_isSelectionMode) return;
    setState(() {
      if (_selectedItems.contains(id)) {
        _selectedItems.remove(id);
        if (_selectedItems.isEmpty) _isSelectionMode = false;
      } else {
        _selectedItems.add(id);
      }
    });
  }

  Widget _buildModernAppBar(bool isDark) {
    if (_isSelectionMode) {
      return Container(
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 20,
            bottom: 15),
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white),
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
            Text("${_selectedItems.length} tanlandi",
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            _headerIconButton(
                isDark, CupertinoIcons.trash_fill, _deleteSelectedItems),
          ],
        ),
      );
    }

    String title = ["Chatlar", "Yangiliklar", "Guruhlar"][_selectedIndex];

    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 20,
          right: 20,
          bottom: 15),
      decoration:
          BoxDecoration(color: isDark ? const Color(0xFF0F172A) : Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!_isSearching)
            Text(title,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -1)),
          if (_isSearching && (_selectedIndex == 0 || _selectedIndex == 2))
            Expanded(
              child: CupertinoSearchTextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                onChanged: (val) =>
                    setState(() => _searchText = val.toLowerCase()),
              ),
            ),
          Row(
            children: [
              if (_selectedIndex == 0 && !_isSearching)
                _headerIconButton(
                    isDark,
                    CupertinoIcons.bell_fill,
                    () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (_) => const NotificationsScreen()))),
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
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            shape: BoxShape.circle),
        child:
            Icon(icon, size: 22, color: isDark ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _buildAnimatedBottomNav(BuildContext context, bool isDark) {
    return Positioned(
      bottom: 20,
      left: 15,
      right: 15,
      child: Row(
        children: [
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
          _buildProfileNavItem(3, isDark),
        ],
      ),
    );
  }

  Widget _buildAddPostButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(context,
            CupertinoPageRoute(builder: (_) => const CreatePostScreen()));
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.15), shape: BoxShape.circle),
        child:
            const Icon(CupertinoIcons.add, color: Colors.blueAccent, size: 22),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, bool isDark) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _pageController.animateToPage(index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isSelected
                  ? Colors.blueAccent
                  : (isDark ? Colors.white54 : Colors.grey),
              size: 22),
          Text(label,
              style: TextStyle(
                  color: isSelected
                      ? Colors.blueAccent
                      : (isDark ? Colors.white38 : Colors.grey),
                  fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildProfileNavItem(int index, bool isDark) {
    bool isSelected = _selectedIndex == index;
    final authProvider = Provider.of<custom.AuthProvider>(context);
    String? userAvatar = authProvider.userData?['avatar'];

    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn);
      },
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          shape: BoxShape.circle,
          border: Border.all(
              color: isSelected
                  ? Colors.blueAccent
                  : Colors.white.withOpacity(0.15)),
        ),
        child: Center(
          child: CircleAvatar(
            radius: 14,
            backgroundImage: (userAvatar != null && userAvatar.isNotEmpty)
                ? CachedNetworkImageProvider(userAvatar)
                : null,
            child: (userAvatar == null || userAvatar.isEmpty)
                ? const Icon(CupertinoIcons.person_alt_circle_fill, size: 28)
                : null,
          ),
        ),
      ),
    );
  }

  // --- O'CHIRISH MANTIQI ---
  void _deleteSelectedItems() async {
    bool? confirm = await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Tasdiqlash"),
        content: Text(
            "Tanlangan ${_selectedItems.length} ta elementni o'chirishni xohlaysizmi?"),
        actions: [
          CupertinoDialogAction(
              child: const Text("Bekor qilish"),
              onPressed: () => Navigator.pop(context, false)),
          CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text("O'chirish"),
              onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      for (String id in _selectedItems) {
        await FirebaseFirestore.instance.collection('chats').doc(id).delete();
      }
      setState(() {
        _isSelectionMode = false;
        _selectedItems.clear();
      });
    }
  }
}
