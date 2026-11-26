import 'package:flutter/material.dart';
import 'modal_history_helper.dart';

export 'modal_history_helper.dart';

/// NavigatorObserver that hooks into all route pushes and pops to synchronize
/// modal popups and dialogs with browser history on Web.
class ModalHistoryObserver extends NavigatorObserver {
  static bool isPopupRoute(Route<dynamic> route) {
    if (route is PageRoute) return false;

    final typeName = route.runtimeType.toString();
    final lowerName = typeName.toLowerCase();

    // Never intercept transient UI menus, dropdowns, popup menus, tooltips or submenus
    if (lowerName.contains('dropdown') ||
        lowerName.contains('popupmenu') ||
        lowerName.contains('menu') ||
        lowerName.contains('tooltip')) {
      return false;
    }

    // Only intercept actual dialogs, bottom sheets, and modal barriers
    if (route is RawDialogRoute ||
        route is DialogRoute ||
        lowerName.contains('dialog') ||
        lowerName.contains('bottomsheet')) {
      return true;
    }

    return false;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (isPopupRoute(route)) {
      ModalHistoryHelper.onPopupPushed(route);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (isPopupRoute(route)) {
      ModalHistoryHelper.onPopupPopped(route);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (isPopupRoute(route)) {
      ModalHistoryHelper.onPopupPopped(route);
    }
  }
}
