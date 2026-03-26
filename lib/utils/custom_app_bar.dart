import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showShadow;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.showShadow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      elevation: showShadow ? 1.0 : 0.0,
      // Colors, icons, and text styles stream directly from AppTheme (scaffold's current theme)
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
