import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../feed_screen.dart'; // UnifiedPostDetail uchun

class FeedTab extends StatelessWidget {
  final bool isDark;

  const FeedTab({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }
        final posts = snapshot.data!.docs;
        if (posts.isEmpty) {
          return const Center(
            child:
                Text("Yangiliklar yo'q", style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final data = posts[index].data() as Map<String, dynamic>;
            final String docId = posts[index].id;

            return _EnhancedPostCard(
              post: data,
              postId: docId,
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) =>
                        UnifiedPostDetail(post: data, postId: docId),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// --- SUB-WIDGET: POST KARTASI ---
class _EnhancedPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final String postId;
  final bool isDark;
  final VoidCallback onTap;

  const _EnhancedPostCard({
    required this.post,
    required this.postId,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rasm qismi + Hero Animation
            if (post['imageUrl'] != null && post['imageUrl'] != "")
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Hero(
                  tag: postId,
                  child: CachedNetworkImage(
                    imageUrl: post['imageUrl'],
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: isDark ? Colors.white10 : Colors.grey[200],
                      child: const Center(child: CupertinoActivityIndicator()),
                    ),
                  ),
                ),
              ),

            // Ma'lumot qismi
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kategoriya
                  Text(
                    (post['category'] ?? "Yangilik").toString().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Sarlavha
                  Text(
                    post['title'] ?? "Mavzu yo'q",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Qisqa tavsif
                  Text(
                    post['description'] ?? "",
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
