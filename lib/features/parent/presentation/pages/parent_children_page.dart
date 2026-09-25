import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/presentation/school_brand.dart';
import '../../../auth/domain/auth_user.dart';
import '../../domain/parent_child.dart';
import '../controllers/parent_home_controller.dart';
import '../widgets/parent_child_card.dart';
import '../widgets/parent_design.dart';

class ParentChildrenPage extends StatelessWidget {
  const ParentChildrenPage({
    required this.user,
    required this.controller,
    required this.onChildSelected,
    required this.onAddChild,
    required this.onLogout,
    super.key,
  });

  final AuthUser user;
  final ParentHomeController controller;
  final ValueChanged<ParentChild> onChildSelected;
  final VoidCallback onAddChild;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParentDesign.background,
      appBar: AppBar(
        toolbarHeight: 82,
        titleSpacing: 20,
        title: const Row(
          children: [
            SchoolBrandLogo(size: 46, showShadow: false),
            SizedBox(width: 13),
            Text(
              'TWCES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_ParentAction>(
            tooltip: 'Account menu',
            onSelected: (action) {
              if (action == _ParentAction.logout) onLogout();
            },
            itemBuilder: (_) => [
              if (user.displayIdentifier.trim().isNotEmpty) ...[
                PopupMenuItem<_ParentAction>(
                  enabled: false,
                  child: _ParentIdentity(
                    name: user.name,
                    identifier: user.displayIdentifier,
                  ),
                ),
                const PopupMenuDivider(),
              ],
              const PopupMenuItem(
                value: _ParentAction.logout,
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
                radius: 20,
                backgroundColor: Colors.white24,
                child: Text(
                  initials(user.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.isLoading && controller.children.isEmpty) {
            return const ParentLoadingView();
          }
          if (controller.children.isEmpty) {
            return _EmptyChildren(
              message: controller.errorMessage,
              onRetry: () => controller.load(refresh: true),
              onAddChild: onAddChild,
            );
          }

          return RefreshIndicator(
            onRefresh: () => controller.load(refresh: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 30),
              children: [
                _Greeting(userName: user.name),
                const SizedBox(height: 30),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final heading = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your children',
                          style: TextStyle(
                            color: ParentDesign.deepInk,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          '${controller.children.length} linked',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                    final button = OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: onAddChild,
                      icon: const Icon(Icons.add_link_rounded, size: 20),
                      label: const Text('Add approved child'),
                    );
                    if (constraints.maxWidth >= 330) {
                      return Row(
                        children: [
                          Expanded(child: heading),
                          const SizedBox(width: 10),
                          button,
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [heading, const SizedBox(height: 12), button],
                    );
                  },
                ),
                const SizedBox(height: 16),
                for (final child in controller.children)
                  ParentChildCard(
                    child: child,
                    selected: controller.selectedChild?.id == child.id,
                    onTap: () => onChildSelected(child),
                  ),
                if (controller.dashboard case final dashboard?) ...[
                  const SizedBox(height: 12),
                  _MonthSnapshot(
                    present: dashboard.present,
                    late: dashboard.late,
                    absent: dashboard.absent,
                    excused: dashboard.excused,
                  ),
                ],
                if (controller.errorMessage case final message?) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $userName',
                style: const TextStyle(
                  color: ParentDesign.deepInk,
                  fontSize: 26,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Choose a child to view their school records.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 125,
          height: 125,
          child: Image.asset(
            'assets/images/Owl.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            semanticLabel: 'QRDify owl mascot',
          ),
        ),
      ],
    );
  }
}

class _MonthSnapshot extends StatelessWidget {
  const _MonthSnapshot({
    required this.present,
    required this.late,
    required this.absent,
    required this.excused,
  });

  final int present;
  final int late;
  final int absent;
  final int excused;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ParentDesign.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ParentSectionLabel('Current month'),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(
                label: 'Present',
                value: present,
                color: AppColors.success,
              ),
              _MiniStat(
                label: 'Late',
                value: late,
                color: const Color(0xFFF59E0B),
              ),
              _MiniStat(
                label: 'Absent',
                value: absent,
                color: AppColors.danger,
              ),
              _MiniStat(
                label: 'Excused',
                value: excused,
                color: AppColors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EmptyChildren extends StatelessWidget {
  const _EmptyChildren({
    required this.message,
    required this.onRetry,
    required this.onAddChild,
  });

  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onAddChild;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ParentEmptyState(
          icon: Icons.family_restroom_rounded,
          title: 'No linked children yet',
          message:
              message ??
              'Use an approved Parent invitation to connect a child.',
          action: Column(
            children: [
              OutlinedButton.icon(
                onPressed: onAddChild,
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('Use Parent invitation'),
              ),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ParentAction { logout }

class _ParentIdentity extends StatelessWidget {
  const _ParentIdentity({required this.name, required this.identifier});

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
            color: ParentDesign.deepInk,
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
