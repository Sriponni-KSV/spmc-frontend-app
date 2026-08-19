/// Holds a transient email value used only when navigating between
/// the Login and Forgot Password screens via button press.
///
/// Because this is plain Dart in-memory state, it is reset to empty
/// whenever the app is cold-started or the browser page is refreshed —
/// so a manual refresh will always show a blank email field.
class AuthNavState {
  AuthNavState._();

  /// Email to pre-populate on the next login / forgot-password screen open.
  /// Consumed (read + cleared) in initState so it is never reused.
  static String _pendingEmail = '';

  /// Set the email before navigating away.
  static void setPendingEmail(String email) {
    _pendingEmail = email;
  }

  /// Read and immediately clear the pending email.
  /// Returns an empty string if nothing was set.
  static String consumePendingEmail() {
    final email = _pendingEmail;
    _pendingEmail = '';
    return email;
  }
}
