import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';

/// Web implementation that intercepts browser Back button to dismiss open modal popups/dialogs
/// before allowing browser history to change main route views.
class ModalHistoryHelper {
  static final List<Route<dynamic>> _popupRoutes = [];
  static int _pushedHistoryCount = 0;
  static bool _isHandlingPopState = false;
  static int _ignorePopStateCount = 0;
  static bool _skipNextBack = false;
  static bool _initialized = false;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static bool _isValidModalRoute(Route<dynamic> route) {
    if (route is PageRoute) return false;
    final lowerName = route.runtimeType.toString().toLowerCase();
    if (lowerName.contains('dropdown') ||
        lowerName.contains('popupmenu') ||
        lowerName.contains('menu') ||
        lowerName.contains('tooltip')) {
      return false;
    }
    return route is RawDialogRoute ||
        route is DialogRoute ||
        lowerName.contains('dialog') ||
        lowerName.contains('bottomsheet');
  }

  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    _popupRoutes.clear();
    _pushedHistoryCount = 0;
    _isHandlingPopState = false;
    _ignorePopStateCount = 0;
    _skipNextBack = false;

    if (_initialized) return;
    _initialized = true;

    // Clean up any corrupt history state that does not have GoRouter's expected keys
    try {
      final currentState = html.window.history.state;
      if (currentState is Map && !currentState.containsKey('location')) {
        html.window.history.replaceState(null, '', html.window.location.href);
      }
    } catch (_) {}

    html.window.addEventListener('popstate', (html.Event event) {
      if (_ignorePopStateCount > 0) {
        _ignorePopStateCount--;
        return;
      }

      // Ensure any corrupt history state during popstate is sanitized before GoRouter parses it
      try {
        final currentState = html.window.history.state;
        if (currentState is Map && !currentState.containsKey('location')) {
          html.window.history.replaceState(null, '', html.window.location.href);
        }
      } catch (_) {}

      if (_popupRoutes.isNotEmpty || _pushedHistoryCount > 0) {
        _pushedHistoryCount = (_pushedHistoryCount - 1).clamp(0, 999999);
        _isHandlingPopState = true;

        try {
          bool poppedAny = false;
          while (_popupRoutes.isNotEmpty) {
            final topRoute = _popupRoutes.last;
            final isMounted = (topRoute is ModalRoute)
                ? (topRoute.subtreeContext != null && topRoute.subtreeContext!.mounted)
                : true;

            if (topRoute.isActive && topRoute.navigator != null && isMounted) {
              try {
                topRoute.navigator!.maybePop().catchError((_) => false);
                poppedAny = true;
              } catch (_) {}
              break;
            } else {
              // Stale or unmounted route from a previous screen or hot restart
              _popupRoutes.removeLast();
            }
          }

          if (!poppedAny && _navigatorKey?.currentState?.canPop() == true) {
            _navigatorKey!.currentState!.maybePop().catchError((_) => false);
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

  static void reset() {
    _popupRoutes.clear();
    _pushedHistoryCount = 0;
    _skipNextBack = false;
    _isHandlingPopState = false;
    _ignorePopStateCount = 0;
  }

  static void onPopupPushed(Route<dynamic> route) {
    if (!_isValidModalRoute(route)) return;
    _popupRoutes.add(route);
    if (!_isHandlingPopState) {
      try {
        final currentState = html.window.history.state;
        // Never put custom keys like 'flutter_modal_popup' in history state.
        // GoRouter expects history state to be null or a valid RouteMatchList map with 'location'.
        final stateToPush = (currentState is Map && currentState.containsKey('location'))
            ? currentState
            : null;
        html.window.history.pushState(
          stateToPush,
          '',
          html.window.location.href,
        );
        _pushedHistoryCount++;
      } catch (_) {}
    }
  }

  static void onPopupPopped(Route<dynamic> route) {
    if (!_isValidModalRoute(route)) return;
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
      _ignorePopStateCount++;
      try {
        html.window.history.back();
      } catch (_) {
        if (_ignorePopStateCount > 0) _ignorePopStateCount--;
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_ignorePopStateCount > 0) {
          _ignorePopStateCount--;
        }
      });
    }
  }
}
