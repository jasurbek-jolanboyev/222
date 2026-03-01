import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  File? _selectedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // Galereyadan rasm tanlash
  Future<void> _pickImage() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  // Ma'lumotlarni Firebase-ga yuklash
  Future<void> _uploadPost() async {
    if (_titleController.text.isEmpty || _descController.text.isEmpty) {
      _showError("Sarlavha va tavsifni to'ldiring");
      return;
    }

    setState(() => _isLoading = true);

    try {
      String imageUrl = "";

      // 1. Agar rasm tanlangan bo'lsa, Storage-ga yuklaymiz
      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('post_images')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      // 2. Firestore-ga post qo'shamiz
      await FirebaseFirestore.instance.collection('posts').add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'imageUrl': imageUrl,
        'webLink': _linkController.text.trim(),
        'category': "YANGILIK",
        'views': 0,
        'likes': [],
        'createdAt': FieldValue.serverTimestamp(),
        'authorId': FirebaseAuth.instance.currentUser?.uid,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Post muvaffaqiyatli qo'shildi!")),
        );
      }
    } catch (e) {
      _showError("Xatolik yuz berdi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Xato"),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Yangi post yaratish",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          if (_isLoading)
            const Padding(
                padding: EdgeInsets.all(12),
                child: CupertinoActivityIndicator())
          else
            TextButton(
              onPressed: _uploadPost,
              child: const Text("Ulashish",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Rasm tanlash bloki
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.camera_fill,
                              size: 40, color: Colors.blueAccent),
                          SizedBox(height: 10),
                          Text("Rasm biriktirish",
                              style: TextStyle(color: Colors.blueAccent)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Sarlavha
            TextField(
              controller: _titleController,
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "Sarlavha",
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 15),

            // Tavsif
            TextField(
              controller: _descController,
              maxLines: 5,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: "Batafsil ma'lumot...",
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 15),

            // Tashqi havola (Web Link)
            TextField(
              controller: _linkController,
              style: const TextStyle(color: Colors.blueAccent),
              decoration: InputDecoration(
                hintText: "Web link (ixtiyoriy)",
                prefixIcon: const Icon(CupertinoIcons.link, size: 18),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
