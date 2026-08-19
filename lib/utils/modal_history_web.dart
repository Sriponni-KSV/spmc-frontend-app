import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';

/// Web implementation that intercepts browser Back button to dismiss open modal popups/dialogs
/// before allowing browser history to change main route views.
class ModalHistoryHelper {
  static final List<Route<dynamic>> _popupRoutes = [];
  static int _pushedHistoryCount = 0;
  static bool _isHandlingPopState = false;
  static bool _isIgnoringPopState = false;
  static bool _skipNextBack = false;
  static bool _initialized = false;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    if (_initialized) return;
    _initialized = true;

    html.window.addEventListener('popstate', (html.Event event) {
      if (_isIgnoringPopState) {
        _isIgnoringPopState = false;
        return;
      }

      if (_popupRoutes.isNotEmpty || _pushedHistoryCount > 0) {
        _pushedHistoryCount = (_pushedHistoryCount - 1).clamp(0, 999999);
        _isHandlingPopState = true;

        try {
          if (_popupRoutes.isNotEmpty) {
            final topRoute = _popupRoutes.last;
            if (topRoute.isActive && topRoute.navigator != null) {
              topRoute.navigator!.maybePop();
            } else if (_navigatorKey?.currentState?.canPop() == true) {
              _navigatorKey!.currentState!.maybePop();
            }
          } else if (_navigatorKey?.currentState?.canPop() == true) {
            _navigatorKey!.currentState!.maybePop();
          }
        } catch (_) {}

        scheduleMicrotask(() {
          _isHandlingPopState = false;
        });
      }
    });
  }

  static void skipNextHistoryBack() {
    _skipNextBack = true;
    if (_pushedHistoryCount > 0) {
      _pushedHistoryCount--;
    }
  }

  static void onPopupPushed(Route<dynamic> route) {
    _popupRoutes.add(route);
    if (!_isHandlingPopState) {
      try {
        final currentState = html.window.history.state;
        Map<dynamic, dynamic> newState = {};
        if (currentState is Map) {
          try {
            newState = Map<dynamic, dynamic>.from(currentState);
          } catch (_) {}
        }
        newState['flutter_modal_popup'] = true;
        html.window.history.pushState(
          newState,
          '',
          html.window.location.href,
        );
        _pushedHistoryCount++;
      } catch (_) {}
    }
  }

  static void onPopupPopped(Route<dynamic> route) {
    _popupRoutes.remove(route);

    if (_isHandlingPopState) {
      // Pop was already triggered and consumed by browser back button popstate
      return;
    }

    if (_skipNextBack) {
      _skipNextBack = false;
      return;
    }

    if (_pushedHistoryCount > 0) {
      _pushedHistoryCount--;
      _isIgnoringPopState = true;
      try {
        html.window.history.back();
      } catch (_) {
        _isIgnoringPopState = false;
      }
      Future.delayed(const Duration(milliseconds: 100), () {
        _isIgnoringPopState = false;
      });
    }
  }
}
