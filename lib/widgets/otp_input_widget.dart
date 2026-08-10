import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';

/// A smart, user-friendly 6-digit OTP input widget.
/// Supports:
///   - Paste: distributes all 6 digits across boxes automatically
///   - Arrow keys: Left/Right navigation between boxes
///   - Backspace: clears current box then moves focus back
///   - Auto-advance: moves forward as each digit is typed
///   - onCompleted callback when all 6 digits are filled
class OtpInputWidget extends StatefulWidget {
  /// Called with the full OTP string when all 6 digits are entered.
  final void Function(String otp)? onCompleted;

  /// Optional error message shown below boxes.
  final String? errorMessage;

  /// Called whenever any digit changes (useful to clear error state).
  final VoidCallback? onChanged;

  const OtpInputWidget({
    Key? key,
    this.onCompleted,
    this.errorMessage,
    this.onChanged,
  }) : super(key: key);

  @override
  OtpInputWidgetState createState() => OtpInputWidgetState();
}

class OtpInputWidgetState extends State<OtpInputWidget> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<FocusNode> _keyListenerNodes =
      List.generate(6, (_) => FocusNode(skipTraversal: true));

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    for (final f in _keyListenerNodes) {
      f.dispose();
    }
    super.dispose();
  }

  /// Returns the full 6-digit OTP string.
  String get otp => _controllers.map((c) => c.text).join();

  /// Clears all OTP fields and focuses the first box.
  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
    if (mounted) setState(() {});
  }

  void _notifyIfComplete() {
    final full = otp;
    if (full.length == 6 && widget.onCompleted != null) {
      widget.onCompleted!(full);
    }
  }

  /// Distributes [text] starting from [startIndex] across the boxes.
  void _distributeText(int startIndex, String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    for (int i = startIndex; i < 6 && (i - startIndex) < digits.length; i++) {
      _controllers[i].text = digits[i - startIndex];
      _controllers[i].selection = TextSelection.fromPosition(
        TextPosition(offset: 1),
      );
    }

    // Move focus to box after last filled one (or last box).
    final nextIndex = (startIndex + digits.length).clamp(0, 5);
    _focusNodes[nextIndex].requestFocus();

    if (mounted) setState(() {});
    widget.onChanged?.call();
    _notifyIfComplete();
  }

  void _onFieldChanged(int index, String value) {
    // Multi-character input: paste scenario.
    if (value.length > 1) {
      // Clear current field (it now has multiple chars), then distribute.
      _controllers[index].clear();
      _distributeText(index, value);
      return;
    }

    widget.onChanged?.call();

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
      _notifyIfComplete();
    }

    if (mounted) setState(() {});
  }

  void _handleKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isNotEmpty) {
        // Clear the current field only.
        _controllers[index].clear();
        widget.onChanged?.call();
        if (mounted) setState(() {});
      } else if (index > 0) {
        // Already empty — move back and clear previous box.
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
        widget.onChanged?.call();
        if (mounted) setState(() {});
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (index > 0) _focusNodes[index - 1].requestFocus();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (index < 5) _focusNodes[index + 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = widget.errorMessage != null;
    final Color activeBorder =
        hasError ? Colors.redAccent : AppTheme.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: SizedBox(
                width: 48,
                height: 56,
                child: KeyboardListener(
                  focusNode: _keyListenerNodes[index],
                  onKeyEvent: (event) => _handleKeyEvent(index, event),
                  child: TextFormField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    // Allow up to 6 chars so paste events can carry all digits.
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: hasError
                          ? Colors.red.withOpacity(0.04)
                          : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: hasError
                              ? Colors.redAccent
                              : Colors.grey.shade300,
                          width: hasError ? 1.5 : 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: activeBorder, width: 2),
                      ),
                    ),
                    onChanged: (val) => _onFieldChanged(index, val),
                    onTap: () {
                      // Select all so typing replaces existing digit.
                      _controllers[index].selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _controllers[index].text.length,
                      );
                    },
                  ),
                ),
              ),
            );
          }),
        ),
        if (hasError) ...[
          const SizedBox(height: 10),
          Text(
            widget.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
