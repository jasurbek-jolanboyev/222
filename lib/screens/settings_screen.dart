import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/cupertino.dart';

import '../providers/theme_provider.dart';
import 'admin/admin_dashboard.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final String _appVersion = "1.0.8";

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final user = FirebaseAuth.instance.currentUser;

    // Cyber Ranglar Palitrasi
    final Color bgColor =
        isDark ? const Color(0xFF0E1621) : const Color(0xFFF1F5F9);
    final Color tileColor = isDark ? const Color(0xFF17212B) : Colors.white;
    final Color headerColor = isDark ? Colors.blueAccent : Colors.blueGrey;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildCyberAppBar(context, isDark, tileColor),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final role = data?['role'] ?? 'user';

          return ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              const SizedBox(height: 10),

              // --- 1. SOZLAMALAR BO'LIMI ---
              _buildSectionHeader("SOZLAMALAR", headerColor),
              _buildGroupContainer(tileColor, isDark, [
                _buildCyberTile(
                  isDark,
                  icon: CupertinoIcons.lock_shield_fill,
                  title: "privacy_safety".tr(),
                  subtitle: "Kod va himoya choralari",
                  color: Colors.green,
                  onTap: () => _showComingSoon("Maxfiylik"),
                ),
                _buildCyberTile(
                  isDark,
                  icon: CupertinoIcons.device_phone_portrait,
                  title: "active_sessions".tr(),
                  subtitle: "Ulangan qurilmalar",
                  color: Colors.lightBlue,
                  onTap: _showActiveSessions,
                ),
                _buildCyberTile(
                  isDark,
                  icon: CupertinoIcons.globe,
                  title: "language".tr(),
                  subtitle: _getCurrentLanguageName(),
                  color: Colors.purpleAccent,
                  onTap: () => _showLanguageModal(isDark),
                ),
                _buildSwitchTile(
                  isDark,
                  icon: isDark
                      ? CupertinoIcons.moon_stars_fill
                      : CupertinoIcons.sun_max_fill,
                  title: "dark_mode".tr(),
                  color: Colors.indigoAccent,
                  value: isDark,
                  onChanged: (val) {
                    HapticFeedback.mediumImpact();
                    themeProvider.toggleTheme(val);
                  },
                ),
              ]),

              // --- 2. XIZMATLAR BO'LIMI ---
              _buildSectionHeader("XIZMATLAR", headerColor),
              _buildGroupContainer(tileColor, isDark, [
                _buildCyberTile(
                  isDark,
                  icon: CupertinoIcons.star_circle_fill,
                  title: "Premium Bundle",
                  subtitle: "Barcha cheklovlarni olib tashlash",
                  color: Colors.orange,
                  onTap: () => _showComingSoon("Premium"),
                ),
                _buildCyberTile(
                  isDark,
                  icon: CupertinoIcons.bell_fill,
                  title: "Bildirishnomalar",
                  subtitle: "Ovoz va xabarlar",
                  color: Colors.redAccent,
                  onTap: () => _showComingSoon("Bildirishnomalar"),
                ),
              ]),

              // --- 3. MA'MURIYAT VA YORDAM ---
              _buildSectionHeader("BOSHQUV VA YORDAM", headerColor),
              _buildGroupContainer(tileColor, isDark, [
                _buildCyberTile(
                  isDark,
                  icon: CupertinoIcons.question_circle_fill,
                  title: "support".tr(),
                  color: Colors.blue,
                  onTap: _contactAdmin,
                ),
                if (role == 'admin')
                  _buildCyberTile(
                    isDark,
                    icon: CupertinoIcons.ant_fill,
                    title: "admin_dashboard".tr(),
                    subtitle: "Tizimni boshqarish paneli",
                    color: Colors.orange,
                    onTap: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (_) => const AdminDashboard())),
                  ),
              ]),

              // --- 4. HISOB AMALLARI ---
              _buildSectionHeader("HISOB", headerColor),
              _buildGroupContainer(tileColor, isDark, [
                _buildCyberTile(
                  isDark,
                  icon: CupertinoIcons.arrow_right_square_fill,
                  title: "logout".tr(),
                  color: Colors.orange,
                  onTap: () => _showLogoutDialog(context, isDark),
                ),
                _buildCyberTile(
                  isDark,
                  icon: CupertinoIcons.trash_fill,
                  title: "delete_account".tr(),
                  color: Colors.red,
                  onTap: () => _confirmAccountDeletion(context, isDark),
                ),
              ]),

              const SizedBox(height: 40),
              _buildFooter(),
              const SizedBox(height: 50),
            ],
          );
        },
      ),
    );
  }

  // --- UI YORDAMCHILARI ---

  PreferredSizeWidget _buildCyberAppBar(
      BuildContext context, bool isDark, Color tileColor) {
    return AppBar(
      elevation: 0,
      backgroundColor: tileColor,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(CupertinoIcons.back,
            color: isDark ? Colors.white : Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        "settings".tr(),
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18),
      ),
    );
  }

  void _showActiveSessions() {
    HapticFeedback.lightImpact();
    String deviceType = Platform.isAndroid ? "Android" : "iOS";
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
              color:
                  isDarkValue(context) ? const Color(0xFF17212B) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(25))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 25),
              const Icon(CupertinoIcons.device_phone_portrait,
                  size: 50, color: Colors.blueAccent),
              const SizedBox(height: 15),
              const Text("Faol sessiyalar",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.phone_iphone, color: Colors.white)),
                title: Text("Ushbu qurilma ($deviceType)"),
                subtitle: const Text("Toshkent, O'zbekiston • 172.16.0.1"),
                trailing: const Text("Hozir",
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 25),
              SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("OK"))),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageModal(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF17212B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Tilni tanlang",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _langTile("O'zbekcha", const Locale('uz'), "🇺🇿"),
              _langTile("Русский", const Locale('ru'), "🇷🇺"),
              _langTile("English", const Locale('en'), "🇺🇸"),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, bool isDark) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text("logout".tr()),
        content: Text("logout_confirm".tr()),
        actions: [
          CupertinoDialogAction(
              child: Text("cancel".tr()), onPressed: () => Navigator.pop(ctx)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text("logout".tr()),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted)
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }

  void _confirmAccountDeletion(BuildContext context, bool isDark) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Hisobni o'chirish",
            style: TextStyle(color: Colors.red)),
        content: const Text(
            "Bu amal qaytarilmaydi. Barcha ma'lumotlaringiz butunlay o'chib ketadi."),
        actions: [
          CupertinoDialogAction(
              child: Text("cancel".tr()), onPressed: () => Navigator.pop(ctx)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("O'chirish"),
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .delete();
                await user?.delete();
                if (mounted)
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (route) => false);
              } catch (e) {
                _showSnackBar("Xavfsizlik uchun qayta login qiling!");
                Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }

  // --- KICHIK KOMPONENTLAR ---

  Widget _buildSectionHeader(String title, Color color) => Padding(
        padding: const EdgeInsets.fromLTRB(25, 20, 20, 8),
        child: Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 1.1)),
      );

  Widget _buildGroupContainer(
          Color color, bool isDark, List<Widget> children) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(15)),
        child: Column(children: children),
      );

  Widget _buildCyberTile(bool isDark,
      {required IconData icon,
      required String title,
      String? subtitle,
      required Color color,
      required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: TextStyle(
              fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey))
          : null,
      trailing: const Icon(CupertinoIcons.chevron_right,
          size: 14, color: Colors.grey),
    );
  }

  Widget _buildSwitchTile(bool isDark,
      {required IconData icon,
      required String title,
      required Color color,
      required bool value,
      required Function(bool) onChanged}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: TextStyle(
              fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
      trailing: CupertinoSwitch(
          value: value, activeColor: Colors.blueAccent, onChanged: onChanged),
    );
  }

  Widget _langTile(String name, Locale loc, String flag) => ListTile(
        leading: Text(flag, style: const TextStyle(fontSize: 22)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: context.locale == loc
            ? const Icon(Icons.check_circle, color: Colors.blue)
            : null,
        onTap: () {
          HapticFeedback.lightImpact();
          context.setLocale(loc);
          Navigator.pop(context);
        },
      );

  Widget _buildFooter() => Center(
        child: Column(
          children: [
            Text("Premium Cyber v$_appVersion",
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const Text("Designed with Cyber Style © 2026",
                style: TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      );

  void _showComingSoon(String title) {
    HapticFeedback.mediumImpact();
    _showSnackBar("$title bo'limi tez kunda qo'shiladi!");
  }

  String _getCurrentLanguageName() {
    final code = context.locale.languageCode;
    if (code == 'uz') return "O'zbekcha";
    if (code == 'ru') return "Русский";
    return "English";
  }

  bool isDarkValue(BuildContext context) =>
      Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

  Future<void> _contactAdmin() async {
    final Uri url = Uri.parse('https://t.me/serinaqu');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication))
      _showSnackBar("Telegram ochilmadi.");
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}
