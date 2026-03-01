import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class ChatBackground extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const ChatBackground({super.key, required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // ChatProvider'dan joriy tanlangan mavzuni olamiz
    final themeType = context.watch<ChatProvider>().currentTheme;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: _getBackgroundColor(themeType, isDark),
      ),
      child: Stack(
        children: [
          // 1. Dinamik Blur effektlari (Faqat Cyber mavzusi uchun)
          if (isDark && themeType == ChatThemeType.cyber) ...[
            _buildBlurSpot(Alignment.topRight, Colors.cyan.withOpacity(0.15)),
            _buildBlurSpot(
                Alignment.bottomLeft, Colors.purple.withOpacity(0.15)),
          ],

          // 2. Dinamik Naqshlar (CustomPainter orqali)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: _getPatternOpacity(themeType, isDark),
                child: CustomPaint(
                  painter: PatternPainter(
                    isDark: isDark,
                    themeType: themeType,
                  ),
                ),
              ),
            ),
          ),

          // 3. Asosiy Kontent
          SafeArea(child: child),
        ],
      ),
    );
  }

  // Mavzuga qarab orqa fon rangini aniqlash
  Color _getBackgroundColor(ChatThemeType theme, bool dark) {
    if (!dark) return const Color(0xFFF1F5F9);
    switch (theme) {
      case ChatThemeType.cyber:
        return const Color(0xFF0F172A); // To'q ko'k (Cyber)
      case ChatThemeType.matrix:
        return const Color(0xFF000D00); // Qora-yashil (Matrix)
      default:
        return const Color(0xFF0E1621); // Telegram uslubidagi klassik to'q rang
    }
  }

  // Naqshlarning ko'rinish darajasi
  double _getPatternOpacity(ChatThemeType theme, bool dark) {
    if (theme == ChatThemeType.matrix) return dark ? 0.2 : 0.1;
    return dark ? 0.05 : 0.08;
  }

  Widget _buildBlurSpot(Alignment alignment, Color color) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }
}

// --- DINAMIK NAQSH CHIZUVCHI ---
class PatternPainter extends CustomPainter {
  final bool isDark;
  final ChatThemeType themeType;

  PatternPainter({required this.isDark, required this.themeType});

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final color = isDark ? Colors.white : Colors.blueGrey;

    // Mavzuga qarab ikonkalarni tanlash
    List<IconData> icons;
    if (themeType == ChatThemeType.matrix) {
      icons = [
        Icons.alternate_email,
        Icons.security,
        Icons.code
      ]; // Matrix uchun simvollar
    } else if (themeType == ChatThemeType.cyber) {
      icons = [Icons.terminal, Icons.memory, Icons.lan, Icons.data_object];
    } else {
      icons = [Icons.chat_bubble_outline, Icons.alternate_email]; // Klassik
    }

    for (double x = 0; x < size.width; x += 70) {
      for (double y = 0; y < size.height; y += 70) {
        final icon = icons[(x + y).toInt() % icons.length];

        textPainter.text = TextSpan(
          text: themeType == ChatThemeType.matrix
              ? ((x + y) % 2 == 0 ? "1" : "0") // Matrixda 0 va 1 lar
              : String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: themeType == ChatThemeType.matrix ? 14 : 20,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: themeType == ChatThemeType.matrix
                ? Colors.green.withOpacity(0.3)
                : color.withOpacity(0.3),
            fontWeight: FontWeight.bold,
          ),
        );

        textPainter.layout();
        canvas.save();
        canvas.translate(x, y);
        if (themeType != ChatThemeType.matrix)
          canvas.rotate(0.3); // Matrixdan boshqasini qiyshaytiramiz
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant PatternPainter oldDelegate) =>
      oldDelegate.themeType != themeType || oldDelegate.isDark != isDark;
}
