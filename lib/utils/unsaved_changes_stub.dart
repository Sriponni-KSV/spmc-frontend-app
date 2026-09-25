/// Stub implementation for non-web platforms (Android, iOS, Windows, macOS, Linux).
class UnsavedChangesHelper {
  static void setUnsavedChanges(bool hasUnsavedData) {}
  static void clear() {}
  static void registerBackPressedHandler(void Function() onBackPressed) {}
  static void unregisterBackPressedHandler() {}
}
