import 'package:flutter/material.dart';

/// Comprehensive Form Validation & Auto-Scroll Helper for Sri Ponni Medical Centre HMS.
///
/// Features:
/// 1. Validates all FormFields registered in the Form.
/// 2. If invalid, traverses the Element tree in pre-order (document/visual order)
///    to identify the FIRST invalid field.
/// 3. Automatically scrolls the enclosing Scrollable (SingleChildScrollView, ListView,
///    Dialog, BottomSheet, CustomScrollView, etc.) so that the first invalid field
///    is positioned comfortably in view (above on-screen soft keyboards).
/// 4. Handles nested scrollables seamlessly.
/// 5. Automatically detects and requests focus on the field's [FocusNode], allowing
///    immediate correction by the user.
/// 6. Highlights invalid fields using the standard HMS theme red error border and
///    clear error text directly below the field.
class FormScrollHelper {
  /// Validates [formKey]. If validation fails, automatically scrolls to the first
  /// invalid field and requests focus on it.
  ///
  /// Returns `true` if valid, `false` if invalid.
  static bool validateAndScrollToFirstInvalid(
    GlobalKey<FormState> formKey, {
    double alignment = 0.12,
    Duration duration = const Duration(milliseconds: 380),
    Curve curve = Curves.easeInOut,
    ScrollController? scrollController,
  }) {
    final FormState? formState = formKey.currentState;
    final BuildContext? rootContext = formKey.currentContext;

    if (formState == null || rootContext == null || !rootContext.mounted) {
      return false;
    }

    // Step 1: Validate all form fields
    final bool isValid = formState.validate();
    if (isValid) {
      return true;
    }

    // Step 2: Schedule auto-scroll on post-frame so error borders/messages have rendered
    // and layout heights are fully updated.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rootContext.mounted) return;
      scrollToFirstInvalidField(
        rootContext,
        alignment: alignment,
        duration: duration,
        curve: curve,
        scrollController: scrollController,
      );
    });

    return false;
  }

  /// Finds the first invalid field within [context] and scrolls to it.
  static bool scrollToFirstInvalidField(
    BuildContext context, {
    double alignment = 0.12,
    Duration duration = const Duration(milliseconds: 380),
    Curve curve = Curves.easeInOut,
    ScrollController? scrollController,
  }) {
    final BuildContext? invalidContext = findFirstInvalidFieldContext(context);
    if (invalidContext == null || !invalidContext.mounted) {
      return false;
    }

    scrollToContext(
      invalidContext,
      alignment: alignment,
      duration: duration,
      curve: curve,
      scrollController: scrollController,
    );

    // Focus the invalid field if a FocusNode exists in its element subtree
    if (invalidContext is Element) {
      final FocusNode? focusNode = findFocusNode(invalidContext);
      if (focusNode != null && focusNode.canRequestFocus) {
        focusNode.requestFocus();
      }
    }

    return true;
  }

  /// Scrolls any enclosing scrollables so that [targetContext] is comfortably visible.
  /// Handles nested scrollables and accounts for keyboard height.
  static void scrollToContext(
    BuildContext targetContext, {
    double alignment = 0.12,
    Duration duration = const Duration(milliseconds: 380),
    Curve curve = Curves.easeInOut,
    ScrollController? scrollController,
  }) {
    if (!targetContext.mounted) return;

    try {
      // Walk up the tree to ensure visibility in all enclosing scrollables
      BuildContext? current = targetContext;
      while (current != null && current.mounted) {
        final ScrollableState? scrollable = Scrollable.maybeOf(current);
        if (scrollable == null) break;

        Scrollable.ensureVisible(
          targetContext,
          alignment: alignment,
          duration: duration,
          curve: curve,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );

        final BuildContext parent = scrollable.context;
        current = parent.findAncestorStateOfType<ScrollableState>()?.context;
      }
    } catch (_) {
      // Fallback: If Scrollable.ensureVisible fails, use the provided scrollController
      if (scrollController != null && scrollController.hasClients) {
        final renderObject = targetContext.findRenderObject();
        if (renderObject is RenderBox && renderObject.attached) {
          final offset = renderObject.localToGlobal(Offset.zero);
          final targetOffset = (scrollController.offset + offset.dy - 120).clamp(
            0.0,
            scrollController.position.maxScrollExtent,
          );
          scrollController.animateTo(
            targetOffset,
            duration: duration,
            curve: curve,
          );
        }
      }
    }
  }

  /// Traverses the widget Element tree downwards in pre-order DFS
  /// to find the first Element whose state is [FormFieldState] and has an error.
  static BuildContext? findFirstInvalidFieldContext(BuildContext context) {
    BuildContext? firstInvalid;

    void visitor(Element element) {
      if (firstInvalid != null) return; // Stop as soon as the first invalid in document order is found

      if (element is StatefulElement) {
        final state = element.state;
        if (state is FormFieldState && state.hasError) {
          firstInvalid = element;
          return;
        }
      }

      element.visitChildren(visitor);
    }

    if (context is Element) {
      visitor(context);
    }

    return firstInvalid;
  }

  /// Recursively searches an Element and its subtree to discover any active [FocusNode].
  static FocusNode? findFocusNode(Element element) {
    FocusNode? foundNode;

    void visitor(Element el) {
      if (foundNode != null) return;

      final widget = el.widget;
      if (widget is Focus && widget.focusNode != null) {
        foundNode = widget.focusNode;
        return;
      } else if (widget is EditableText && widget.focusNode != null) {
        foundNode = widget.focusNode;
        return;
      }

      el.visitChildren(visitor);
    }

    visitor(element);
    return foundNode;
  }
}

/// Extension methods on [GlobalKey<FormState>] for convenient validation with auto-scroll.
extension FormKeyScrollValidationExtension on GlobalKey<FormState> {
  /// Validates the form and automatically scrolls to and focuses the first invalid field.
  bool validateAndScroll({
    double alignment = 0.12,
    Duration duration = const Duration(milliseconds: 380),
    Curve curve = Curves.easeInOut,
    ScrollController? scrollController,
  }) {
    return FormScrollHelper.validateAndScrollToFirstInvalid(
      this,
      alignment: alignment,
      duration: duration,
      curve: curve,
      scrollController: scrollController,
    );
  }
}

/// Extension methods on [FormState] for convenient validation with auto-scroll.
extension FormStateScrollValidationExtension on FormState {
  /// Validates the form and automatically scrolls to and focuses the first invalid field.
  bool validateAndScroll({
    double alignment = 0.12,
    Duration duration = const Duration(milliseconds: 380),
    Curve curve = Curves.easeInOut,
    ScrollController? scrollController,
  }) {
    final bool isValid = validate();
    if (isValid) return true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        FormScrollHelper.scrollToFirstInvalidField(
          context,
          alignment: alignment,
          duration: duration,
          curve: curve,
          scrollController: scrollController,
        );
      }
    });

    return false;
  }
}

/// Extension on [BuildContext] for quick form validation and auto-scroll.
extension BuildContextFormScrollExtension on BuildContext {
  /// Validates the form identified by [formKey] and automatically scrolls to the first error.
  bool validateAndScrollForm(
    GlobalKey<FormState> formKey, {
    double alignment = 0.12,
    Duration duration = const Duration(milliseconds: 380),
    Curve curve = Curves.easeInOut,
    ScrollController? scrollController,
  }) {
    return FormScrollHelper.validateAndScrollToFirstInvalid(
      formKey,
      alignment: alignment,
      duration: duration,
      curve: curve,
      scrollController: scrollController,
    );
  }
}

/// Reusable Form widget that encapsulates automatic error scrolling.
class AutoScrollForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final Widget child;
  final AutovalidateMode? autovalidateMode;
  final VoidCallback? onChanged;

  const AutoScrollForm({
    super.key,
    required this.formKey,
    required this.child,
    this.autovalidateMode,
    this.onChanged,
  });

  /// Validates this form and scrolls to the first invalid field.
  bool validate() {
    return formKey.validateAndScroll();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      autovalidateMode: autovalidateMode,
      onChanged: onChanged,
      child: child,
    );
  }
}

