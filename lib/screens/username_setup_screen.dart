import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as custom;

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isProcessing = false;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // --- XABARLARNI KO'RSATISH (CHIROYLISI) ---
  void _showMsg(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:
              const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- ASOSIY SAQLASH FUNKSIYASI ---
  Future<void> _saveUsername() async {
    final authProvider =
        Provider.of<custom.AuthProvider>(context, listen: false);
    final String name = _usernameController.text.trim().toLowerCase();

    // 1. Validatsiya (Xavfsiz va qisqa)
    if (name.isEmpty) {
      setState(() => _errorText = "Username kiritish shart");
      HapticFeedback.vibrate();
      return;
    }

    if (name.length < 4) {
      setState(() => _errorText = "Kamida 4 ta belgi bo'lishi kerak");
      HapticFeedback.vibrate();
      return;
    }

    // 2. Jarayonni boshlash
    setState(() {
      _isProcessing = true;
      _errorText = null;
    });

    try {
      // 3. Bandlikni tekshirish
      final bool isTaken = await authProvider.isUsernameTaken(name);

      if (isTaken) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorText = "Afsus, bu nom band. Boshqasini urinib ko'ring.";
          _isProcessing = false;
        });
        return;
      }

      // 4. Firestore'da yangilash
      await authProvider.updateUsername(name);

      HapticFeedback.mediumImpact();
      _showMsg("Hammasi tayyor! Xush kelibsiz.", Colors.green);

      // Eslatma: AuthWrapper avtomatik ravishda HomeScreen'ga o'tkazadi.
    } catch (e) {
      _showMsg(e.toString(), Colors.redAccent);
      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<custom.AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _isProcessing
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    authProvider.signOut();
                  },
            icon: const Icon(Icons.logout_rounded, color: Colors.grey),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Visual Brand element
              _buildModernLogo(),
              const SizedBox(height: 40),

              const Text(
                "Profilingizni sozlang",
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 12),
              const Text(
                "O'zingizga yoqqan noyob nomni kiriting.\nUni keyinchalik o'zgartira olmaysiz.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 45),

              // Username input maydoni
              _buildUsernameField(isDark),

              const SizedBox(height: 15),
              _buildInstructionText(),

              const SizedBox(height: 50),

              // Tasdiqlash tugmasi
              _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
        ),
        const Icon(CupertinoIcons.person_crop_circle_badge_checkmark,
            size: 80, color: Colors.blueAccent),
      ],
    );
  }

  Widget _buildUsernameField(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: TextField(
        controller: _usernameController,
        enabled: !_isProcessing,
        autofocus: true,
        // Pentest: SQL Injection va Script Injection himoyasi uchun filtr
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_.]')),
          LengthLimitingTextInputFormatter(16),
        ],
        onChanged: (v) {
          if (_errorText != null) setState(() => _errorText = null);
        },
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2),
        decoration: InputDecoration(
          prefixIcon: const Icon(CupertinoIcons.at, color: Colors.blueAccent),
          hintText: "username",
          errorText: _errorText,
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
        const SizedBox(width: 5),
        const Text(
          "Kichik harf, raqam va (_) ruxsat beriladi",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: _isProcessing ? null : _saveUsername,
        child: _isProcessing
            ? const CupertinoActivityIndicator(color: Colors.white)
            : const Text(
                "PROFILNI TAYYORLASH",
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 1),
              ),
      ),
    );
  }
}
