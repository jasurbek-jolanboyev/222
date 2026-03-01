import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

// Barcha so'ralgan mavzular uchun enum kengaytirildi
enum ChatThemeType {
  classic,
  love,
  friends,
  hackers,
  pentesters,
  blackHat,
  developer,
  students,
  cyber,
  matrix
}

class ChatProvider with ChangeNotifier {
  IO.Socket? socket;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _messages = [];
  String? _currentChatRoom;
  bool _isConnected = false;
  bool _isLoadingHistory = false;
  final Map<String, bool> _typingUsers = {};

  // Fon mavzusi uchun boshlang'ich qiymat
  ChatThemeType _currentTheme = ChatThemeType.classic;

  // Getterlar
  List<Map<String, dynamic>> get messages => _messages;
  String? get currentChatRoom => _currentChatRoom;
  bool get isConnected => _isConnected;
  bool get isLoadingHistory => _isLoadingHistory;
  Map<String, bool> get typingUsers => _typingUsers;
  ChatThemeType get currentTheme => _currentTheme;

  // --- MAVZUNI BOSHQARISH (Dinamik tanlov) ---

  void updateChatTheme(ChatThemeType theme) {
    _currentTheme = theme;
    notifyListeners();

    // Agar xonaga biriktirilgan bo'lsa, mavzuni bazaga ham yozib qo'yish mumkin
    if (_currentChatRoom != null) {
      _saveThemeToFirebase(theme);
    }
  }

  // Firebase'dan kelgan stringni Enumga aylantirish
  void loadThemeFromFirebase(String? themeName) {
    _currentTheme = ChatThemeType.values.firstWhere(
      (e) => e.toString().split('.').last == themeName,
      orElse: () => ChatThemeType.classic,
    );
    notifyListeners();
  }

  // Mavzuni bazada saqlash (ixtiyoriy, xona sozlamasi sifatida)
  Future<void> _saveThemeToFirebase(ChatThemeType theme) async {
    try {
      await _firestore.collection('chats').doc(_currentChatRoom).set({
        'theme': theme.toString().split('.').last,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Mavzuni saqlashda xato: $e");
    }
  }

  // --- XAVFSIZLIK ---
  String _sanitizeText(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), "").trim();
  }

  // --- SOKETNI SOZLASH ---
  void initSocket(String username) {
    socket?.dispose();

    socket =
        IO.io('https://safechat-backend-api.onrender.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 2000,
    });

    socket!.connect();

    socket!.onConnect((_) {
      _isConnected = true;
      socket!.emit('join', {'username': username});
      if (_currentChatRoom != null) {
        socket!.emit('join_room', {'room': _currentChatRoom});
      }
      notifyListeners();
    });

    socket!.onConnectError((err) {
      _isConnected = false;
      debugPrint("Socket ulanish xatosi: $err");
      notifyListeners();
    });

    socket!.onDisconnect((_) {
      _isConnected = false;
      notifyListeners();
    });

    socket!.on('receive_message', (data) {
      if (data is Map<String, dynamic> && data['room'] == _currentChatRoom) {
        _handleIncomingMessage(data);
      }
    });

    socket!.on('display_typing', (data) {
      if (data is Map<String, dynamic> && data['room'] == _currentChatRoom) {
        final String typingUser = data['username'].toString();
        if (typingUser != username) {
          _typingUsers[typingUser] = data['isTyping'] == true;
          notifyListeners();
        }
      }
    });
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final sanitizedMessage = {
      'msgId': data['msgId']?.toString() ?? "",
      'sender': data['sender']?.toString() ?? "System",
      'text': _sanitizeText(data['text']?.toString() ?? ""),
      'room': data['room'],
      'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
      'replyTo': data['replyTo'],
      'status': 'received',
    };

    bool exists = _messages.any((m) => m['msgId'] == sanitizedMessage['msgId']);
    if (!exists && sanitizedMessage['msgId'] != "") {
      _messages.insert(0, sanitizedMessage);
      notifyListeners();
    }
  }

  // --- CHAT TARIXI VA SOZLAMALARI ---
  void setCurrentChat(String user1, String user2) async {
    List<String> ids = [user1, user2];
    ids.sort();
    _currentChatRoom = ids.join('_');

    _messages = [];
    _typingUsers.clear();
    _isLoadingHistory = true;
    notifyListeners();

    socket?.emit('join_room', {'room': _currentChatRoom});

    try {
      // 1. Tarixni yuklash
      final snapshot = await _firestore
          .collection('chats')
          .doc(_currentChatRoom)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _messages = snapshot.docs.map((doc) {
        final data = doc.data();
        if (data['createdAt'] is Timestamp) {
          data['timestamp'] =
              (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        data['text'] = _sanitizeText(data['text'] ?? "");
        data['status'] = 'delivered';
        return data;
      }).toList();

      // 2. Xonaga oid mavzuni yuklash
      final chatDoc =
          await _firestore.collection('chats').doc(_currentChatRoom).get();
      if (chatDoc.exists) {
        loadThemeFromFirebase(chatDoc.data()?['theme']);
      }
    } catch (e) {
      debugPrint("Ma'lumotlarni yuklashda xato: $e");
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

// --- XABAR YUBORISH (Media va Bildirishnoma bilan) ---
  Future<void> sendMessage({
    required String sender,
    required String receiver,
    required String text,
    Map<String, dynamic>? replyTo,
    String? senderName,
    String type = 'text',
    String? mediaUrl,
    String? fileName,
  }) async {
    // Matnni tozalash (agar media bo'lsa matn bo'sh bo'lishi mumkin)
    final cleanText = _sanitizeText(text);
    if (cleanText.isEmpty && replyTo == null && mediaUrl == null) return;

    final String msgId = "${DateTime.now().millisecondsSinceEpoch}_$sender";
    final String timeIso = DateTime.now().toIso8601String();

    // 1. UI uchun ma'lumot (Optimistic UI)
    final msgData = {
      'msgId': msgId,
      'sender': sender,
      'receiver': receiver,
      'text': cleanText,
      'type': type, // <--- Turi (image, video, etc)
      'mediaUrl': mediaUrl, // <--- Media manzili
      'fileName': fileName, // <--- Fayl nomi
      'room': _currentChatRoom,
      'timestamp': timeIso,
      'replyTo': replyTo,
      'status': 'sending',
    };

    _messages.insert(0, msgData);
    notifyListeners();

    // 2. Soket orqali yuborish (Real-time)
    if (_isConnected) {
      socket?.emit('send_message', msgData);
    }

    try {
      final WriteBatch batch = _firestore.batch();

      // a) Xabarni xonaga yozish
      final msgDocRef = _firestore
          .collection('chats')
          .doc(_currentChatRoom)
          .collection('messages')
          .doc(msgId);

      final firestoreData = Map<String, dynamic>.from(msgData);
      firestoreData['createdAt'] = FieldValue.serverTimestamp();
      firestoreData.remove('status'); // Bazada status 'sent' bo'ladi
      firestoreData['isRead'] = false;

      batch.set(msgDocRef, firestoreData);

      // b) Chat ro'yxatini yangilash (Last Message)
      final chatRoomRef = _firestore.collection('chats').doc(_currentChatRoom);

      // So'nggi xabar ko'rinishi: agar rasm bo'lsa "🖼 Rasm" deb chiqadi
      String lastDisplay =
          type == 'text' ? cleanText : "[${type.toUpperCase()}]";

      batch.set(
          chatRoomRef,
          {
            'lastMessage': lastDisplay,
            'lastTime': FieldValue.serverTimestamp(),
            'users': [sender, receiver],
            'lastSenderId': sender,
          },
          SetOptions(merge: true));

      // c) Bildirishnoma yuborish
      final notifyRef = _firestore
          .collection('users')
          .doc(receiver)
          .collection('notifications')
          .doc();

      batch.set(notifyRef, {
        'title': senderName ?? 'Yangi xabar',
        'body': lastDisplay,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': sender,
        'roomId': _currentChatRoom,
        'type': type, // chat, image, video...
      });

      await batch.commit();

      // UI holatini yangilash
      int index = _messages.indexWhere((m) => m['msgId'] == msgId);
      if (index != -1) {
        _messages[index]['status'] = 'sent';
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Yuborishda xatolik: $e");
      int index = _messages.indexWhere((m) => m['msgId'] == msgId);
      if (index != -1) {
        _messages[index]['status'] = 'error';
        notifyListeners();
      }
    }
  }

  // --- XABARNI O'CHIRISH ---
  Future<void> deleteMessage(String msgId) async {
    if (_currentChatRoom == null) return;
    try {
      await _firestore
          .collection('chats')
          .doc(_currentChatRoom)
          .collection('messages')
          .doc(msgId)
          .delete();

      _messages.removeWhere((m) => m['msgId'] == msgId);
      notifyListeners();
    } catch (e) {
      debugPrint("O'chirishda xatolik: $e");
    }
  }

  // --- YOZMOQDA... HOLATI ---
  void sendTypingStatus(String username, bool isTyping) {
    if (_currentChatRoom == null) return;
    socket?.emit('typing', {
      'room': _currentChatRoom,
      'username': username,
      'isTyping': isTyping,
    });
  }

  @override
  void dispose() {
    socket?.disconnect();
    socket?.dispose();
    super.dispose();
  }
}
