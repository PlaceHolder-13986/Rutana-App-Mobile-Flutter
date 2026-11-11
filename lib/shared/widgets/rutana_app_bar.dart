import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class RutanaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onProfileTap;

  const RutanaAppBar({super.key, required this.title, this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline),
          tooltip: 'Profile',
          onPressed: onProfileTap,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}