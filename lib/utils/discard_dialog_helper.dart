import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_localizations.dart';
import 'modal_history_helper.dart';
import 'unsaved_changes_helper.dart';

/// Reusable helper to manage discard warning dialogs and protect
/// navigation/dialogs from losing unsaved changes.
class DiscardDialogHelper {
  /// In-memory indicator for unsaved changes queryable across the app
  static bool hasUnsavedChanges = false;

  /// Sets whether there are currently unsaved changes
  static void setHasUnsavedChanges(bool value) {
    hasUnsavedChanges = value;
    UnsavedChangesHelper.setUnsavedChanges(value);
  }

  /// Clears the unsaved changes state
  static void clear() {
    hasUnsavedChanges = false;
    UnsavedChangesHelper.clear();
  }

  /// Displays the standard Sri Ponni HMS discard confirmation dialog.
  /// Returns `true` if user confirmed to discard, `false` if they decided to stay.
  static Future<bool> showDiscardWarningDialog(
    BuildContext context, {
    String? title,
    String? message,
    String? confirmText,
    String? cancelText,
  }) async {
    final isMobile = MediaQuery.of(context).size.width < 500;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32,
            vertical: 24,
          ),
          child: Container(
            width: isMobile ? double.infinity : 440,
            constraints: const BoxConstraints(maxWidth: 440),
            padding: EdgeInsets.all(isMobile ? 18 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.dangerColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title ??
                            ctx.tr(
                              'discard_unsaved_changes',
                              fallback: 'Discard Unsaved Changes?',
                            ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.textPrimaryColor,
                          fontFamily: 'Inter',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  message ??
                      ctx.tr(
                        'discard_unsaved_body',
                        fallback:
                            'You have unsaved changes. If you leave now, your entries will be lost.\n\nDo you want to discard changes and leave?',
                      ),
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                    height: 1.4,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: AppTheme.cancelButton,
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(cancelText ?? ctx.tr('stay_on_page', fallback: 'Stay on Page')),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: AppTheme.dangerButton,
                      onPressed: () {
                        ModalHistoryHelper.skipNextHistoryBack();
                        Navigator.of(ctx).pop(true);
                      },
                      child: Text(confirmText ?? ctx.tr('discard_and_leave', fallback: 'Discard & Leave')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  /// Handles cancel, close, or back button press on popup dialogs.
  /// If [isDirty] is true, prompts with [showDiscardWarningDialog].
  /// If user confirms or if [isDirty] is false, pops the dialog and returns true.
  /// Otherwise returns false.
  static Future<bool> handleCancelOrDismiss(
    BuildContext context, {
    required bool isDirty,
    String? title,
    String? message,
    dynamic popResult,
  }) async {
    if (!isDirty) {
      Navigator.of(context).pop(popResult);
      return true;
    }
    final shouldDiscard = await showDiscardWarningDialog(
      context,
      title: title,
      message: message,
    );
    if (shouldDiscard && context.mounted) {
      clear();
      Navigator.of(context).pop(popResult);
      return true;
    }
    return false;
  }

  /// Intercepts back-gesture, Escape, and backdrop pop attempts.
  static Widget wrapWithPopScope({
    required BuildContext context,
    required bool isDirty,
    required Widget child,
    String? title,
    String? message,
    dynamic popResult,
  }) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final shouldDiscard = await showDiscardWarningDialog(
          context,
          title: title,
          message: message,
        );
        if (shouldDiscard && context.mounted) {
          clear();
          Navigator.of(context).pop(popResult);
        }
      },
      child: child,
    );
  }
}

