import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../controllers/department_controller.dart';
import '../models/department_model.dart';

class DepartmentDropdown extends StatefulWidget {
  final int? selectedId;
  final String? selectedName;
  final ValueChanged<DepartmentModel?>? onChanged;
  final ValueChanged<int?>? onIdChanged;
  final ValueChanged<String?>? onNameChanged;
  final String? hintText;
  final String? labelText;
  final bool includeAllOption;
  final String allOptionLabel;
  final bool isDense;
  final FormFieldValidator<dynamic>? validator;
  final bool enabled;
  final bool showCodeBadge;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;

  const DepartmentDropdown({
    super.key,
    this.selectedId,
    this.selectedName,
    this.onChanged,
    this.onIdChanged,
    this.onNameChanged,
    this.hintText = 'Select Department',
    this.labelText,
    this.includeAllOption = false,
    this.allOptionLabel = 'All Departments',
    this.isDense = true,
    this.validator,
    this.enabled = true,
    this.showCodeBadge = true,
    this.fillColor,
    this.contentPadding,
  });

  @override
  State<DepartmentDropdown> createState() => _DepartmentDropdownState();
}

class _DepartmentDropdownState extends State<DepartmentDropdown> {
  final DepartmentController _controller = DepartmentController();

  @override
  void initState() {
    super.initState();
    if (_controller.departments.isEmpty) {
      _controller.fetchDepartments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final list = _controller.activeDepartments;

        // Determine current selected value
        int? matchedId = widget.selectedId;
        if (matchedId == null && widget.selectedName != null && widget.selectedName!.isNotEmpty) {
          if (widget.includeAllOption &&
              (widget.selectedName == 'All' || widget.selectedName == widget.allOptionLabel)) {
            matchedId = -1;
          } else {
            final match = _controller.findByName(widget.selectedName);
            if (match != null) matchedId = match.id;
          }
        }

        // If includeAllOption is set and nothing matched or value is -1
        if (widget.includeAllOption && matchedId == null) {
          matchedId = -1;
        }

        // Validate that matchedId exists in items
        final bool idExists = matchedId == -1 || list.any((d) => d.id == matchedId);
        final int? effectiveValue = idExists ? matchedId : null;

        return DropdownButtonFormField<int>(
          value: effectiveValue,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
            filled: true,
            fillColor: widget.fillColor ?? Colors.white,
            isDense: widget.isDense,
            contentPadding: widget.contentPadding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
          ),
          icon: _controller.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
          items: [
            if (widget.includeAllOption)
              DropdownMenuItem<int>(
                value: -1,
                child: Text(
                  widget.allOptionLabel,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                ),
              ),
            ...list.map((dept) {
              return DropdownMenuItem<int>(
                value: dept.id,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dept.name,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.showCodeBadge && dept.code.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          dept.code,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
          onChanged: !widget.enabled
              ? null
              : (val) {
                  if (val == -1) {
                    widget.onIdChanged?.call(null);
                    widget.onNameChanged?.call(widget.allOptionLabel);
                    widget.onChanged?.call(null);
                  } else {
                    final dept = _controller.findById(val);
                    widget.onIdChanged?.call(val);
                    widget.onNameChanged?.call(dept?.name);
                    widget.onChanged?.call(dept);
                  }
                },
          validator: widget.validator != null
              ? (val) => widget.validator!(val == -1 ? null : val)
              : null,
        );
      },
    );
  }
}

class DepartmentBadge extends StatelessWidget {
  final String name;
  final String? code;
  final Color? color;
  final double fontSize;

  const DepartmentBadge({
    super.key,
    required this.name,
    this.code,
    this.color,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apartment_rounded, size: fontSize + 1, color: effectiveColor),
          const SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: effectiveColor,
            ),
          ),
          if (code != null && code!.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              '($code)',
              style: TextStyle(
                fontSize: fontSize - 1,
                color: effectiveColor.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

