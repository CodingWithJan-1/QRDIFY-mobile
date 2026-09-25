import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'school_brand.dart';

class ModuleHomeScaffold extends StatelessWidget {
  const ModuleHomeScaffold({
    required this.title,
    required this.userName,
    this.userIdentifier,
    required this.description,
    required this.onLogout,
    this.features = const [],
    this.onLocationPrivacy,
    this.overview,
    super.key,
  });

  final String title;
  final String userName;
  final String? userIdentifier;
  final String description;
  final List<ModuleFeature> features;
  final Future<void> Function() onLogout;
  final VoidCallback? onLocationPrivacy;
  final Widget? overview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 20,
        title: const Row(
          children: [
            SchoolBrandLogo(size: 42, showShadow: false),
            SizedBox(width: 12),
            Text(
              'TWCES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_HomeAction>(
            tooltip: 'Account menu',
            onSelected: (action) {
              switch (action) {
                case _HomeAction.locationPrivacy:
                  onLocationPrivacy?.call();
                case _HomeAction.logout:
                  onLogout();
              }
            },
            itemBuilder: (_) => [
              if (userIdentifier case final identifier?
                  when identifier.trim().isNotEmpty) ...[
                PopupMenuItem<_HomeAction>(
                  enabled: false,
                  child: _AccountIdentity(
                    name: userName,
                    identifier: identifier,
                  ),
                ),
                const PopupMenuDivider(),
              ],
              if (onLocationPrivacy != null)
                const PopupMenuItem(
                  value: _HomeAction.locationPrivacy,
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: AppColors.ink),
                      SizedBox(width: 10),
                      Flexible(child: Text('Location & privacy')),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: _HomeAction.logout,
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: AppColors.ink),
                    SizedBox(width: 10),
                    Text('Sign out'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                child: Text(
                  _initials(userName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text(
            '$title Dashboard',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Welcome, $userName. $description',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          if (overview != null) ...[overview!, const SizedBox(height: 28)],
          if (features.isNotEmpty) ...[
            const Text(
              'QUICK ACCESS',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            ...features.map((feature) => _FeatureCard(feature: feature)),
          ],
        ],
      ),
    );
  }
}

class _AccountIdentity extends StatelessWidget {
  const _AccountIdentity({required this.name, required this.identifier});

  final String name;
  final String identifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          identifier,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final ModuleFeature feature;

  @override
  Widget build(BuildContext context) {
    final enabled = feature.onTap != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: feature.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: enabled
                      ? const Color(0xFFEAF1FB)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  feature.icon,
                  color: enabled ? AppColors.navy : const Color(0xFF94A3B8),
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.title,
                      style: TextStyle(
                        color: enabled
                            ? AppColors.ink
                            : const Color(0xFF64748B),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feature.description,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                enabled
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModuleFeature {
  const ModuleFeature({
    required this.title,
    required this.description,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;
}

enum _HomeAction { locationPrivacy, logout }

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
