import 'package:flutter/services.dart';

/// Formatter that automatically capitalizes the first letter of each word (Title Case)
/// as the user types, ensuring consistent capitalization across Web, Mobile, and Desktop.
class CapitalizeWordsInputFormatter extends TextInputFormatter {
  const CapitalizeWordsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final text = newValue.text;
    final buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      // Delimiters that trigger capitalization on the next letter
      if (char == ' ' || char == '.' || char == '-' || char == '/' || char == '(' || char == '[') {
        buffer.write(char);
        capitalizeNext = true;
      } else if (capitalizeNext) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
      }
    }

    final formattedText = buffer.toString();
    return newValue.copyWith(
      text: formattedText,
      selection: newValue.selection,
    );
  }
}
