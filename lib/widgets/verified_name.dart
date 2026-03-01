// lib/widgets/verified_name.dart
import 'package:flutter/material.dart';

class VerifiedName extends StatelessWidget {
  final String username;
  final bool isVerified;
  final TextStyle? style;
  final double iconSize;

  const VerifiedName({
    required this.username,
    required this.isVerified,
    this.style,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
            child:
                Text(username, style: style, overflow: TextOverflow.ellipsis)),
        if (isVerified)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.verified, color: Colors.blue, size: iconSize),
          ),
      ],
    );
  }
}
