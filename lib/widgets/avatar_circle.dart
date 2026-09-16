import 'package:flutter/material.dart';

import '../theme/reconnect_theme.dart';

/// A circular avatar that renders [imageUrl] as a photo when present,
/// falling back to an initials badge on [background] otherwise (and if the
/// image fails to load). Shared by Profile, Contact Detail, and Edit
/// Profile so avatar treatment is consistent across the app.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.imageUrl,
    required this.initials,
    required this.size,
    this.background = ReconnectColors.accent,
    this.fontSize,
  });

  final String imageUrl;
  final String initials;
  final double size;
  final Color background;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return _initialsCircle();
    return ClipOval(
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _initialsCircle(),
      ),
    );
  }

  Widget _initialsCircle() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: fontSize ?? size * 0.36),
      ),
    );
  }
}
