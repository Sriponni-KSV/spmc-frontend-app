import 'package:flutter/services.dart';

/// A [TextInputFormatter] that blocks paste operations on a text field.
///
/// It detects a paste by checking whether the incoming change inserts more
/// than one character at once (which keyboard typing cannot do). When such
/// a change is detected the old value is returned unchanged, effectively
/// silently discarding the pasted content.
///
/// Usage:
/// ```dart
/// inputFormatters: [NoPasteFormatter()],
/// ```
class NoPasteFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Number of characters added in this update.
    final added = newValue.text.length - oldValue.text.length;

    // More than one character inserted at once → treat it as a paste → reject.
    if (added > 1) {
      return oldValue;
    }

    return newValue;
  }
}
