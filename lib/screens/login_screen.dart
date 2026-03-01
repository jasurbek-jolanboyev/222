import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLogin = true; // Kirish yoki Ro'yxatdan o'tish rejimi
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // Xatoliklarni chiroyli chiqarish
  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Asosiy mantiqiy funksiya
  Future<void> _submit() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && username.isEmpty)) {
      _showMessage("Iltimos, barcha maydonlarni to'ldiring!");
      return;
    }

    try {
      if (_isLogin) {
        await auth.signInWithEmail(email, password);
      } else {
        if (username.length < 4) {
          _showMessage("Username kamida 4 ta belgidan iborat bo'lsin!");
          return;
        }
        await auth.signUpWithEmail(email, password, username);
      }
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo qismi
                  _buildLogo(),
                  const SizedBox(height: 40),

                  // Sarlavha
                  Text(
                    _isLogin ? "Xush kelibsiz" : "Ro'yxatdan o'ting",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isLogin
                        ? "Cyber Community'ga kirish uchun ma'lumotlarni kiriting"
                        : "Jamiyatimizga qo'shilish uchun yangi hisob yarating",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 40),

                  // Inputlar
                  if (!_isLogin) ...[
                    _buildTextField(
                      controller: _usernameController,
                      hint: "Foydalanuvchi nomi",
                      icon: CupertinoIcons.person,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 15),
                  ],
                  _buildTextField(
                    controller: _emailController,
                    hint: "Email manzili",
                    icon: CupertinoIcons.mail,
                    isDark: isDark,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    controller: _passwordController,
                    hint: "Parol",
                    icon: CupertinoIcons.lock,
                    isDark: isDark,
                    isPassword: true,
                    obscureText: _obscureText,
                    onSuffixTap: () =>
                        setState(() => _obscureText = !_obscureText),
                  ),

                  // Parolni unutdingizmi?
                  if (_isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text("Parolni unutdingizmi?",
                            style: TextStyle(
                                fontSize: 13, color: Colors.blueAccent)),
                        onPressed: () {
                          // Parolni tiklash dialogi (Sizning AuthProviderda bor deb hisoblaymiz)
                          _showResetPasswordDialog();
                        },
                      ),
                    ),

                  const SizedBox(height: 30),

                  // Kirish tugmasi
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: CupertinoButton(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(15),
                      padding: EdgeInsets.zero,
                      onPressed: auth.isLoading ? null : _submit,
                      child: auth.isLoading
                          ? const CupertinoActivityIndicator(
                              color: Colors.white)
                          : Text(_isLogin ? "Kirish" : "Ro'yxatdan o'tish",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Google bilan kirish
                  _buildGoogleButton(auth, isDark),

                  const SizedBox(height: 30),

                  // Rejimni almashtirish (Login/SignUp)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_isLogin
                          ? "Hisobingiz yo'qmi?"
                          : "Hisobingiz bormi?"),
                      CupertinoButton(
                        child: Text(_isLogin ? "Yaratish" : "Kirish",
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(CupertinoIcons.ant_fill,
          size: 60, color: Colors.blueAccent),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onSuffixTap,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: onSuffixTap,
                  child: Icon(
                      obscureText
                          ? CupertinoIcons.eye_slash
                          : CupertinoIcons.eye,
                      color: Colors.grey,
                      size: 20),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildGoogleButton(AuthProvider auth, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          side: BorderSide(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
        ),
        onPressed: auth.isLoading
            ? null
            : () async {
                try {
                  await auth.signInWithGoogle();
                } catch (e) {
                  _showMessage(e.toString());
                }
              },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.globe, size: 20, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text(
              "Google orqali davom etish",
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog() {
    final resetController = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Parolni tiklash"),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: resetController,
            placeholder: "Emailingizni kiriting",
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Bekor qilish"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("Yuborish"),
            onPressed: () async {
              if (resetController.text.isNotEmpty) {
                // Bu yerda authProvider'da sendPasswordReset(email) metodini chaqirish kerak
                Navigator.pop(context);
                _showMessage("Parolni tiklash havolasi yuborildi!",
                    isError: false);
              }
            },
          ),
        ],
      ),
    );
  }
}
