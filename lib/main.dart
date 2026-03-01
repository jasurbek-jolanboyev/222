import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/group_info_screen.dart';
import 'firebase_options.dart';
// Ismlar to'qnashmasligi uchun 'as custom' deb import qilamiz
import 'providers/auth_provider.dart' as custom;
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'services/notification_service.dart';
import 'screens/username_setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

/// 1. GLOBAL NAVIGATOR KEY
/// Bu kalit bildirishnoma bosilganda context-siz navigatsiya qilish uchun kerak.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Faqat vertikal rejimni saqlab qolish
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 2. FIREBASE INITIALIZATION
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

  // 3. LOCALIZATION
  await EasyLocalization.ensureInitialized();

  // 4. NOTIFICATIONS SERVICE INITIALIZE
  // Ilova ishga tushishi bilan bildirishnomalar xizmatini yoqamiz
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint("Notification Init Error: $e");
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('uz'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => custom.AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
        ],
        child: const OverlaySupport.global(
          child: MyApp(),
        ),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      // 5. NAVIGATOR KEY ULASH
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Cyber Community',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AuthStatusGate(),
    );
  }
}

class AuthStatusGate extends StatelessWidget {
  const AuthStatusGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Firebase ulanish holatini kutish
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(label: "Xavfsiz ulanish...");
        }

        final User? user = snapshot.data;

        // 2. Foydalanuvchi tizimga kirmagan bo'lsa
        if (user == null) {
          return const LoginScreen();
        }

        // 3. Foydalanuvchi ma'lumotlarini AuthProvider orqali tekshirish
        return Consumer<custom.AuthProvider>(
          builder: (context, auth, _) {
            if (auth.userData == null) {
              return const _LoadingScreen(label: "Profil yuklanmoqda...");
            }

            final userData = auth.userData!;

            // Bloklangan foydalanuvchini tekshirish
            if (userData['isBlocked'] == true) {
              return const LoginScreen();
            }

            // Username o'rnatilganini tekshirish
            final String username = userData['username'] ?? "";
            if (username.trim().isEmpty) {
              return const UsernameSetupScreen();
            }

            // --- DEEP LINK VA TOKEN YANGILASH ---
            // Bu qism ekran chizib bo'lingandan keyin bir marta ishlaydi
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // FCM Tokenni yangilash
              NotificationService.updateFCMToken();

              // WEB DEEP LINK: URL'ni tekshirish (?id=...)
              // Bu Uri.base mobil ilovada ham, brauzerda ham xavfsiz ishlaydi
              final Uri uri = Uri.base;
              if (uri.queryParameters.containsKey('id')) {
                final String? groupId = uri.queryParameters['id'];

                if (groupId != null && groupId.isNotEmpty) {
                  // Agar URLda guruh ID bo'lsa, foydalanuvchini o'sha guruhga yo'naltiramiz
                  // navigatorKey orqali context'siz o'tish
                  navigatorKey.currentState?.push(
                    CupertinoPageRoute(
                      builder: (_) => GroupInfoScreen(chatId: groupId),
                    ),
                  );
                }
              }
            });

            // Asosiy ekran (agar Deep Link bo'lsa, bu ekranning tepasidan GroupInfo ochiladi)
            return const HomeScreen();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  final String label;
  const _LoadingScreen({this.label = "Yuklanmoqda..."});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CupertinoActivityIndicator(
                radius: 15, color: Colors.blueAccent),
            const SizedBox(height: 25),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            CupertinoButton(
              child: const Text("Tizimdan chiqish",
                  style: TextStyle(fontSize: 12)),
              onPressed: () async {
                // Tizimdan chiqayotganda tokenni ham o'chirib ketish
                await NotificationService.deleteToken();
                if (context.mounted) {
                  Provider.of<custom.AuthProvider>(context, listen: false)
                      .signOut();
                }
              },
            )
          ],
        ),
      ),
    );
  }
}
