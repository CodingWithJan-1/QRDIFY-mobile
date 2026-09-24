import 'package:flutter/material.dart';

import '../../domain/parent_child.dart';
import 'parent_design.dart';

class ParentChildCard extends StatelessWidget {
  const ParentChildCard({
    required this.child,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final ParentChild child;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ParentChildIdentity(
        child: child,
        selected: selected,
        onTap: onTap,
        card: true,
      ),
    );
  }
}
