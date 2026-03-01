import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Pentest/UX: Mavzu o'zgarganda silliq o'tishni ta'minlash uchun Extension ishlatamiz
class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  static const String _themeKey = "isDarkMode";

  // --- SafeChat Brend Ranglari (Premium Palitra) ---
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);

  // Dark Palette
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkInput = Color(0xFF334155);

  // Light Palette
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightInput = Color(0xFFF1F5F9);

  ThemeProvider() {
    _loadTheme();
  }

  // --- MAVZUNI O'ZGARTIRISH (Smooth Transition) ---
  void toggleTheme(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;

    // Pentest/UX: Foydalanuvchi interfeysiga tebranish orqali javob qaytarish
    HapticFeedback.lightImpact();

    _updateSystemUI();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, value);
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    _updateSystemUI();
    notifyListeners();
  }

  // Tizim panellarini dinamik yangilash
  void _updateSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: _isDarkMode ? darkBg : Colors.white,
      systemNavigationBarIconBrightness:
          _isDarkMode ? Brightness.light : Brightness.dark,
    ));
  }

  // --- LIGHT THEME ---
  ThemeData get lightTheme => _buildTheme(Brightness.light);

  // --- DARK THEME ---
  ThemeData get darkTheme => _buildTheme(Brightness.dark);

  // Markazlashtirilgan Theme Builder (Kod takrorlanishini oldini oladi)
  ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: isDark ? darkBg : lightBg,
      cardColor: isDark ? darkCard : Colors.white,
      splashColor: primaryBlue.withOpacity(0.1),
      highlightColor: Colors.transparent,

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: brightness,
        primary: primaryBlue,
        onPrimary: Colors.white,
        surface: isDark ? darkCard : Colors.white,
        background: isDark ? darkBg : lightBg,
        error: errorRed,
      ),

      // AppBar - Ilovani "Yuzi"
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkBg : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1E293B),
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(
            color: isDark ? Colors.white : const Color(0xFF1E293B)),
      ),

      // Input Decoration (TextFields uchun mukammal ko'rinish)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkInput : lightInput,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        hintStyle: TextStyle(
            color: isDark ? Colors.white30 : Colors.black38, fontSize: 14),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? darkBg : Colors.white,
        selectedItemColor: primaryBlue,
        unselectedItemColor: isDark ? Colors.white24 : Colors.grey.shade400,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold),
        titleLarge: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF334155),
            fontSize: 16),
        bodyMedium: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
            fontSize: 14),
      ),
    );
  }
}
