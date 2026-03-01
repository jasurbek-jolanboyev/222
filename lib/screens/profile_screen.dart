import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../widgets/verified_name.dart';
import '../providers/theme_provider.dart';
import 'admin/admin_dashboard.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;

  String get effectiveUserId {
    if (widget.uid.isNotEmpty) return widget.uid;
    return FirebaseAuth.instance.currentUser?.uid ?? "";
  }

  // --- PROFIL RASMINI YANGILASH ---
  Future<void> _updateAvatar() async {
    final uid = effectiveUserId;
    if (uid.isEmpty) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 35,
      maxWidth: 800,
    );

    if (image == null) return;

    setState(() => _isUploading = true);
    HapticFeedback.mediumImpact();

    try {
      final String fileName =
          'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('users/$uid/$fileName');

      if (kIsWeb) {
        await ref.putData(await image.readAsBytes(),
            SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(
            File(image.path), SettableMetadata(contentType: 'image/jpeg'));
      }

      final String url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'avatar': url});

      _showSnackBar("Profil rasmi muvaffaqiyatli yangilandi!");
    } catch (e) {
      _showSnackBar("Rasm yuklashda xatolik yuz berdi", isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- PROFILNI TO'LIQ TAHRIRLASH ---
  void _showEditProfileModal(Map<String, dynamic> data, bool isDark) {
    final nameCtrl = TextEditingController(text: data['username']);
    final bioCtrl = TextEditingController(text: data['bio']);
    final phoneCtrl = TextEditingController(text: data['phone'] ?? "");
    final tgUserCtrl = TextEditingController(text: data['tgUsername'] ?? "@");
    final bDayCtrl = TextEditingController(text: data['birthDate'] ?? "");
    bool isUpdating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.fromLTRB(
                20, 15, 20, MediaQuery.of(context).viewInsets.bottom + 30),
            decoration: BoxDecoration(
                color: isDark ? const Color(0xFF17212B) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(25))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 25),
                  const Text("Profilni tahrirlash",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _buildEditInput(
                      "Username", nameCtrl, isDark, CupertinoIcons.person),
                  _buildEditInput(
                      "Bio", bioCtrl, isDark, CupertinoIcons.text_quote,
                      maxLines: 2),
                  _buildEditInput(
                      "Telefon", phoneCtrl, isDark, CupertinoIcons.phone,
                      keyboardType: TextInputType.phone),
                  _buildEditInput(
                      "Telegram Link", tgUserCtrl, isDark, CupertinoIcons.at),
                  _buildEditInput("Tug'ilgan kun", bDayCtrl, isDark,
                      CupertinoIcons.calendar),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: isUpdating
                          ? null
                          : () async {
                              setModalState(() => isUpdating = true);
                              try {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(effectiveUserId)
                                    .update({
                                  'username': nameCtrl.text.trim(),
                                  'bio': bioCtrl.text.trim(),
                                  'phone': phoneCtrl.text.trim(),
                                  'tgUsername': tgUserCtrl.text.trim(),
                                  'birthDate': bDayCtrl.text.trim(),
                                });
                                Navigator.pop(context);
                                _showSnackBar("Ma'lumotlar saqlandi!");
                              } catch (e) {
                                _showSnackBar("Xatolik yuz berdi",
                                    isError: true);
                              } finally {
                                setModalState(() => isUpdating = false);
                              }
                            },
                      child: isUpdating
                          ? const CupertinoActivityIndicator(
                              color: Colors.white)
                          : const Text("SAQLASH"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final uid = effectiveUserId;

    if (uid.isEmpty) {
      return const Scaffold(
          body: Center(child: Text("Siz tizimga kirmagansiz")));
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E1621) : const Color(0xFFF1F5F9),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Foydalanuvchi topilmadi"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String clubStatus = data['clubStatus'] ?? 'none';
          final String role = data['role'] ?? 'user';

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildCyberAppBar(data, isDark),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    children: [
                      // 1. Amallar qatori (Kamera, Tahrirlash, Sozlamalar)
                      _buildCyberActionRow(data, isDark),
                      const SizedBox(height: 15),

                      // 2. RAD ETILGANLIK XABARI (Agar status 'rejected' bo'lsa)
                      if (clubStatus == 'rejected') ...[
                        _buildRejectedGlassCard(data, context, isDark),
                        const SizedBox(height: 15),
                      ],

                      // 3. ASOSIY MA'LUMOTLAR (Telegram Style)
                      _buildCyberSection(isDark, [
                        _buildTelegramTile(data['phone'] ?? "Kiritilmagan",
                            "Mobil raqam", isDark),
                        _buildTelegramTile(data['tgUsername'] ?? "@user",
                            "Foydalanuvchi nomi", isDark),
                        _buildTelegramTile(
                            data['bio'] ?? "Bio yo'q", "Tarjimayi hol", isDark),
                        _buildTelegramTile(data['birthDate'] ?? "Kiritilmagan",
                            "Tug'ilgan kun", isDark),
                      ]),

                      const SizedBox(height: 10),

                      // 4. QO'SHIMCHA SOZLAMALAR VA AMALLAR
                      _buildCyberSection(isDark, [
                        _buildActionTile(CupertinoIcons.shield_fill,
                            "Hamjamiyat statusi", isDark,
                            trailing: _getStatusText(clubStatus),
                            iconColor: _getStatusColor(clubStatus), onTap: () {
                          if (clubStatus == 'none' ||
                              clubStatus == 'rejected') {
                            Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (_) =>
                                        const ClubRegistrationScreen()));
                          }
                        }),
                        if (role == 'admin')
                          _buildActionTile(
                              CupertinoIcons.lock_shield, "Admin Panel", isDark,
                              iconColor: Colors.orange,
                              onTap: () => Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                      builder: (_) => const AdminDashboard()))),
                        _buildActionTile(
                            CupertinoIcons.settings, "Sozlamalar", isDark,
                            onTap: () => Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (_) => const SettingsScreen()))),
                        _buildActionTile(CupertinoIcons.question_circle,
                            "Yordam markazi", isDark,
                            onTap: _contactAdmin),
                      ]),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- CYBER UI COMPONENTS ---
  Widget _buildCyberAppBar(Map<String, dynamic> data, bool isDark) {
    return SliverAppBar(
      expandedHeight: 450,
      pinned: true,
      stretch: true,
      // Orqa fon rangi isDark rejimiga qarab moslashadi
      backgroundColor: isDark ? const Color(0xFF17212B) : Colors.blueAccent,

      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
          StretchMode.fadeTitle,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Profil rasmi
            data['avatar'] != null && data['avatar'] != ""
                ? CachedNetworkImage(
                    imageUrl: data['avatar'],
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey[900]),
                  )
                : Container(
                    color: Colors.blueGrey,
                    child: const Icon(CupertinoIcons.person_fill,
                        size: 100, color: Colors.white24),
                  ),

            // 2. Gradiyent (Ism yaxshi ko'rinishi uchun pastdan soya)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black, // Pastda qora
                    Colors.black54, // O'rtada xira qora
                    Colors.transparent // Tepada shaffof
                  ],
                  stops: [0.0, 0.3, 0.6],
                ),
              ),
            ),

            // 3. Ism va Onlayn holati
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- YANGILANGAN ISM VA VERIFIKATSIYA ---
                  VerifiedName(
                    username: data['username'] ?? "Foydalanuvchi",
                    isVerified: data['isVerified'] ?? false,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32, // Biroz kattaroq qildik
                        fontWeight: FontWeight.w900, // Qalinroq stil
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                              color: Colors.black45,
                              blurRadius: 10,
                              offset: Offset(0, 2))
                        ]),
                    iconSize: 28,
                  ),
                  // ---------------------------------------

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: data['online'] == true
                                  ? Colors.greenAccent
                                  : Colors.grey,
                              shape: BoxShape.circle,
                              boxShadow: [
                                if (data['online'] == true)
                                  BoxShadow(
                                      color:
                                          Colors.greenAccent.withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2)
                              ])),
                      const SizedBox(width: 10),
                      Text(
                        data['online'] == true ? "onlayn" : "offlayn",
                        style: TextStyle(
                            color: data['online'] == true
                                ? Colors.greenAccent
                                : Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 4. Yuklanish indikatori (Avatar almashtirilayotgan bo'lsa)
            if (_isUploading)
              Container(
                color: Colors.black26,
                child: const Center(
                    child: CupertinoActivityIndicator(
                        radius: 20, color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCyberActionRow(Map<String, dynamic> data, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _cyberCircleBtn(CupertinoIcons.photo_camera, "Rasm belgilash",
            _updateAvatar, isDark),
        _cyberCircleBtn(CupertinoIcons.pencil, "Axborotni tahrirlash",
            () => _showEditProfileModal(data, isDark), isDark),
        _cyberCircleBtn(
            CupertinoIcons.settings,
            "Sozlamalar",
            () => Navigator.push(context,
                CupertinoPageRoute(builder: (_) => const SettingsScreen())),
            isDark),
      ],
    );
  }

  Widget _cyberCircleBtn(
      IconData icon, String label, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2733) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  const BoxShadow(color: Colors.black12, blurRadius: 4)
                ]),
            child: Icon(icon, color: Colors.blueAccent, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTelegramTile(String title, String subtitle, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black, fontSize: 16)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
        ],
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, bool isDark,
      {required VoidCallback onTap, Color? iconColor, String? trailing}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor ?? Colors.blueAccent, size: 22),
      title: Text(title,
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black, fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(trailing,
                style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          const Icon(CupertinoIcons.chevron_right,
              size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildCyberSection(bool isDark, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2733) : Colors.white,
          borderRadius: BorderRadius.circular(15)),
      child: Column(children: children),
    );
  }

  Widget _buildEditInput(
      String label, TextEditingController ctrl, bool isDark, IconData icon,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: CupertinoTextField(
        controller: ctrl,
        placeholder: label,
        maxLines: maxLines,
        keyboardType: keyboardType,
        prefix: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Icon(icon, color: Colors.blueAccent, size: 20)),
        padding: const EdgeInsets.all(14),
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey[100],
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSnackBar(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating));
  }

// --- BU BLOKNI ESKISI BILAN ALMASHTIRING ---
  String _getStatusText(String s) {
    if (s == 'approved') return "A'zo";
    if (s == 'pending') return "Kutilmoqda";
    if (s == 'rejected') return "Rad etilgan";
    return "Qo'shilish";
  }

  Color _getStatusColor(String s) {
    if (s == 'approved') return Colors.green;
    if (s == 'pending') return Colors.orange;
    if (s == 'rejected') return Colors.redAccent;
    return Colors.blueAccent;
  }

// --- BU BUTUNLAY YANGI BLOK, KLASS OXIRIGA QO'SHING ---
  Widget _buildRejectedGlassCard(
      Map<String, dynamic> data, BuildContext context, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.redAccent.withOpacity(0.1)
                : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: Colors.redAccent.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            children: [
              const Icon(CupertinoIcons.xmark_octagon_fill,
                  color: Colors.redAccent, size: 40),
              const SizedBox(height: 10),
              const Text("Arizangiz rad etildi",
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "Sabab: ${data['rejectReason'] ?? 'Ma\'lumotlar to\'liq emas'}",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 13),
              ),
              const SizedBox(height: 15),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
                onPressed: () => Navigator.push(
                    context,
                    CupertinoPageRoute(
                        builder: (_) => const ClubRegistrationScreen())),
                child: const Text("Qayta topshirish",
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _contactAdmin() async {
    final Uri url = Uri.parse('https://t.me/serinaqu');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication))
      _showSnackBar("Telegram yuklanmadi", isError: true);
  }
}

// ==========================================
// 4. KLUBGA ARIZA TOPSHIRISH EKRANI (CYBER DESIGN)
// ==========================================
class ClubRegistrationScreen extends StatefulWidget {
  const ClubRegistrationScreen({super.key});
  @override
  State<ClubRegistrationScreen> createState() => _ClubRegistrationScreenState();
}

class _ClubRegistrationScreenState extends State<ClubRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _uniController = TextEditingController();
  final _phoneController = TextEditingController();

  XFile? _card;
  XFile? _selfie;
  bool _loading = false;

  // Rasmni tanlash (Sifatni optimallashtirish bilan)
  Future<void> _pick(bool isSelfie) async {
    final i = await ImagePicker().pickImage(
        source: isSelfie ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 35, // Storage joyini tejash uchun
        maxWidth: 1000);
    if (i != null) {
      HapticFeedback.lightImpact();
      setState(() => isSelfie ? _selfie = i : _card = i);
    }
  }

  // Faylni yuklash funksiyasi (Metadata bilan)
  Future<String> _uploadFile(File f, String path) async {
    final r = FirebaseStorage.instance.ref().child(path);
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'picked-by-user': FirebaseAuth.instance.currentUser?.uid ?? 'unknown'
      },
    );
    await r.putFile(f, metadata);
    return await r.getDownloadURL();
  }

  // Arizani yuborish
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _card == null ||
        _selfie == null) {
      _showSnackBar("Iltimos, barcha ma'lumotlar va rasmlarni kiriting!",
          isError: true);
      return;
    }

    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // 1. Rasmlarni yuklash
      final cardUrl = await _uploadFile(
          File(_card!.path), "club_apps/$uid/student_card.jpg");
      final selfieUrl =
          await _uploadFile(File(_selfie!.path), "club_apps/$uid/selfie.jpg");

      // 2. Firestore'ga yozish (Batch ishlatish tavsiya etiladi yoki oddiy set)
      final batch = FirebaseFirestore.instance.batch();

      final appRef =
          FirebaseFirestore.instance.collection('club_applications').doc(uid);
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      batch.set(appRef, {
        'userId': uid,
        'fullName': _nameController.text.trim(),
        'university': _uniController.text.trim(),
        'phone': _phoneController.text.trim(),
        'studentCardUrl': cardUrl,
        'selfieUrl': selfieUrl,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      batch.update(userRef, {'clubStatus': 'pending'});

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar(
            "Arizangiz muvaffaqiyatli yuborildi. Admin javobini kuting!",
            isError: false);
      }
    } catch (e) {
      _showSnackBar("Xatolik yuz berdi: $e", isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    // Sariq chiziqni yo'qotish uchun rangni e'lon qilamiz
    final primaryColor = Colors.blueAccent;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E1621) : const Color(0xFFF1F5F9),
      appBar: CupertinoNavigationBar(
        middle: Text("Klubga a'zo bo'lish",
            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        backgroundColor: isDark ? const Color(0xFF17212B) : Colors.white,
        border: null,
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CupertinoActivityIndicator(radius: 15),
                  const SizedBox(height: 15),
                  Text("Hujjatlar yuklanmoqda...",
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54))
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("SHAXSIY MA'LUMOTLAR"),
                    _inp(_nameController, "F.I.O (To'liq)",
                        CupertinoIcons.person, isDark),
                    _inp(_uniController, "O'quv muassasasi",
                        CupertinoIcons.book, isDark),
                    _inp(_phoneController, "Bog'lanish uchun tel",
                        CupertinoIcons.phone, isDark,
                        keyboard: TextInputType.phone),
                    const SizedBox(height: 25),
                    _sectionTitle("HUJJATLAR FOTOSURATI"),
                    const Text(
                        "Talabalik guvohnomasi va u bilan birga tushilgan selfie yuklanishi shart.",
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        _imgBox("Guvohnoma (Oldi)", _card, () => _pick(false),
                            isDark),
                        const SizedBox(width: 15),
                        _imgBox("Selfie (Hujjat bilan)", _selfie,
                            () => _pick(true), isDark),
                      ],
                    ),
                    const SizedBox(height: 40),
                    // TUGMA QISMI YANGILANDI:
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: CupertinoButton(
                        // Mana endi primaryColor ishlatildi, sariq chiziq yo'qoladi
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(15),
                        onPressed: _submit,
                        child: const Text("ARIZANI TASDIQLASH",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text("Ma'lumotlaringiz xavfsizligi kafolatlanadi",
                          style: TextStyle(color: Colors.grey, fontSize: 11)),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(left: 5, bottom: 10),
        child: Text(title,
            style: const TextStyle(
                color: Colors.blueAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      );

  Widget _inp(TextEditingController c, String h, IconData i, bool d,
          {TextInputType? keyboard}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: CupertinoTextField(
          controller: c,
          placeholder: h,
          keyboardType: keyboard,
          prefix: Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Icon(i, color: Colors.blueAccent, size: 20)),
          padding: const EdgeInsets.all(16),
          placeholderStyle: const TextStyle(color: Colors.grey, fontSize: 15),
          style: TextStyle(color: d ? Colors.white : Colors.black),
          decoration: BoxDecoration(
              color: d ? const Color(0xFF1C2733) : Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ]),
        ),
      );

  Widget _imgBox(String t, XFile? f, VoidCallback o, bool d) => Expanded(
        child: GestureDetector(
          onTap: o,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: d ? const Color(0xFF1C2733) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: f != null
                      ? Colors.blueAccent
                      : Colors.blueAccent.withOpacity(0.1),
                  width: 2),
            ),
            child: f == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        const Icon(CupertinoIcons.cloud_upload_fill,
                            color: Colors.blueAccent, size: 35),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(t,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500)),
                        )
                      ])
                : ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(File(f.path), fit: BoxFit.cover)),
          ),
        ),
      );
}
