import 'package:flutter/material.dart';

/// Initials remain visible if the photo is missing or cannot be downloaded.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.fallback,
    this.photoUrl,
    this.radius = 20,
    this.backgroundColor,
  });
  final Widget fallback;
  final String? photoUrl;
  final double radius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    final hasPhoto = url != null && url.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      foregroundImage: hasPhoto ? NetworkImage(url) : null,
      onForegroundImageError: hasPhoto ? (_, __) {} : null,
      child: fallback,
    );
  }
}
