import 'package:flutter/foundation.dart';

/// Centralized state for managing sidebar expand/collapse across the application.
class SidebarState {
  SidebarState._();

  static final ValueNotifier<bool> isCollapsed = ValueNotifier<bool>(false);

  static bool get collapsed => isCollapsed.value;

  static void toggle() {
    isCollapsed.value = !isCollapsed.value;
  }

  static void setCollapsed(bool value) {
    if (isCollapsed.value != value) {
      isCollapsed.value = value;
    }
  }
}
