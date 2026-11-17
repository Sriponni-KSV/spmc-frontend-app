/// Stub implementation for non-web platforms (Android, iOS, Windows, macOS, Linux).
class UnsavedChangesHelper {
  static bool hasUnsavedChanges = false;

  static void setUnsavedChanges(bool hasUnsavedData) {
    hasUnsavedChanges = hasUnsavedData;
  }

  static void clear() {
    hasUnsavedChanges = false;
  }

  static void registerBackPressedHandler(void Function() onBackPressed) {}
  static void unregisterBackPressedHandler() {}
}
