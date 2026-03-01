import 'dart:math';
import 'package:intl/intl.dart';

class ChatHelpers {
  /// 1. Sonlarni formatlash (Masalan: 1500 -> 1.5K, 1200000 -> 1.2M)
  static String formatNumbers(int num) {
    if (num >= 1000000) {
      double res = num / 1000000;
      return "${res.toStringAsFixed(res.truncateToDouble() == res ? 0 : 1)}M";
    } else if (num >= 1000) {
      double res = num / 1000;
      return "${res.toStringAsFixed(res.truncateToDouble() == res ? 0 : 1)}K";
    } else {
      return num.toString();
    }
  }

  /// 2. Vaqtni nisbiy formatlash (Chat ro'yxati uchun)
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return "hozirgina";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes} daqiqa oldin";
    } else if (diff.inHours < 24 && dateTime.day == now.day) {
      return DateFormat('HH:mm').format(dateTime); // Bugun bo'lsa faqat soat
    } else if (diff.inDays == 1 || (now.day - dateTime.day == 1)) {
      return "kecha";
    } else if (diff.inDays < 7) {
      return "${diff.inDays} kun oldin";
    } else {
      return DateFormat('dd.MM.yyyy').format(dateTime);
    }
  }

  /// 3. Fayl hajmini formatlash (To'g'ri matematik mantiq bilan)
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];

    // Logarifmik hisoblash (dart:math orqali)
    var i = (log(bytes) / log(1024)).floor();

    // Natijani formatlash (masalan: 1.25 MB)
    var size = bytes / pow(1024, i);
    return "${size.toStringAsFixed(1)} ${suffixes[i]}";
  }

  /// 4. Online/Last Seen statusini formatlash
  static String formatLastSeen(dynamic lastSeen) {
    if (lastSeen == null) return "noma'lum";

    DateTime dateTime;
    if (lastSeen is DateTime) {
      dateTime = lastSeen;
    } else {
      // Firebase Timestamp bo'lsa DateTime ga o'girish
      dateTime = lastSeen.toDate();
    }

    final now = DateTime.now();
    final diff = now.difference(dateTime);

    // 2 daqiqadan kam bo'lsa - online
    if (diff.inMinutes < 2) return "online";

    final String timeStr = DateFormat('HH:mm').format(dateTime);

    if (diff.inDays == 0 && dateTime.day == now.day) {
      return "bugun $timeStr da bo'lgan";
    } else if (diff.inDays == 1 || (now.day - dateTime.day == 1)) {
      return "kecha $timeStr da bo'lgan";
    } else {
      return "${DateFormat('dd.MM').format(dateTime)} $timeStr da bo'lgan";
    }
  }

  /// 5. Chat ichidagi xabarlar vaqti uchun qisqa format
  static String formatChatMessageTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }
}
