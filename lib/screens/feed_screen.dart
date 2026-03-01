import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart'; // Qo'shildi

import '../providers/theme_provider.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  Widget build(BuildContext context) {
    final bool isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("YANGILIKLAR",
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CupertinoActivityIndicator());

          final posts = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index].data() as Map<String, dynamic>;
              final String postId = posts[index].id;
              bool isLiked =
                  (post['likes'] as List?)?.contains(_userId) ?? false;

              return _buildModernPostCard(
                  context, postId, post, isLiked, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildModernPostCard(BuildContext context, String id,
      Map<String, dynamic> post, bool isLiked, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(
              builder: (_) => UnifiedPostDetail(post: post, postId: id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post['imageUrl'] != null && post['imageUrl'] != "")
              Hero(
                tag: id,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(25)),
                  child: CachedNetworkImage(
                    imageUrl: post['imageUrl'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post['category']?.toString().toUpperCase() ?? "YANGILIK",
                      style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                  const SizedBox(height: 8),
                  Text(post['title'] ?? "",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _smallStat(CupertinoIcons.heart_fill,
                          "${(post['likes'] as List?)?.length ?? 0}"),
                      _smallStat(
                          CupertinoIcons.eye_fill, "${post['views'] ?? 0}"),
                      const Text("Batafsil →",
                          style: TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallStat(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      );
}

class UnifiedPostDetail extends StatefulWidget {
  final Map<String, dynamic> post;
  final String postId;
  const UnifiedPostDetail(
      {super.key, required this.post, required this.postId});

  @override
  State<UnifiedPostDetail> createState() => _UnifiedPostDetailState();
}

class _UnifiedPostDetailState extends State<UnifiedPostDetail> {
  VideoPlayerController? _vController;
  ChewieController? _cController;
  YoutubePlayerController? _ytController; // YouTube Controller
  bool _isBookmarked = false;
  bool _isYoutube = false;

  @override
  void initState() {
    super.initState();
    _incrementViews();
    _checkBookmark();
    _setupMedia();
  }

  void _setupMedia() {
    final String? videoUrl =
        widget.post['videoUrl']; // Admin paneldagi video havolasi

    if (videoUrl != null && videoUrl.isNotEmpty) {
      String? ytId = YoutubePlayer.convertUrlToId(videoUrl);
      if (ytId != null) {
        // Bu YouTube videosi
        _isYoutube = true;
        _ytController = YoutubePlayerController(
          initialVideoId: ytId,
          flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
        );
      } else if (videoUrl.toLowerCase().contains('.mp4')) {
        // Bu oddiy fayl videosi
        _initVideo(videoUrl);
      }
    }
  }

  void _incrementViews() => FirebaseFirestore.instance
      .collection('posts')
      .doc(widget.postId)
      .update({'views': FieldValue.increment(1)});

  void _checkBookmark() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookmarks')
        .doc(widget.postId)
        .get();
    if (mounted) setState(() => _isBookmarked = doc.exists);
  }

  void _initVideo(String url) {
    _vController = VideoPlayerController.networkUrl(Uri.parse(url));
    _vController!.initialize().then((_) {
      if (mounted) {
        setState(() {
          _cController = ChewieController(
            videoPlayerController: _vController!,
            autoPlay: true,
            aspectRatio: _vController!.value.aspectRatio,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _vController?.dispose();
    _cController?.dispose();
    _ytController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildMediaHeader(),
            ),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => Navigator.pop(context)),
            actions: [
              IconButton(
                icon: Icon(
                    _isBookmarked
                        ? CupertinoIcons.bookmark_fill
                        : CupertinoIcons.bookmark,
                    color: _isBookmarked ? Colors.amber : null),
                onPressed: _toggleBookmark,
              ),
              IconButton(
                  icon: const Icon(CupertinoIcons.share),
                  onPressed: () => Share.share(
                      "${widget.post['title']}\n\nCyberCommunity ilovasida o'qing!")),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.post['title'] ?? "",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  const SizedBox(height: 15),
                  Text(widget.post['description'] ?? "",
                      style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: textColor.withOpacity(0.8))),

                  const SizedBox(height: 30),

                  // --- ADMIN PANELDAN KELADIGAN ASOSIY TUGMA (WEB LINK) ---
                  if (widget.post['webLink'] != null &&
                      widget.post['webLink'] != "")
                    _buildMainActionButton(),

                  const SizedBox(height: 25),

                  // MANBALAR (Agar links listi bo'lsa)
                  if (widget.post['links'] != null &&
                      (widget.post['links'] as List).isNotEmpty) ...[
                    const Text("QO'SHIMCHA MANBALAR",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                            fontSize: 12)),
                    const SizedBox(height: 10),
                    ...(widget.post['links'] as List).map((l) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(CupertinoIcons.link, size: 18),
                          title: Text(l is Map ? l['name'] : "Havola",
                              style: const TextStyle(fontSize: 14)),
                          onTap: () =>
                              _launchURL(l is Map ? l['url'] : l.toString()),
                        )),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // Media Headerni chiqarish (YouTube, MP4 yoki Rasm)
  Widget _buildMediaHeader() {
    if (_isYoutube && _ytController != null) {
      return YoutubePlayer(
        controller: _ytController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.blueAccent,
      );
    } else if (_cController != null) {
      return Chewie(controller: _cController!);
    } else {
      return Hero(
        tag: widget.postId,
        child: CachedNetworkImage(
          imageUrl: widget.post['imageUrl'] ?? "",
          fit: BoxFit.cover,
          errorWidget: (context, url, error) =>
              const Icon(Icons.image_not_supported),
        ),
      );
    }
  }

  // Admin paneldagi asosiy Web Link tugmasi
  Widget _buildMainActionButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        color: Colors.blueAccent,
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(15),
        onPressed: () => _launchURL(widget.post['webLink']),
        child: Text(widget.post['buttonName'] ?? "Batafsil ma'lumot",
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Havolani ochib bo'lmadi: $url");
    }
  }

  void _toggleBookmark() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookmarks')
        .doc(widget.postId);
    if (_isBookmarked) {
      await ref.delete();
    } else {
      await ref.set({...widget.post, 'savedAt': FieldValue.serverTimestamp()});
    }
    setState(() => _isBookmarked = !_isBookmarked);
  }
}
