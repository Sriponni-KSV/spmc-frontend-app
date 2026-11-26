import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/notification_controller.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';

/// Shared notification bell icon button with a red unread count badge.
class NotificationBellButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onPressed;
  final double iconSize;
  final double badgeSize;
  final double badgeFontSize;
  final double badgeRight;
  final double badgeTop;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final Color? inactiveColor;
  final Color activeColor;

  const NotificationBellButton({
    super.key,
    required this.unreadCount,
    required this.onPressed,
    this.iconSize = 22,
    this.badgeSize = 16,
    this.badgeFontSize = 9,
    this.badgeRight = 5,
    this.badgeTop = 5,
    this.padding,
    this.constraints,
    this.inactiveColor,
    this.activeColor = AppTheme.dangerColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasUnread = unreadCount > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            hasUnread
                ? Icons.notifications_active_outlined
                : Icons.notifications_none_outlined,
            color: hasUnread
                ? activeColor
                : (inactiveColor ?? AppTheme.getTextPrimaryColor(context)),
            size: iconSize,
          ),
          padding: padding,
          constraints: constraints,
          tooltip: context.tr('notifications', fallback: 'Notifications'),
          onPressed: onPressed,
        ),
        if (hasUnread)
          Positioned(
            right: badgeRight,
            top: badgeTop,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: BoxConstraints(
                  minWidth: badgeSize,
                  minHeight: badgeSize,
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: badgeFontSize,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shared notifications modal dialog used across role dashboards.
class NotificationsDialog {
  static int countUnread(List<Map<String, dynamic>> notifications) {
    return notifications.where((n) => n['is_read'] != true).length;
  }

  static int? _parseId(dynamic raw) {
    if (raw is int) return raw;
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  /// Parses notification `metadata` whether it arrives as a Map or JSON string.
  static Map<String, dynamic> parseMetadata(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  /// Opens the notifications dialog and refreshes data in the background.
  static Future<void> show({
    required BuildContext context,
    required List<Map<String, dynamic>> initialNotifications,
    required Future<List<Map<String, dynamic>>> Function() onRefresh,
    required Future<void> Function(Map<String, dynamic> notification)
    onNotificationTap,
    String subtitle = 'Updates, alerts & system notices',
    String emptySubtitle =
        'You\'re all caught up! New alerts and system notices will appear here.',
  }) async {
    final controller = NotificationController();
    List<Map<String, dynamic>> notifications = List<Map<String, dynamic>>.from(
      initialNotifications,
    );
    bool isLoading = notifications.isEmpty;
    bool isDialogOpen = true;
    bool hasTriggeredInitialRefresh = false;
    StateSetter? dialogSetState;

    Future<void> refreshList() async {
      if (isDialogOpen) {
        dialogSetState?.call(() => isLoading = true);
      }
      try {
        final fresh = await onRefresh();
        if (isDialogOpen) {
          dialogSetState?.call(() {
            notifications = List<Map<String, dynamic>>.from(fresh);
            isLoading = false;
          });
        }
      } catch (_) {
        if (isDialogOpen) {
          dialogSetState?.call(() => isLoading = false);
        }
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setDialogState) {
            dialogSetState = setDialogState;
            if (!hasTriggeredInitialRefresh) {
              hasTriggeredInitialRefresh = true;
              Future.microtask(refreshList);
            }

            final isDark = AppTheme.isDark(modalCtx);
            final unread = notifications
                .where((n) => n['is_read'] != true)
                .toList();
            final read = notifications
                .where((n) => n['is_read'] == true)
                .toList();

            return Dialog(
              backgroundColor: AppTheme.getCardColor(modalCtx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  maxHeight: 540,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.notifications_active_outlined,
                              color: AppTheme.primaryColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  modalCtx.tr(
                                    'notifications',
                                    fallback: 'Notifications',
                                  ),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.getTextPrimaryColor(
                                      modalCtx,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.getTextSecondaryColor(
                                      modalCtx,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (unread.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                final ids = unread
                                    .map((n) {
                                      n['is_read'] = true;
                                      return _parseId(n['id']);
                                    })
                                    .whereType<int>()
                                    .toList();
                                await Future.wait(
                                  ids.map((id) async {
                                    try {
                                      await controller.markAsRead(id);
                                    } catch (e) {
                                      debugPrint(
                                        'Error marking notification $id read: $e',
                                      );
                                    }
                                  }),
                                );
                                await refreshList();
                              },
                              child: const Text(
                                'Mark all as read',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 20,
                              color: AppTheme.getTextSecondaryColor(modalCtx),
                            ),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(
                        height: 1,
                        color: AppTheme.getBorderColor(modalCtx),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: isLoading && notifications.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : notifications.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.notifications_off_outlined,
                                      size: 54,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'No Notifications Right Now',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppTheme.getTextPrimaryColor(
                                          modalCtx,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      emptySubtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.getTextSecondaryColor(
                                          modalCtx,
                                        ),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView(
                                children: [
                                  if (unread.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6.0,
                                      ),
                                      child: Row(
                                        children: [
                                          const Text(
                                            'NEW ALERTS',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: AppTheme.dangerColor,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? AppTheme.dangerColor
                                                        .withValues(alpha: 0.2)
                                                  : AppTheme.dangerBg,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${unread.length}',
                                              style: const TextStyle(
                                                color: AppTheme.dangerColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...unread.map(
                                      (n) => _buildTile(
                                        modalCtx: modalCtx,
                                        dialogCtx: dialogCtx,
                                        notification: n,
                                        controller: controller,
                                        onRefresh: refreshList,
                                        onNotificationTap: onNotificationTap,
                                      ),
                                    ),
                                  ],
                                  if (read.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6.0,
                                      ),
                                      child: Text(
                                        'EARLIER',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: AppTheme.getTextSecondaryColor(
                                            modalCtx,
                                          ),
                                        ),
                                      ),
                                    ),
                                    ...read.map(
                                      (n) => _buildTile(
                                        modalCtx: modalCtx,
                                        dialogCtx: dialogCtx,
                                        notification: n,
                                        controller: controller,
                                        onRefresh: refreshList,
                                        onNotificationTap: onNotificationTap,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                      Divider(
                        height: 1,
                        color: AppTheme.getBorderColor(modalCtx),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: isLoading ? null : refreshList,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: Text(
                              modalCtx.tr('refresh', fallback: 'Refresh'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            style: AppTheme.getCancelButton(modalCtx),
                            child: Text(
                              modalCtx.tr('close', fallback: 'Close'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      isDialogOpen = false;
      dialogSetState = null;
    });
  }

  static Widget _buildTile({
    required BuildContext modalCtx,
    required BuildContext dialogCtx,
    required Map<String, dynamic> notification,
    required NotificationController controller,
    required Future<void> Function() onRefresh,
    required Future<void> Function(Map<String, dynamic> notification)
    onNotificationTap,
  }) {
    final isDark = AppTheme.isDark(modalCtx);
    final bool isUnread = notification['is_read'] != true;
    final title = notification['title']?.toString() ?? 'Notification';
    final message = notification['message']?.toString() ?? '';
    final formattedDate = _formatDate(notification['created_at']?.toString());

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        final id = _parseId(notification['id']);
        if (isUnread) {
          notification['is_read'] = true;
          onRefresh();
          if (id != null) {
            controller.markAsRead(id).then((_) => onRefresh()).catchError((e) {
              debugPrint('Error marking notification read on tap: $e');
              return <Map<String, dynamic>>[];
            });
          }
        }
        Navigator.of(dialogCtx).pop();
        Future.delayed(Duration.zero, () {
          onNotificationTap(notification);
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUnread
              ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.14 : 0.05)
              : (isDark ? AppTheme.darkSurfaceColor : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isUnread
                ? AppTheme.primaryColor.withValues(alpha: 0.25)
                : AppTheme.getBorderColor(modalCtx),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isUnread
                    ? (isDark
                          ? AppTheme.dangerColor.withValues(alpha: 0.2)
                          : AppTheme.dangerBg)
                    : (isDark ? AppTheme.darkCardColor : Colors.grey.shade200),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUnread
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                color: isUnread
                    ? AppTheme.dangerColor
                    : AppTheme.getTextSecondaryColor(modalCtx),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.getTextPrimaryColor(modalCtx),
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.getTextSecondaryColor(modalCtx),
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.getTextSecondaryColor(
                              modalCtx,
                            ).withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      Text(
                        'Open module →',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
                tooltip: 'Mark as read',
                onPressed: () async {
                  final id = _parseId(notification['id']);
                  notification['is_read'] = true;
                  if (id != null) {
                    try {
                      await controller.markAsRead(id);
                    } catch (e) {
                      debugPrint('Error marking notification read: $e');
                    }
                  }
                  await onRefresh();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '-';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return rawDate;
    }
  }
}
