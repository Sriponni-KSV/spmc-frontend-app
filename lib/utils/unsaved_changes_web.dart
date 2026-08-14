import 'dart:html' as html;
import 'dart:js' as js;

/// Web implementation for intercepting browser page reloads/closes when unsaved form data exists.
class UnsavedChangesHelper {
  static html.EventListener? _beforeUnloadListener;

  /// Sets the global flag to trigger browser confirmation dialog on refresh/reload if [hasUnsavedData] is true.
  static void setUnsavedChanges(bool hasUnsavedData) {
    try {
      if (js.context.hasProperty('unsavedChanges')) {
        final unsavedObj = js.context['unsavedChanges'];
        if (unsavedObj != null) {
          unsavedObj.callMethod('setHasUnsavedData', [hasUnsavedData]);
        }
      }
    } catch (_) {}

    if (hasUnsavedData) {
      _enableDirectListener();
    } else {
      _disableDirectListener();
    }
  }

  /// Clears the unsaved changes warning (e.g. after successful form submission).
  static void clear() {
    setUnsavedChanges(false);
  }

  static void _enableDirectListener() {
    if (_beforeUnloadListener != null) return;

    _beforeUnloadListener = (html.Event event) {
      if (event is html.BeforeUnloadEvent) {
        event.preventDefault();
        event.returnValue = 'Do you want to refresh? All unsaved data will be lost.';
      } else {
        event.preventDefault();
        (event as dynamic).returnValue = 'Do you want to refresh? All unsaved data will be lost.';
      }
    };

    html.window.addEventListener('beforeunload', _beforeUnloadListener!);
  }

  static void _disableDirectListener() {
    if (_beforeUnloadListener != null) {
      html.window.removeEventListener('beforeunload', _beforeUnloadListener!);
      _beforeUnloadListener = null;
    }
  }
}
