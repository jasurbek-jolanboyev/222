import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../main.dart'; // navigatorKey shu yerda bo'lishi shart
import '../screens/chat_screen.dart';
import '../screens/home_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Fondagi xabarlarni qayta ishlash
  debugPrint("Handling background message: ${message.messageId}");
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Smart Filter: Foydalanuvchi hozir aynan qaysi chat oynasida turganini bilish uchun
  static String? currentOpenedChatId;

  // Android kanali sozlamalari (High Importance)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'cyber_chat_priority_channel',
    'Cyber Messages',
    description: 'Yangi xabarlar va bildirishnomalar',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static Future<void> initialize() async {
    try {
      // 1. Ruxsatnomalar (iOS 18 va Android 13+)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );
      debugPrint(
          'Bildirishnoma ruxsat holati: ${settings.authorizationStatus}');

      // 2. Foreground sozlamalari (Ilova ochiqligida tizim bannerini boshqarish)
      await _messaging.setForegroundNotificationPresentationOptions(
        alert:
            false, // Tizim standart bannerini o'chiramiz (o'rniga bizning Glass UI chiqadi)
        badge: true,
        sound: true,
      );

      // 3. Local Notifications Initializatsiya
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestCriticalPermission: true,
        defaultPresentAlert: true,
        defaultPresentSound: true,
        defaultPresentBadge: true,
      );

      await _localNotifications.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null) {
            try {
              // String payloadni Map formatiga qaytaramiz
              final Map<String, dynamic> data = jsonDecode(details.payload!);
              _handleMessageClick(data);
            } catch (e) {
              // Agar payload JSON bo'lmasa (masalan, toString natijasi bo'lsa)
              debugPrint("Payload decode error: $e");
            }
          }
        },
      );

      // Android kanalni tizimda yaratish
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // --- ASOSIY LISTENERLAR ---

      // A) Foreground (Ilova ochiq bo'lganda kelgan xabar)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final String? incomingChatId = message.data['chatId'];

        // FILTR: Foydalanuvchi aynan shu chatda ochiq tursa bildirishnoma ko'rsatmaymiz
        if (incomingChatId != null && incomingChatId == currentOpenedChatId) {
          return;
        }

        if (message.notification != null) {
          // Ham tizim ovozi uchun Local Notification, ham maxsus Glass UI
          _showLocalNotification(message.notification!, message.data);
          _showGlassOverlay(
            message.notification!.title ?? "Yangi xabar",
            message.notification!.body ?? "",
            message.data,
          );
        }
      });

      // B) Ilova fonda (Background) bo'lganda bildirishnoma bosilsa
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessageClick(message.data);
      });

      // D) Ilova butkul yopiq (Terminated) bo'lganda bildirishnoma orqali kirilsa
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) _handleMessageClick(message.data);
      });

      // Background handler o'rnatish
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Token yangilanishini kuzatish
      _messaging.onTokenRefresh
          .listen((newToken) => _saveTokenToFirestore(newToken));
    } catch (e) {
      debugPrint("Notification Init Error: $e");
    }
  }

  // --- LOCAL NOTIFICATION (Tizim darajasida ovoz va banner) ---
  static void _showLocalNotification(
      RemoteNotification notification, Map<String, dynamic> data) {
    final String threadId = data['chatId'] ?? 'general_group';

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          groupKey: threadId,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: false, // Glass UI borligi uchun bannerni yashiramiz
          presentSound: true,
          presentBadge: true,
          threadIdentifier: threadId,
          interruptionLevel: InterruptionLevel.active, // iOS 18 Heads-up style
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  // --- GLASS OVERLAY UI (Shaffof bildirishnoma) ---
  static void _showGlassOverlay(
      String title, String body, Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    OverlayState? overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 10,
        right: 10,
        child: Dismissible(
          key: UniqueKey(),
          direction: DismissDirection.up,
          onDismissed: (_) => overlayEntry.remove(),
          child: Material(
            color: Colors.transparent,
            child: _GlassNotificationWidget(
              title: title,
              body: body,
              onTap: () {
                if (overlayEntry.mounted) overlayEntry.remove();
                _handleMessageClick(data);
              },
            ),
          ),
        ),
      ),
    );

    overlayState.insert(overlayEntry);

    // 4 soniyadan keyin avtomatik yopish
    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  // --- CHATGA YOKI HOMEGA YO'NALTIRISH ---
  static void _handleMessageClick(Map<String, dynamic> data) {
    final String? chatId = data['chatId'];

    if (chatId != null) {
      // Agar chatId bo'lsa, aniq chat ekraniga
      navigatorKey.currentState?.push(
        MaterialPageRoute(
            builder: (context) => ChatScreen(
                  roomId: chatId,
                  otherUserId: data['senderId'] ?? '',
                  otherUsername: data['senderName'] ?? 'Chat',
                  otherAvatar: data['senderAvatar'] ?? '',
                )),
      );
    } else {
      // Bo'lmasa HomeScreen'ga (Lobby)
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  // --- TOKEN BOSHQARUVI ---
  static Future<void> updateFCMToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      if (Platform.isIOS) await _messaging.getAPNSToken();
      String? token = await _messaging.getToken();
      if (token != null) await _saveTokenToFirestore(token);
    } catch (e) {
      debugPrint("FCM Update Error: $e");
    }
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
        'platform': Platform.operatingSystem,
      }, SetOptions(merge: true));
      debugPrint("FCM Token saqlandi ✅");
    }
  }

  static Future<void> deleteToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': FieldValue.delete(),
        });
      }
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint("Token o'chirildi 🗑");
    }
  }
}

// --- SHAFFOF SHISHA (GLASS) VIDJETI ---
class _GlassNotificationWidget extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onTap;

  const _GlassNotificationWidget(
      {required this.title, required this.body, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: Colors.blueAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      Text(
                        body,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
