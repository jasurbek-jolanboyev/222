import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final String? mediaUrl;
  final String? fileName;
  final bool isMe;
  final DateTime timestamp;
  final String senderName;
  final bool isRead;
  final bool isEdited;
  final Map<String, dynamic>? replyTo;
  final String type;

  const MessageBubble({
    super.key,
    required this.text,
    this.mediaUrl,
    this.fileName,
    required this.isMe,
    required this.timestamp,
    required this.senderName,
    required this.isRead,
    this.isEdited = false,
    this.replyTo,
    required this.type,
  });

  // Joylashuvni xaritada ochish funksiyasi
  Future<void> _openMap() async {
    if (mediaUrl != null) {
      final Uri url = Uri.parse(mediaUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String time = DateFormat('HH:mm').format(timestamp);
    final size = MediaQuery.of(context).size;

    final Color myBubbleColor =
        isDark ? const Color(0xFF2563EB) : const Color(0xFF007AFF);
    final Color otherBubbleColor =
        isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor =
        isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) _buildAvatar(isDark),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: size.width * 0.75),
                  decoration: BoxDecoration(
                    color: isMe ? myBubbleColor : otherBubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (replyTo != null) _buildReplyBlock(isDark, isMe),

                        // --- MULTIMEDIA TARKIBI ---
                        if (type == 'image' && mediaUrl != null)
                          _buildImage(context),
                        if (type == 'video' && mediaUrl != null)
                          _buildVideoPlaceholder(isMe),
                        if (type == 'location') _buildLocationBlock(isMe),
                        if (type == 'file') _buildFileBlock(isDark, isMe),
                        if (type == 'audio') _buildAudioBlock(isDark, isMe),

                        // --- MATN VA VAQT ---
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (text.isNotEmpty && type != 'location')
                                Text(
                                  text,
                                  style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                      height: 1.2),
                                ),
                              const SizedBox(height: 4),
                              _buildMetaRow(isDark, isMe, time),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- QOSHIMCHA VIDJETLAR ---

  Widget _buildImage(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Rasm ustiga bosganda kattalashtirib ko'rsatish mantiqi
      },
      child: CachedNetworkImage(
        imageUrl: mediaUrl!,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => const SizedBox(
            height: 200, child: Center(child: CupertinoActivityIndicator())),
        errorWidget: (context, url, error) =>
            const Icon(Icons.broken_image, size: 50),
      ),
    );
  }

  Widget _buildLocationBlock(bool isMe) {
    return InkWell(
      onTap: _openMap,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.blueGrey[100],
          image: const DecorationImage(
            image: NetworkImage(
                "https://www.mapquestapi.com/staticmap/v5/map?key=YOUR_KEY&center=41.311,69.240&zoom=13&size=400,200"), // Namuna uchun statik xarita
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black26,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.location_solid,
                  color: isMe ? Colors.white : Colors.red, size: 40),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10)),
                child: const Text("Joylashuvni ochish",
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder(bool isMe) {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.black87,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(CupertinoIcons.play_circle_fill,
              color: Colors.white, size: 60),
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4)),
              child: const Text("VIDEO",
                  style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFileBlock(bool isDark, bool isMe) {
    return Container(
      padding: const EdgeInsets.all(12),
      color:
          isMe ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.05),
      child: Row(
        children: [
          const Icon(CupertinoIcons.doc_fill,
              color: Colors.blueAccent, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fileName ?? "Fayl yuborildi",
              style: TextStyle(
                  color: isMe ? Colors.white : null,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioBlock(bool isDark, bool isMe) {
    return Container(
      padding: const EdgeInsets.all(10),
      width: 200,
      child: Row(
        children: [
          Icon(CupertinoIcons.play_arrow_solid,
              color: isMe ? Colors.white : Colors.blueAccent),
          const SizedBox(width: 8),
          const Expanded(
              child: LinearProgressIndicator(value: 0, minHeight: 2)),
          const SizedBox(width: 8),
          Text("0:00",
              style: TextStyle(
                  fontSize: 11, color: isMe ? Colors.white70 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildReplyBlock(bool isDark, bool isMe) {
    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? Colors.black12 : Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border(
            left: BorderSide(
                color: isMe ? Colors.white70 : Colors.blueAccent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(replyTo?['senderName'] ?? "Xabar",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.blueAccent)),
          Text(replyTo?['text'] ?? "",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMetaRow(bool isDark, bool isMe, String time) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isEdited)
          const Text("tahrirlandi ",
              style: TextStyle(
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey)),
        Text(time,
            style: TextStyle(
                fontSize: 10, color: isMe ? Colors.white70 : Colors.grey)),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            isRead
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.check_mark_circled,
            size: 12,
            color: isRead
                ? (isDark ? Colors.greenAccent : Colors.white)
                : Colors.white70,
          ),
        ],
      ],
    );
  }

  Widget _buildAvatar(bool isDark) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.blueAccent.withOpacity(0.2),
      child: Text(senderName.isNotEmpty ? senderName[0].toUpperCase() : "?",
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
