import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/parent_child.dart';

abstract final class ParentDesign {
  static const background = Color(0xFFF6FAFE);
  static const softBlue = Color(0xFFEAF3FF);
  static const paleBlue = Color(0xFFF0F6FD);
  static const line = Color(0xFFD8E2EE);
  static const deepInk = Color(0xFF08142B);
}

class ParentPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const ParentPageHeader({
    required this.title,
    this.actions = const [],
    super.key,
  });

  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(82);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: preferredSize.height,
      titleSpacing: 20,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      actions: actions,
    );
  }
}

class ParentChildIdentity extends StatelessWidget {
  const ParentChildIdentity({
    required this.child,
    this.selected = false,
    this.onTap,
    this.card = false,
    super.key,
  });

  final ParentChild child;
  final bool selected;
  final VoidCallback? onTap;
  final bool card;

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: card ? 16 : 8,
            vertical: card ? 16 : 14,
          ),
          child: Row(
            children: [
              _InitialsAvatar(name: child.name),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parentDisplayName(child.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ParentDesign.deepInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.25,
                      ),
                    ),
                    if (child.classLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        child.classLabel,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      parentSentenceCase(child.relationship),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: selected ? AppColors.blue : AppColors.muted,
                  size: selected ? 30 : 28,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!card) return content;
    return Container(
      decoration: BoxDecoration(
        color: selected ? ParentDesign.softBlue : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParentDesign.line),
      ),
      child: content,
    );
  }
}

class ParentSectionLabel extends StatelessWidget {
  const ParentSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF52617A),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

class ParentEmptyState extends StatelessWidget {
  const ParentEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 46),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 94,
                height: 94,
                decoration: const BoxDecoration(
                  color: ParentDesign.paleBlue,
                  shape: BoxShape.circle,
                ),
              ),
              Icon(icon, size: 54, color: ParentDesign.deepInk),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ParentDesign.deepInk,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

class ParentLoadingView extends StatelessWidget {
  const ParentLoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.blue));
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFDDEBFF),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials(name),
        style: const TextStyle(
          color: AppColors.blue,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String initials(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  return words
      .take(2)
      .where((word) => word.isNotEmpty)
      .map((word) => word[0])
      .join()
      .toUpperCase();
}

String parentDisplayName(String value) {
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map(
        (word) => word[0] == word[0].toLowerCase()
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : word,
      )
      .join(' ');
}

String parentSentenceCase(String value) => value.isEmpty
    ? 'Guardian'
    : '${value[0].toUpperCase()}${value.substring(1).replaceAll('_', ' ')}';
