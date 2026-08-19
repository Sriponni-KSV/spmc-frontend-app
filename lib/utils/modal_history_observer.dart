import 'package:flutter/material.dart';
import 'modal_history_helper.dart';

export 'modal_history_helper.dart';

/// NavigatorObserver that hooks into all route pushes and pops to synchronize
/// modal popups and dialogs with browser history on Web.
class ModalHistoryObserver extends NavigatorObserver {
  static bool isPopupRoute(Route<dynamic> route) {
    if (route is PopupRoute) return true;
    if (route is ModalRoute && route is! PageRoute) return true;
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
