import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

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
    this.height = 44,
    this.borderColor,
    this.focusedBorderColor,
    this.borderWidth,
    this.focusedBorderWidth,
    this.fillColor,
    this.popupBgColor,
    this.hintFontSize,
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

  /// When true, the dropdown list is being actively scrolled on a touch
  /// device. We use this to prevent accidental item selection.
  bool _isScrolling = false;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _filteredItems = _allEntries.entries.toList();

    final displayValue = _allEntries[widget.value] ?? widget.value ?? '';
    _textEditingController = TextEditingController(text: displayValue);

    // Track scroll activity so we can suppress accidental selection
    // during a touch scroll.
    _scrollController.addListener(() {
      if (_scrollController.position.isScrollingNotifier.value) {
        _isScrolling = true;
      }
    });

    _searchFocusNode.onKeyEvent = (node, event) => _handleKey(event);
    _mainFocusNode.onKeyEvent = (node, event) => _handleKey(event);
    _searchFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
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
        if (_highlightedIndex >= 0 &&
            _highlightedIndex < _filteredItems.length) {
          if (_fieldKey.currentState != null) {
            _selectItem(
              _fieldKey.currentState!,
              _filteredItems[_highlightedIndex],
            );
          }
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
    if (widget.value != oldWidget.value ||
        widget.dropdownMap != oldWidget.dropdownMap ||
        widget.dropdownItems != oldWidget.dropdownItems) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (_fieldKey.currentState != null) {
            _fieldKey.currentState!.didChange(widget.value);
          }
          final displayValue = _allEntries[widget.value] ?? widget.value ?? '';
          if (displayValue != _textEditingController.text) {
            _textEditingController.text = displayValue;
          }
        }
      });
    }
    if (widget.dropdownItems != oldWidget.dropdownItems ||
        widget.dropdownMap != oldWidget.dropdownMap) {
      _filteredItems = _allEntries.entries.toList();
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
    if (_overlayEntry != null && _overlayEntry!.mounted) {
      _overlayEntry!.markNeedsBuild();
    }
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

    _highlightedIndex = 0;
    if (!_searchFocusNode.hasFocus) {
      _searchFocusNode.requestFocus();
    }

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final RenderBox? currentRenderBox =
            context.findRenderObject() as RenderBox?;
        if (currentRenderBox == null || !currentRenderBox.attached) {
          return const SizedBox.shrink();
        }

        final size = currentRenderBox.size;
        final fieldGlobal = currentRenderBox.localToGlobal(Offset.zero);

        final mediaQuery = MediaQuery.maybeOf(context);
        final view = WidgetsBinding.instance.platformDispatcher.views.first;
        final double screenHeight = mediaQuery?.size.height ??
            (view.physicalSize.height / view.devicePixelRatio);
        final double keyboardHeight = mediaQuery?.viewInsets.bottom ??
            (view.viewInsets.bottom / view.devicePixelRatio);
        final double topPadding = mediaQuery?.padding.top ??
            (view.padding.top / view.devicePixelRatio);

        // Calculate available space with safety margins
        final double spaceBelow =
            (screenHeight - fieldGlobal.dy - size.height - keyboardHeight - 16)
                .clamp(0.0, screenHeight);
        final double spaceAbove =
            (fieldGlobal.dy - topPadding - 16).clamp(0.0, screenHeight);

        // Decide direction: prefer below if space >= 140 or more space below
        final bool showAbove = spaceBelow < 140 && spaceAbove > spaceBelow;

        final double availableHeight = showAbove ? spaceAbove : spaceBelow;
        // Strictly limit maxHeight to at most availableHeight so it can never overflow status bar or keyboard
        final double dynamicMaxHeight = availableHeight.clamp(50.0, 200.0);

        // When opening upward, anchor the follower's bottom to the target's top.
        final Offset offset = showAbove
            ? const Offset(0, -6) // follower-bottom → target-top minus gap
            : Offset(0, size.height + 6);
        final Alignment tAnchor = Alignment.topLeft;
        final Alignment fAnchor =
            showAbove ? Alignment.bottomLeft : Alignment.topLeft;

        return Positioned(
          width: size.width,
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
                        BoxConstraints(maxHeight: dynamicMaxHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: _filteredItems.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Text(
                                    'No results found',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.grey.shade500,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    if (notification
                                        is ScrollStartNotification) {
                                      _isScrolling = true;
                                    } else if (notification
                                        is ScrollEndNotification) {
                                      // Small delay before clearing so tap-up at end
                                      // of scroll doesn't accidentally select.
                                      Future.delayed(
                                        const Duration(milliseconds: 150),
                                        () => _isScrolling = false,
                                      );
                                    }
                                    return false;
                                  },
                                  child: Listener(
                                    // Intercept pointer scroll signals (trackpad / mouse wheel)
                                    // so they reach the ScrollController even when the
                                    // TextField inside the field holds focus.
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
                                                // Guard: don't select during/after scroll.
                                                if (_isScrolling) return;
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
    _isScrolling = false;
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
              validator: widget.validator,
              builder: (field) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TapRegion(
                      groupId: _groupId,
                      onTapOutside: (_) {
                        _hideDropdown();
                        _searchFocusNode.unfocus();
                        _mainFocusNode.unfocus();
                      },
                      child: Container(
                        width: double.infinity,
                        height: widget.height,
                        clipBehavior: Clip.none,
                        decoration: BoxDecoration(
                          color: widget.isEnabled
                              ? (widget.fillColor ?? Colors.white)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            width: field.hasError
                                ? 1.5
                                : _searchFocusNode.hasFocus
                                    ? (widget.focusedBorderWidth ?? 1.6)
                                    : (widget.borderWidth ?? 1.2),
                            color: field.hasError
                                ? Colors.red
                                : _searchFocusNode.hasFocus
                                    ? (widget.focusedBorderColor ??
                                        const Color(0xFF302861))
                                    : widget.isEnabled
                                        ? (widget.borderColor ??
                                            const Color(0xFF302861)
                                                .withValues(alpha: 0.15))
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
                                textInputAction: TextInputAction.done,
                                onTapOutside: (_) {},
                                decoration: InputDecoration(
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  hintText: widget.hint ?? '',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.grey.shade400,
                                    fontSize: widget.hintFontSize ?? 13,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: widget.isEnabled
                                      ? Colors.black87
                                      : Colors.grey.shade500,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                onChanged: (val) {
                                  field.didChange(val);
                                  _filterItems(val);
                                  if (_overlayEntry == null) {
                                    _showDropdown(field);
                                  }
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
                                      ? Icons.arrow_drop_up
                                      : Icons.arrow_drop_down,
                                  size: 20,
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
