import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';

class CustomDropdownSearch extends StatefulWidget {
  final String label;
  final String? hint;
  final List<String>? dropdownItems;
  final Map<String, String>?
      dropdownMap; // Map of database ID (value) to Display Name (label)
  final String? value;
  final ValueChanged<String?>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool requiredMark;
  final bool clearOnSelect;
  final bool isEnabled;
  final double height;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final double? borderWidth;
  final double? focusedBorderWidth;
  final Color? fillColor;
  final Color? popupBgColor;
  final double? hintFontSize;
  final bool allowFreeText;
  final bool readOnly;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  const CustomDropdownSearch({
    super.key,
    required this.label,
    this.hint,
    this.dropdownItems,
    this.dropdownMap,
    this.value,
    this.onChanged,
    this.validator,
    this.requiredMark = false,
    this.clearOnSelect = false,
    this.isEnabled = true,
    this.height = 52,
    this.borderColor,
    this.focusedBorderColor,
    this.borderWidth,
    this.focusedBorderWidth,
    this.fillColor,
    this.popupBgColor,
    this.hintFontSize,
    this.allowFreeText = false,
    this.readOnly = false,
    this.maxLength = 60,
    this.inputFormatters,
  });

  static bool get isOpen =>
      _CustomDropdownSearchState._closeActiveDropdown != null;

  @override
  State<CustomDropdownSearch> createState() => _CustomDropdownSearchState();
}

class _CustomDropdownSearchState extends State<CustomDropdownSearch>
    with WidgetsBindingObserver {
  static VoidCallback? _closeActiveDropdown;

  final _groupId = Object();
  OverlayEntry? _overlayEntry;
  final _layerLink = LayerLink();
  final _fieldKey = GlobalKey<FormFieldState<String>>();

  /// Controller for inline search typing in the main input field.
  late TextEditingController _textEditingController;
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _mainFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<MapEntry<String, String>> _filteredItems = [];
  int _highlightedIndex = 0;

  Map<String, String> get _allEntries {
    if (widget.dropdownMap != null) {
      return widget.dropdownMap!;
    } else if (widget.dropdownItems != null) {
      return {for (var item in widget.dropdownItems!) item: item};
    }
    return {};
  }

  /// Returns the effective placeholder text.
  /// Priority: explicit hint → auto-derived from label → generic fallback.
  String get _effectiveHint {
    if (widget.hint != null && widget.hint!.isNotEmpty) return widget.hint!;
    if (widget.label.isNotEmpty) {
      final lower = widget.label.toLowerCase();
      // If the label already starts with 'select', use it directly
      if (lower.startsWith('select')) return 'Select ${widget.label.substring(6).trim()}';
      return 'Select ${widget.label}';
    }
    return 'Select...';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _filteredItems = _allEntries.entries.toList();

    final displayValue = _allEntries[widget.value] ?? widget.value ?? '';
    _textEditingController = TextEditingController(text: displayValue);

    _searchFocusNode.onKeyEvent = (node, event) => _handleKey(event);
    _mainFocusNode.onKeyEvent = (node, event) => _handleKey(event);
    _searchFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_searchFocusNode.hasFocus && !_mainFocusNode.hasFocus) {
      if (_fieldKey.currentState != null) {
        _validateAndSyncInput(_fieldKey.currentState!);
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _validateAndSyncInput(FormFieldState<String> field) {
    if (widget.allowFreeText) return;

    final text = _textEditingController.text.trim();

    if (text.isEmpty) {
      if (widget.value != null && widget.value!.isNotEmpty) {
        field.didChange(null);
        widget.onChanged?.call(null);
      }
      return;
    }

    MapEntry<String, String>? matchedEntry;
    for (final entry in _allEntries.entries) {
      if (entry.key.toLowerCase() == text.toLowerCase() ||
          entry.value.toLowerCase() == text.toLowerCase()) {
        matchedEntry = entry;
        break;
      }
    }

    if (matchedEntry != null) {
      field.didChange(matchedEntry.key);
      _textEditingController.text = matchedEntry.value;
      widget.onChanged?.call(matchedEntry.key);
    } else {
      _textEditingController.clear();
      field.didChange(null);
      widget.onChanged?.call(null);
      _filteredItems = _allEntries.entries.toList();
    }
  }

  /// Called by the framework when window metrics change (e.g. keyboard
  /// opens or closes). Rebuilds the overlay so it can reposition.
  @override
  void didChangeMetrics() {
    // Rebuild overlay so it can reposition when keyboard opens/closes.
    if (_overlayEntry != null && _overlayEntry!.mounted) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (_overlayEntry == null || !_overlayEntry!.mounted) return KeyEventResult.ignored;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_highlightedIndex < _filteredItems.length - 1) {
          _highlightedIndex++;
          _scrollToHighlight();
          if (_overlayEntry != null && _overlayEntry!.mounted) {
            _overlayEntry!.markNeedsBuild();
          }
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_highlightedIndex > 0) {
          _highlightedIndex--;
          _scrollToHighlight();
          if (_overlayEntry != null && _overlayEntry!.mounted) {
            _overlayEntry!.markNeedsBuild();
          }
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_filteredItems.isNotEmpty &&
            _highlightedIndex >= 0 &&
            _highlightedIndex < _filteredItems.length) {
          if (_fieldKey.currentState != null) {
            _selectItem(
              _fieldKey.currentState!,
              _filteredItems[_highlightedIndex],
            );
          }
          return KeyEventResult.handled;
        } else {
          if (_fieldKey.currentState != null) {
            _validateAndSyncInput(_fieldKey.currentState!);
          }
          _hideDropdown();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _scrollToHighlight() {
    if (_scrollController.hasClients) {
      const double itemHeight = 40.0;
      final double targetPosition = _highlightedIndex * itemHeight;
      if (targetPosition < _scrollController.position.pixels) {
        _scrollController.animateTo(
          targetPosition,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
        );
      } else if (targetPosition + itemHeight >
          _scrollController.position.pixels +
              _scrollController.position.viewportDimension) {
        _scrollController.animateTo(
          targetPosition +
              itemHeight -
              _scrollController.position.viewportDimension,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _selectItem(
      FormFieldState<String> field, MapEntry<String, String> entry) {
    if (widget.clearOnSelect) {
      field.didChange(null);
      _textEditingController.clear();
      _filterItems('');
    } else {
      field.didChange(entry.key);
      _textEditingController.text = entry.value;
      _filterItems(entry.value);
    }
    widget.onChanged?.call(entry.key);
    _searchFocusNode.unfocus();
    _mainFocusNode.unfocus();
    _hideDropdown();
  }

  @override
  void didUpdateWidget(CustomDropdownSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only call didChange when the actual selected value changes!
    if (widget.value != oldWidget.value) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _fieldKey.currentState != null) {
          _fieldKey.currentState!.didChange(widget.value);
        }
      });
    }

    // Keep display text in sync when value changes externally and user is not actively typing
    if (widget.value != oldWidget.value) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_searchFocusNode.hasFocus) {
          final displayValue = _allEntries[widget.value] ?? widget.value ?? '';
          if (displayValue != _textEditingController.text) {
            _textEditingController.text = displayValue;
          }
          if (widget.value == null || widget.value!.isEmpty) {
            _filteredItems = _allEntries.entries.toList();
          }
        }
      });
    }

    if (widget.dropdownItems != oldWidget.dropdownItems ||
        widget.dropdownMap != oldWidget.dropdownMap) {
      if (!_searchFocusNode.hasFocus) {
        _filteredItems = _allEntries.entries.toList();
      }
    }
  }

  void _filterItems(String query) {
    setState(() {
      _highlightedIndex = 0;
      if (query.isEmpty) {
        _filteredItems = _allEntries.entries.toList();
      } else {
        _filteredItems = _allEntries.entries
            .where((entry) =>
                entry.value.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
    _overlayEntry?.markNeedsBuild();
  }

  void _toggleDropdown(FormFieldState<String> field) {
    if (_overlayEntry != null) {
      _hideDropdown();
    } else {
      _showDropdown(field);
    }
  }

  /// Intercepts trackpad/mouse-wheel scroll signals and forwards them directly
  /// to the [ScrollController], bypassing the TextField focus absorption.
  void _handlePointerScroll(PointerScrollEvent event) {
    if (!_scrollController.hasClients) return;
    final double scrollDelta = event.scrollDelta.dy;
    final double newOffset = (_scrollController.offset + scrollDelta).clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(newOffset);
  }

  void _showDropdown(FormFieldState<String> field) {
    if (!widget.isEnabled) return;
    if (_closeActiveDropdown != null) {
      _closeActiveDropdown!();
    }
    _closeActiveDropdown = _hideDropdown;

    final currentText = _textEditingController.text.trim();
    final selectedDisplay = _allEntries[widget.value] ?? widget.value ?? '';
    if (currentText.isEmpty || currentText == selectedDisplay) {
      _filteredItems = _allEntries.entries.toList();
    }

    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject == null || renderObject is! RenderBox || !renderObject.attached) {
      return;
    }

    _highlightedIndex = 0;
    if (!widget.readOnly && !_searchFocusNode.hasFocus) {
      _searchFocusNode.requestFocus();
    }

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        if (!mounted) return const SizedBox.shrink();
        final currentRenderObject = context.findRenderObject();
        if (currentRenderObject == null ||
            currentRenderObject is! RenderBox ||
            !currentRenderObject.attached) {
          return const SizedBox.shrink();
        }
        final RenderBox activeRenderBox = currentRenderObject;
        final activeSize = activeRenderBox.size;
        final fieldGlobal = activeRenderBox.localToGlobal(Offset.zero);

        // Compute available space below and above the field, accounting for keyboard.
        const double kDropdownMaxHeight = 300;
        final view = WidgetsBinding.instance.platformDispatcher.views.first;
        final double screenHeight =
            view.physicalSize.height / view.devicePixelRatio;
        final double keyboardHeight =
            view.viewInsets.bottom / view.devicePixelRatio;

        final spaceBelow =
            screenHeight - fieldGlobal.dy - activeSize.height - keyboardHeight - 12;
        final spaceAbove = fieldGlobal.dy - 12;

        // Flexible placement: show above if space below is tight and there is more space above
        final showAbove =
            spaceBelow < kDropdownMaxHeight && spaceAbove > spaceBelow;

        // When opening upward, anchor the follower's bottom to the target's top.
        final Offset offset = showAbove
            ? const Offset(0, -6) // follower-bottom → target-top minus gap
            : Offset(0, activeSize.height + 6);
        final Alignment tAnchor =
            showAbove ? Alignment.topLeft : Alignment.topLeft;
        final Alignment fAnchor =
            showAbove ? Alignment.bottomLeft : Alignment.topLeft;

        return Positioned(
          width: activeSize.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: tAnchor,
            followerAnchor: fAnchor,
            offset: offset,
            // Wrap overlay in TapRegion with the same groupId so
            // touches inside the dropdown are NOT treated as
            // "tap outside" the TextField, preventing focus loss.
            child: TapRegion(
              groupId: _groupId,
              child: Material(
                type: MaterialType.card,
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                color: widget.popupBgColor ?? Colors.white,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {}, // absorb taps inside overlay
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.popupBgColor ?? Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        width: 1,
                        color: const Color(0xFF302861).withValues(alpha: 0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF302861).withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    constraints:
                        const BoxConstraints(maxHeight: kDropdownMaxHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: _filteredItems.isEmpty
                              ? (widget.allowFreeText && _textEditingController.text.trim().isNotEmpty
                                  ? Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          final customVal = _textEditingController.text.trim();
                                          if (_fieldKey.currentState != null) {
                                            _selectItem(
                                              _fieldKey.currentState!,
                                              MapEntry(customVal, customVal),
                                            );
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.add_circle_outline, size: 18, color: AppTheme.primaryColor),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Add "${_textEditingController.text.trim()}"',
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.primaryColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.all(16),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'No matching items found',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          color: Colors.grey.shade500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ))
                              : Listener(
                                  onPointerSignal: (event) {
                                    if (event is PointerScrollEvent) {
                                      _handlePointerScroll(event);
                                    }
                                  },
                                  child: ScrollConfiguration(
                                    // Allow trackpad pan gestures to scroll the list.
                                    behavior: _TrackpadAwareScrollBehavior(),
                                    child: ListView.builder(
                                      controller: _scrollController,
                                      shrinkWrap: true,
                                      physics: const ClampingScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      itemCount: _filteredItems.length,
                                      itemBuilder: (context, index) {
                                        final entry = _filteredItems[index];
                                        final isHighlighted =
                                            index == _highlightedIndex;
                                        final isSelected =
                                            entry.key == widget.value;

                                        return Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            splashFactory:
                                                NoSplash.splashFactory,
                                            onTap: () {
                                              if (_fieldKey.currentState !=
                                                  null) {
                                                _selectItem(
                                                  _fieldKey.currentState!,
                                                  entry,
                                                );
                                              }
                                            },
                                            child: Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 10,
                                                horizontal: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                color: isSelected
                                                    ? const Color(0xFF302861)
                                                        .withValues(
                                                            alpha: 0.06)
                                                    : (isHighlighted
                                                        ? Colors.grey.shade100
                                                        : Colors.transparent),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      entry.value,
                                                      style:
                                                          TextStyle(
                                                        fontFamily: 'Inter',
                                                        color: isSelected
                                                            ? const Color(
                                                                0xFF302861)
                                                            : Colors.black87,
                                                        fontSize: 14,
                                                        fontWeight: isSelected
                                                            ? FontWeight.w600
                                                            : FontWeight.w400,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    const Icon(
                                                      Icons.check,
                                                      size: 16,
                                                      color:
                                                          Color(0xFF302861),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    final overlay = Overlay.maybeOf(context);
    if (overlay != null && mounted) {
      overlay.insert(_overlayEntry!);
      if (mounted) setState(() {});
    }
  }

  void _hideDropdown() {
    if (_overlayEntry != null) {
      if (_overlayEntry!.mounted) {
        _overlayEntry!.remove();
      }
      _overlayEntry = null;
    }
    if (_closeActiveDropdown == _hideDropdown) {
      _closeActiveDropdown = null;
    }
    _highlightedIndex = 0;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchFocusNode.removeListener(_onFocusChange);
    if (_overlayEntry != null) {
      if (_overlayEntry!.mounted) {
        _overlayEntry!.remove();
      }
      _overlayEntry = null;
    }
    if (_closeActiveDropdown == _hideDropdown) {
      _closeActiveDropdown = null;
    }
    _textEditingController.dispose();
    _searchFocusNode.dispose();
    _mainFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _mainFocusNode,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label.isNotEmpty) ...[
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: widget.label,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.requiredMark)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          CompositedTransformTarget(
            link: _layerLink,
            child: FormField<String>(
              key: _fieldKey,
              initialValue: widget.value,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (val) {
                if (!widget.allowFreeText) {
                  final rawText = _textEditingController.text.trim();
                  if (rawText.isNotEmpty) {
                    final isKnown = _allEntries.entries.any((e) =>
                        e.key.toLowerCase() == rawText.toLowerCase() ||
                        e.value.toLowerCase() == rawText.toLowerCase());
                    if (!isKnown) {
                      return 'Please select a valid option from the list';
                    }
                  }
                  if (val != null && val.trim().isNotEmpty) {
                    final isValid = _allEntries.containsKey(val) ||
                        _allEntries.containsValue(val);
                    if (!isValid) {
                      return 'Please select a valid option from the list';
                    }
                  }
                }
                if (widget.validator != null) {
                  return widget.validator!(val);
                }
                return null;
              },
              builder: (field) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TapRegion(
                      groupId: _groupId,
                      onTapOutside: (_) {
                        _hideDropdown();
                        if (_fieldKey.currentState != null) {
                          _validateAndSyncInput(_fieldKey.currentState!);
                        }
                        _searchFocusNode.unfocus();
                        _mainFocusNode.unfocus();
                      },
                      child: Container(
                        width: double.infinity,
                        height: widget.height,
                        clipBehavior: Clip.none,
                        decoration: BoxDecoration(
                          color: widget.isEnabled
                              ? (widget.fillColor ?? const Color(0xFFF1F5F9))
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            width: field.hasError
                                ? 1.5
                                : _searchFocusNode.hasFocus
                                    ? (widget.focusedBorderWidth ?? 1.4)
                                    : (widget.borderWidth ?? 0),
                            color: field.hasError
                                ? Colors.red
                                : _searchFocusNode.hasFocus
                                    ? (widget.focusedBorderColor ??
                                        const Color(0xFF302861))
                                    : widget.isEnabled
                                        ? (widget.borderColor ??
                                            Colors.transparent)
                                        : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textEditingController,
                                focusNode: _searchFocusNode,
                                enabled: widget.isEnabled,
                                readOnly: widget.readOnly,
                                enableInteractiveSelection: !widget.readOnly,
                                mouseCursor: widget.readOnly
                                    ? SystemMouseCursors.click
                                    : SystemMouseCursors.text,
                                textInputAction: TextInputAction.done,
                                onTapOutside: (_) {},
                                maxLength: widget.maxLength,
                                buildCounter: (
                                  context, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) =>
                                    null,
                                inputFormatters: widget.inputFormatters ??
                                    [
                                      if (widget.maxLength != null)
                                        LengthLimitingTextInputFormatter(
                                          widget.maxLength,
                                        ),
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):]'),
                                      ),
                                    ],
                                decoration: InputDecoration(
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  hintText: _effectiveHint,
                                  counterText: '',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Inter',
                                    color: const Color(0xFF9CA3AF),
                                    fontSize: widget.hintFontSize ?? 14,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: widget.isEnabled
                                      ? const Color(0xFF1E293B)
                                      : Colors.grey.shade500,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                                onChanged: (val) {
                                  if (widget.allowFreeText) {
                                    field.didChange(val);
                                    widget.onChanged?.call(val);
                                  } else {
                                    MapEntry<String, String>? matched;
                                    for (final entry in _allEntries.entries) {
                                      if (entry.key.toLowerCase() ==
                                              val.trim().toLowerCase() ||
                                          entry.value.toLowerCase() ==
                                              val.trim().toLowerCase()) {
                                        matched = entry;
                                        break;
                                      }
                                    }
                                    if (matched != null) {
                                      field.didChange(matched.key);
                                      widget.onChanged?.call(matched.key);
                                    } else {
                                      field.didChange(null);
                                      widget.onChanged?.call(null);
                                    }
                                  }
                                  _filterItems(val);
                                  if (_overlayEntry == null) {
                                    _showDropdown(field);
                                  }
                                },
                                onSubmitted: (_) {
                                  if (_fieldKey.currentState != null) {
                                    _validateAndSyncInput(_fieldKey.currentState!);
                                  }
                                  _hideDropdown();
                                },
                                onTap: () {
                                  _toggleDropdown(field);
                                },
                              ),
                            ),
                            GestureDetector(
                              onTap: widget.isEnabled
                                  ? () => _toggleDropdown(field)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  _overlayEntry != null
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 22,
                                  color: widget.isEnabled
                                      ? const Color(0xFF302861)
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (field.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          field.errorText ?? "",
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackpadAwareScrollBehavior extends ScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
