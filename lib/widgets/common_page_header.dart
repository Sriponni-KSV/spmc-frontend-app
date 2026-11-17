import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Reusable, standardized page header widget for all HMS screens.
/// Enforces consistent typography, hierarchy, padding, and responsive layout across the application.
class CommonPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final List<Widget>? actions;
  final Widget? bottom;
  final EdgeInsetsGeometry? padding;
  final bool? isMobile;

  const CommonPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.actions,
    this.bottom,
    this.padding,
    this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final bool mobile = isMobile ?? MediaQuery.of(context).size.width < 900;
    final effectivePadding = padding ??
        EdgeInsets.fromLTRB(
          mobile ? 16 : 24,
          mobile ? 16 : 24,
          mobile ? 16 : 24,
          0,
        );

    final titleWidget = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primaryColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor ?? AppTheme.primaryColor,
              size: mobile ? 20 : 22,
            ),
          ),
        ],
        Flexible(
          child: Text(
            title,
            style: AppTheme.pageTitleStyle(context, isMobile: mobile),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final subtitleWidget = (subtitle != null && subtitle!.trim().isNotEmpty)
        ? Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              subtitle!,
              style: AppTheme.pageSubtitleStyle(context, isMobile: mobile),
            ),
          )
        : null;

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleWidget,
        if (subtitleWidget != null) subtitleWidget,
      ],
    );

    return Container(
      padding: effectivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mobile) ...[
            titleColumn,
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions!,
              ),
            ],
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: titleColumn),
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!
                        .expand((w) => [w, const SizedBox(width: 8)])
                        .toList()
                      ..removeLast(),
                  ),
                ],
              ],
            ),
          ],
          if (bottom != null) ...[
            const SizedBox(height: 14),
            bottom!,
          ],
        ],
      ),
    );
  }
}

