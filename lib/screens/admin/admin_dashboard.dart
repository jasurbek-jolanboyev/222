import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

// ==========================================
// 0. GLOBAL ADMIN UTILS (Takrorlanishni oldini olish)
// ==========================================
class AdminUtils {
  static String formatDate(dynamic ts) {
    if (ts == null) return "-";
    DateTime dt = (ts as Timestamp).toDate();
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  static void showImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
                child: InteractiveViewer(
                    child: CachedNetworkImage(imageUrl: url))),
            Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context))),
          ],
        ),
      ),
    );
  }

  static void toast(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red : Colors.green),
    );
  }
}

// ==========================================
// ASOSIY DASHBOARD
// ==========================================
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const _AdminHomeTab(),
    const _ClubApplicationsTab(),
    const _UserDatabaseTab(),
    const _ContentManagerTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.white38,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chart_bar_square_fill),
              label: "Statistika"),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.checkmark_shield_fill),
              label: "Arizalar"),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person_3_fill), label: "Userlar"),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.news), label: "Postlar"),
        ],
      ),
    );
  }
}

// ==========================================
// 1. STATISTIKA TABI
// ==========================================
class _AdminHomeTab extends StatelessWidget {
  const _AdminHomeTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
            backgroundColor: Color(0xFF1E293B),
            title: Text("DASHBOARD"),
            pinned: true,
            centerTitle: true),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.4,
                  children: [
                    _statCard("USERS", "users", Colors.blue),
                    _statCard("POSTS", "posts", Colors.purple),
                    _statCard("VERIFIED", "users", Colors.green,
                        field: 'isVerified'),
                    _statCard("ADMINS", "users", Colors.orange,
                        field: 'role', value: 'admin'),
                  ],
                ),
                const SizedBox(height: 25),
                _buildAlertBanner(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String title, String col, Color c,
      {String? field, dynamic value}) {
    Query q = FirebaseFirestore.instance.collection(col);
    if (field != null) q = q.where(field, isEqualTo: value ?? true);

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        return Container(
          decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(snap.hasData ? "${snap.data!.docs.length}" : "...",
                  style: TextStyle(
                      color: c, fontSize: 26, fontWeight: FontWeight.bold)),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 10, letterSpacing: 1.2)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertBanner() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('club_applications')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty)
          return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.orange.withOpacity(0.5))),
          child: Row(children: [
            const Icon(Icons.bolt, color: Colors.orange),
            const SizedBox(width: 10),
            Text("Kutilayotgan arizalar: ${snap.data!.docs.length} ta",
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
        );
      },
    );
  }
}

// ==========================================
// 2. ARIZALAR VA KLUB AZOLARI (Optimallashtirilgan)
// ==========================================
class _ClubApplicationsTab extends StatefulWidget {
  const _ClubApplicationsTab();
  @override
  State<_ClubApplicationsTab> createState() => _ClubApplicationsTabState();
}

class _ClubApplicationsTabState extends State<_ClubApplicationsTab> {
  int _activeTab = 0; // 0: Pending, 1: Approved

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Klub Boshqaruvi"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Row(
            children: [
              _tabBtn("Yangi", 0),
              _tabBtn("A'zolar", 1),
            ],
          ),
        ),
      ),
      body: _buildStream(),
    );
  }

  Widget _tabBtn(String txt, int idx) {
    bool isSel = _activeTab == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = idx),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: isSel ? Colors.blueAccent : Colors.transparent,
                      width: 2))),
          child: Text(txt,
              style: TextStyle(
                  color: isSel ? Colors.white : Colors.white38,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _buildStream() {
    String status = _activeTab == 0 ? 'pending' : 'approved';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('club_applications')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CupertinoActivityIndicator());
        if (snap.data!.docs.isEmpty)
          return const Center(
              child: Text("Ma'lumot topilmadi",
                  style: TextStyle(color: Colors.white24)));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snap.data!.docs.length,
          itemBuilder: (context, i) {
            final doc = snap.data!.docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _ApplicationCard(docId: doc.id, data: data);
          },
        );
      },
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _ApplicationCard({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    bool isPending = data['status'] == 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: CircleAvatar(
            backgroundColor: isPending ? Colors.blueAccent : Colors.green,
            child: Icon(isPending ? Icons.mail : Icons.verified,
                color: Colors.white, size: 18)),
        title: Text(data['fullName'] ?? "Noma'lum",
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        subtitle: Text(data['university'] ?? "-",
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row("Tel:", data['phone']),
                _row("Telegram:", "@${data['telegram']}"),
                _row("Sana:", AdminUtils.formatDate(data['createdAt'])),
                const SizedBox(height: 15),
                Row(children: [
                  _img(context, "Talaba kartasi", data['studentCardUrl']),
                  const SizedBox(width: 10),
                  _img(context, "Selfie", data['selfieUrl']),
                ]),
                if (isPending) ...[
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                        child: _actionBtn("RAD ETISH", Colors.red,
                            () => _handle(context, false))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _actionBtn("TASDIQLASH", Colors.green,
                            () => _handle(context, true))),
                  ])
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _row(String l, String? v) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text("$l ${v ?? '-'}",
          style: const TextStyle(color: Colors.white70, fontSize: 12)));

  Widget _img(BuildContext context, String l, String? url) {
    return Expanded(
      child: GestureDetector(
        onTap: () => url != null ? AdminUtils.showImage(context, url) : null,
        child: Column(children: [
          Container(
              height: 80,
              decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10)),
              child: url != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child:
                          CachedNetworkImage(imageUrl: url, fit: BoxFit.cover))
                  : const Icon(Icons.broken_image, color: Colors.white10)),
          Text(l, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ]),
      ),
    );
  }

  Widget _actionBtn(String t, Color c, VoidCallback f) => CupertinoButton(
      padding: EdgeInsets.zero,
      color: c.withOpacity(0.1),
      onPressed: f,
      child: Text(t,
          style:
              TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)));

  Future<void> _handle(BuildContext context, bool approve) async {
    String? reason;
    if (!approve) {
      // Rad etish sababini so'rash (Sodda variant)
      reason = "Hujjatlar mos kelmadi";
    }

    try {
      await FirebaseFirestore.instance
          .collection('club_applications')
          .doc(docId)
          .update({
        'status': approve ? 'approved' : 'rejected',
        if (!approve) 'rejectReason': reason
      });
      if (data['userId'] != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(data['userId'])
            .update({
          'role': approve ? 'club_member' : 'user',
          'isVerified': approve,
          'clubStatus': approve ? 'approved' : 'rejected'
        });
      }
      AdminUtils.toast(
          context, approve ? "Klubga qabul qilindi" : "Rad etildi");
    } catch (e) {
      AdminUtils.toast(context, "Xato: $e", isError: true);
    }
  }
}

class _UserDatabaseTab extends StatefulWidget {
  const _UserDatabaseTab();
  @override
  State<_UserDatabaseTab> createState() => _UserDatabaseTabState();
}

class _UserDatabaseTabState extends State<_UserDatabaseTab> {
  String _search = "";
  String _filter = "all";

  // --- ASOSIY AMALLAR FUNKSIYASI ---
  // Bu funksiya orqali barcha Firebase amallarini markazlashgan holda bajaramiz
  Future<void> _processAction(String uid, String actionType,
      {Map<String, dynamic>? extraData}) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      String msg = "";

      switch (actionType) {
        case 'toggle_verify':
          bool current = extraData?['isVerified'] ?? false;
          await docRef.update({'isVerified': !current});
          msg = !current
              ? "Foydalanuvchi verifikatsiya qilindi"
              : "Verifikatsiya olib tashlandi";
          break;

        case 'toggle_block':
          bool current = extraData?['isBlocked'] ?? false;
          await docRef.update({'isBlocked': !current});
          msg = !current ? "Foydalanuvchi bloklandi" : "Blokdan chiqarildi";
          break;

        case 'delete':
          await docRef.delete();
          msg = "Foydalanuvchi bazadan o'chirildi";
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Xatolik yuz berdi: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text("Foydalanuvchilar",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.blueAccent),
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: "all", child: Text("Barcha foydalanuvchilar")),
              const PopupMenuItem(
                  value: "admin", child: Text("Faqat Adminlar")),
              const PopupMenuItem(
                  value: "club_member", child: Text("Klub a'zolari")),
            ],
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(65),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: CupertinoSearchTextField(
              placeholder: "Ism yoki login orqali qidiruv...",
              style: const TextStyle(color: Colors.white, fontSize: 14),
              backgroundColor: Colors.white.withOpacity(0.05),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
        ),
      ),
      body: _buildUserList(),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snap) {
        if (snap.hasError)
          return const Center(child: Text("Ma'lumot olishda xatolik"));
        if (!snap.hasData)
          return const Center(child: CupertinoActivityIndicator());

        final docs = snap.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final name = (d['username'] ?? "").toString().toLowerCase();
          bool mSearch = name.contains(_search);
          bool mFilter = _filter == "all" || d['role'] == _filter;
          return mSearch && mFilter;
        }).toList();

        if (docs.isEmpty) {
          return const Center(
              child: Text("Foydalanuvchilar topilmadi",
                  style: TextStyle(color: Colors.white38)));
        }

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final bool isVerified = data['isVerified'] ?? false;
            final bool isBlocked = data['isBlocked'] ?? false;

            return Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  backgroundImage: data['avatar'] != null
                      ? CachedNetworkImageProvider(data['avatar'])
                      : null,
                  child: data['avatar'] == null
                      ? const Icon(Icons.person, color: Colors.blueAccent)
                      : null,
                ),
                title: Row(
                  children: [
                    Text(data['username'] ?? "User",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    if (isVerified)
                      const Padding(
                          padding: EdgeInsets.only(left: 5),
                          child: Icon(Icons.verified,
                              color: Colors.blue, size: 16)),
                  ],
                ),
                subtitle: Text(
                  "${data['role']?.toString().toUpperCase() ?? "USER"} ${isBlocked ? '• BLOKLANGAN' : ''}",
                  style: TextStyle(
                      color: isBlocked ? Colors.redAccent : Colors.white38,
                      fontSize: 11),
                ),
                trailing: const Icon(CupertinoIcons.ellipsis_vertical,
                    color: Colors.white54, size: 20),
                onTap: () => _showUserActions(docs[i].id, data),
              ),
            );
          },
        );
      },
    );
  }

  void _showUserActions(String uid, Map<String, dynamic> data) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(data['username'] ?? "Foydalanuvchi boshqaruvi"),
        message: const Text("Tanlangan foydalanuvchi uchun amalni belgilang"),
        actions: [
          // 1. VERIFIKATSIYA TUGMASI
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _processAction(uid, 'toggle_verify', extraData: data);
            },
            child: Text(data['isVerified'] == true
                ? "Verifikatsiyani bekor qilish"
                : "Verifikatsiya tasdiqlash"),
          ),
          // 2. BLOKLASH TUGMASI
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _processAction(uid, 'toggle_block', extraData: data);
            },
            child: Text(
              data['isBlocked'] == true
                  ? "Blokdan chiqarish"
                  : "Foydalanuvchini bloklash",
              style: const TextStyle(color: Colors.orange),
            ),
          ),
          // 3. O'CHIRISH TUGMASI
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              // O'chirishdan oldin so'rash (xavfsizlik uchun)
              _confirmDelete(uid);
            },
            child: const Text("Hisobni butunlay o'chirish"),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text("Bekor qilish"),
        ),
      ),
    );
  }

  void _confirmDelete(String uid) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Haqiqatdan ham o'chirmoqchimisiz?"),
        content: const Text("Bu amalni ortga qaytarib bo'lmaydi!"),
        actions: [
          CupertinoDialogAction(
              child: const Text("Yo'q"),
              onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Ha, o'chirilsin"),
            onPressed: () {
              Navigator.pop(context);
              _processAction(uid, 'delete');
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. CONTENT MANAGER (Smart Feed System)
// ==========================================
class _ContentManagerTab extends StatefulWidget {
  const _ContentManagerTab();
  @override
  State<_ContentManagerTab> createState() => _ContentManagerTabState();
}

class _ContentManagerTabState extends State<_ContentManagerTab> {
  // Controllerlar
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _vUrl = TextEditingController();
  final _link = TextEditingController();
  final _btnName = TextEditingController();

  XFile? _img;
  bool _loading = false;
  String? _editingPostId;
  String? _currentImageUrl;

  // --- POSTNI CHOP ETISH YOKI YANGILASH ---
  Future<void> _publishOrUpdate() async {
    // 1. Validatsiya
    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      _showMsg("Sarlavha va Tavsif majburiy!", isErr: true);
      return;
    }

    setState(() => _loading = true);

    try {
      String? finalUrl = _currentImageUrl;

      // 2. Rasm bilan ishlash
      if (_img != null) {
        // Agar tahrirlash bo'lsa va yangi rasm yuklansa, eskisini o'chirish (Storage tozaligi uchun)
        if (_editingPostId != null && _currentImageUrl != null) {
          try {
            await FirebaseStorage.instance
                .refFromURL(_currentImageUrl!)
                .delete();
          } catch (e) {
            debugPrint("Eski rasm o'chmadi (ehtimol mavjud emas): $e");
          }
        }

        // Yangi rasmni yuklash
        final ref = FirebaseStorage.instance
            .ref()
            .child('posts/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(
            File(_img!.path), SettableMetadata(contentType: 'image/jpeg'));
        finalUrl = await ref.getDownloadURL();
      }

      // 3. Ma'lumotlar Map'i
      final postData = {
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'videoUrl': _vUrl.text.trim(),
        'webLink': _link.text.trim(),
        'buttonName':
            _btnName.text.trim().isEmpty ? "Batafsil" : _btnName.text.trim(),
        'imageUrl': finalUrl,
        'updatedAt': FieldValue.serverTimestamp(),
        'type': _vUrl.text.trim().isNotEmpty ? 'video' : 'image',
      };

      // 4. Firestore operatsiyasi
      if (_editingPostId != null) {
        // Tahrirlash (Update)
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(_editingPostId)
            .update(postData);
        _showMsg("Post muvaffaqiyatli yangilandi!");
      } else {
        // Yangi qo'shish (Add)
        postData['createdAt'] = FieldValue.serverTimestamp();
        postData['views'] = 0;
        postData['likes'] = 0;
        postData['shares'] = 0;

        await FirebaseFirestore.instance.collection('posts').add(postData);
        _showMsg("Post Feedga qo'shildi!");
      }

      _clearForm();
      // Muvaffaqiyatli yakunlangach, Boshqarish tabiga o'tkazish
      DefaultTabController.of(context).animateTo(1);
    } catch (e) {
      _showMsg("Xatolik: $e", isErr: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- TAHRIRLASH REJIMINI BOSHLASH ---
  void _startEdit(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _editingPostId = doc.id;
      _title.text = data['title'] ?? "";
      _desc.text = data['description'] ?? "";
      _vUrl.text = data['videoUrl'] ?? "";
      _link.text = data['webLink'] ?? "";
      _btnName.text = data['buttonName'] ?? "Batafsil";
      _currentImageUrl = data['imageUrl'];
      _img = null;
    });
    // "Yangi Post" (forma) bo'limiga o'tkazish
    DefaultTabController.of(context).animateTo(0);
  }

  void _clearForm() {
    _title.clear();
    _desc.clear();
    _vUrl.clear();
    _link.clear();
    _btnName.clear();
    setState(() {
      _img = null;
      _editingPostId = null;
      _currentImageUrl = null;
    });
  }

  void _showMsg(String m, {bool isErr = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: isErr ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // 1. DefaultTabController eng tepada bo'lishi kerak
    return DefaultTabController(
      length: 2,
      child: Builder(
        // 2. Builder qo'shish shart! Bu yangi context yaratadi
        builder: (BuildContext context) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: const Color(0xFF1E293B),
              title: Text(_editingPostId != null
                  ? "Postni Tahrirlash"
                  : "Feed Boshqaruvi"),
              actions: [
                if (_editingPostId != null)
                  IconButton(
                      onPressed: _clearForm,
                      icon: const Icon(Icons.close, color: Colors.orange))
              ],
              bottom: const TabBar(
                  indicatorColor: Colors.blueAccent,
                  tabs: [Tab(text: "Yangi Post"), Tab(text: "Boshqarish")]),
            ),
            body: TabBarView(children: [
              _buildAddTab(context),
              _buildManageTab(context) // Bunga ham uzatamiz
            ]),
          );
        },
      ),
    );
  }

  // --- 1-TAB: FORM ---
  Widget _buildAddTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _inp(_title, "Post Sarlavhasi", CupertinoIcons.pencil),
        const SizedBox(height: 12),
        _inp(_desc, "Batafsil ma'lumot", CupertinoIcons.text_alignleft, max: 6),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _inp(_btnName, "Tugma nomi", CupertinoIcons.tag)),
          const SizedBox(width: 10),
          Expanded(child: _inp(_link, "Havola (URL)", CupertinoIcons.link)),
        ]),
        const SizedBox(height: 12),
        _inp(
            _vUrl, "Video URL (YouTube/Direct)", CupertinoIcons.play_rectangle),
        const SizedBox(height: 20),
        _buildImagePickerArea(),
        const SizedBox(height: 30),
        _loading
            ? const Center(
                child: CupertinoActivityIndicator(
                    radius: 15, color: Colors.blueAccent))
            : SizedBox(
                width: double.infinity,
                height: 55,
                child: CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(15),
                    onPressed: _publishOrUpdate,
                    child: Text(
                        _editingPostId != null
                            ? "O'ZGARISHLARNI SAQLASH"
                            : "FEEDGA CHOP ETISH",
                        style: const TextStyle(fontWeight: FontWeight.bold)))),
        const SizedBox(height: 50),
      ]),
    );
  }

  // --- 2-TAB: MANAGE ---
  Widget _buildManageTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CupertinoActivityIndicator());

        final docs = snap.data!.docs;
        if (docs.isEmpty)
          return const Center(
              child: Text("Postlar mavjud emas",
                  style: TextStyle(color: Colors.white24)));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 50,
                    height: 50,
                    color: Colors.white10,
                    child: data['imageUrl'] != null
                        ? CachedNetworkImage(
                            imageUrl: data['imageUrl'],
                            fit: BoxFit.cover,
                            placeholder: (c, u) =>
                                const CupertinoActivityIndicator(),
                          )
                        : const Icon(Icons.article, color: Colors.blueAccent),
                  ),
                ),
                title: Text(data['title'] ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                subtitle: Text(
                    "${data['views'] ?? 0} ko'rilgan • ${data['type']}",
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.pencil_circle_fill,
                          color: Colors.blueAccent),
                      onPressed: () => _startEdit(doc),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.trash,
                          color: Colors.redAccent, size: 20),
                      onPressed: () => _deletePost(doc.id, data['imageUrl']),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImagePickerArea() {
    return GestureDetector(
      onTap: () async {
        final x = await ImagePicker()
            .pickImage(source: ImageSource.gallery, imageQuality: 70);
        if (x != null) setState(() => _img = x);
      },
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white10, width: 2)),
        child: _img != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(File(_img!.path), fit: BoxFit.cover))
            : (_currentImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: CachedNetworkImage(
                        imageUrl: _currentImageUrl!, fit: BoxFit.cover))
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Icon(Icons.add_photo_alternate_rounded,
                            color: Colors.blueAccent, size: 40),
                        SizedBox(height: 10),
                        Text("Rasm tanlash",
                            style: TextStyle(color: Colors.white24))
                      ])),
      ),
    );
  }

  Widget _inp(TextEditingController c, String h, IconData i, {int max = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: max,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
              prefixIcon: Icon(i, color: Colors.blueAccent, size: 20),
              hintText: h,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide:
                      const BorderSide(color: Colors.blueAccent, width: 1))),
        ),
      );

  Future<void> _deletePost(String id, String? url) async {
    final confirm = await showCupertinoDialog<bool>(
        context: context,
        builder: (c) => CupertinoAlertDialog(
              title: const Text("O'chirish"),
              content:
                  const Text("Ushbu post butunlay o'chiriladi. Rozimisiz?"),
              actions: [
                CupertinoDialogAction(
                    child: const Text("Yo'q"),
                    onPressed: () => Navigator.pop(c, false)),
                CupertinoDialogAction(
                    isDestructiveAction: true,
                    child: const Text("Ha"),
                    onPressed: () => Navigator.pop(c, true)),
              ],
            ));

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('posts').doc(id).delete();
        if (url != null)
          await FirebaseStorage.instance.refFromURL(url).delete();
        _showMsg("Post o'chirildi.");
      } catch (e) {
        _showMsg("Xatolik: $e", isErr: true);
      }
    }
  }
}
