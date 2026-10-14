import 'package:flutter/material.dart';

class UserProfileAvatar extends StatelessWidget {
  const UserProfileAvatar({
    required this.name,
    this.photoUrl,
    this.radius = 24,
    this.backgroundColor = const Color(0xFFE8EEF8),
    this.foregroundColor = const Color(0xFF0B3A82),
    super.key,
  });

  final String name;
  final String? photoUrl;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return Semantics(
      label: '$name profile photo',
      image: true,
      child: ClipOval(
        child: SizedBox.square(
          dimension: radius * 2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: backgroundColor,
                child: Center(
                  child: Text(
                    initials.isEmpty ? '?' : initials,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (photoUrl != null && photoUrl!.isNotEmpty)
                Image.network(
                  photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
