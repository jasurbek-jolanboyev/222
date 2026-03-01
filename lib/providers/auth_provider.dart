import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  bool _disposed = false;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _userDocSubscription;

  // Getterlar
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get userData => _userData;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authSubscription = _auth.authStateChanges().listen((User? user) {
      _currentUser = user;
      if (user != null) {
        _startUserDataListener(user.uid);
      } else {
        _stopUserDataListener();
        _userData = null;
        _notify();
      }
    });
  }

  /// Foydalanuvchi ma'lumotlarini markaziy eshitish
  void _startUserDataListener(String uid) {
    _userDocSubscription?.cancel();

    // snapshots() dan keyin <Map<String, dynamic>> turini berish sariq chiziqni yo'qotadi
    _userDocSubscription =
        _firestore.collection('users').doc(uid).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        // snapshot.data() allaqachon Map qaytaradi, 'as' kerak emas
        final Map<String, dynamic>? freshData = snapshot.data();

        // Bloklanganligini tekshirish
        if (freshData?['isBlocked'] == true) {
          signOut();
          return;
        }

        // Faqat muhim ma'lumotlar o'zgarganda UI yangilanadi
        if (_shouldUpdateUI(freshData)) {
          _userData = freshData;
          _notify();
        }
      }
    }, onError: (e) => debugPrint("Firestore Listener Error: $e"));
  }

  /// UI ni keraksiz rebuildlardan himoya qilish (lastSeen ni hisobga olmaydi)
  bool _shouldUpdateUI(Map<String, dynamic>? newData) {
    if (_userData == null) return true;
    if (newData == null) return false;

    return _userData!['username'] != newData['username'] ||
        _userData!['avatar'] != newData['avatar'] ||
        _userData!['role'] != newData['role'] ||
        _userData!['clubStatus'] != newData['clubStatus'] ||
        _userData!['bio'] != newData['bio'];
  }

  void _stopUserDataListener() {
    _userDocSubscription?.cancel();
    _userDocSubscription = null;
  }

  // --- ONLINE STATUS BOSHQARUVI ---

  Future<void> setOnlineStatus(bool status) async {
    if (_currentUser == null) return;
    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'online': status,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Update Status Error: $e");
    }
  }

  // --- AUTH AMALLARI ---

  Future<void> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      await setOnlineStatus(true);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e.code);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signUpWithEmail(
      String email, String password, String username) async {
    try {
      _setLoading(true);

      // DIQQAT: Agar qoidalarni 'allow read: if true' qilmasangiz,
      // bu qator har doim 'Denied' xatosini beradi.
      final taken = await isUsernameTaken(username);
      if (taken) throw "Bu username band!";

      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Auth muvaffaqiyatli bo'ldi, endi Firestore yozishga ruxsat beradi
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'username': username.trim().toLowerCase(),
        'email': email.trim(),
        'avatar': "",
        'bio': "Cyber Community a'zosi",
        'isBlocked': false,
        'isVerified': false,
        'role': 'user', // Default rol
        'online': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e.code);
    } catch (e) {
      throw e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      _setLoading(true);
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'username': "",
            'email': user.email,
            'avatar': user.photoURL ?? "",
            'isBlocked': false,
            'isVerified': false,
            'role': 'user',
            'online': true,
            'createdAt': FieldValue.serverTimestamp(),
            'lastSeen': FieldValue.serverTimestamp(),
          });
        } else {
          await setOnlineStatus(true);
        }
      }
    } catch (e) {
      debugPrint("Google Login Error: $e");
      throw "Google orqali kirish amalga oshmadi.";
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    try {
      await setOnlineStatus(false);
      _stopUserDataListener();
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint("Logout Error: $e");
    }
  }

  // --- YORDAMCHI FUNKSIYALAR ---

  Future<bool> isUsernameTaken(String username) async {
    final result = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase().trim())
        .get();
    return result.docs.isNotEmpty;
  }

  Future<void> updateUsername(String newName) async {
    if (_currentUser == null) return;
    try {
      _setLoading(true);
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'username': newName.trim().toLowerCase(),
      });
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    super.dispose();
  }

  String _handleAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return "Foydalanuvchi topilmadi.";
      case 'wrong-password':
        return "Parol noto'g'ri.";
      case 'email-already-in-use':
        return "Bu email band.";
      case 'invalid-email':
        return "Email formati noto'g'ri.";
      case 'user-disabled':
        return "Hisobingiz bloklangan.";
      default:
        return "Xatolik yuz berdi ($code)";
    }
  }
}
