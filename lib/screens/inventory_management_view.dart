import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_dropdown_search.dart';
import '../services/api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/api_config.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';

class InventoryManagementView extends StatefulWidget {
  final bool isMobile;
  final bool isFoodStockOnly;
  const InventoryManagementView({
    super.key,
    this.isMobile = false,
    this.isFoodStockOnly = false,
  });

  @override
  State<InventoryManagementView> createState() => _InventoryManagementViewState();
}

class _InventoryManagementViewState extends State<InventoryManagementView> {
  List<dynamic> _items = [];
  List<dynamic> _purchaseRequests = [];
  List<dynamic> _lowStockItems = [];
  List<dynamic> _expiringItems = [];
  bool _isLoading = true;
  String? _error;
  String _selectedCategory = 'All';
  OverlayEntry? _currentTopBanner;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String get baseUrl => ApiEndpoints.baseUrl;

  @override
  void initState() {
    super.initState();
    if (widget.isFoodStockOnly) {
      _selectedCategory = 'Food Stock';
    }
    _loadInventoryData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _currentTopBanner?.remove();
    _currentTopBanner = null;
    super.dispose();
  }

  void _showTopNotification(String message, {bool isError = true, BuildContext? targetCtx}) {
    if (!mounted) return;
    try {
      _currentTopBanner?.remove();
      _currentTopBanner = null;

      final overlay = (targetCtx != null ? Overlay.maybeOf(targetCtx) : null) ??
                      Overlay.maybeOf(context) ??
                      Overlay.of(context);
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) => Positioned(
          top: MediaQuery.of(ctx).padding.top + 20,
          left: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isError ? Icons.error_outline : Icons.check_circle_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          entry.remove();
                          if (_currentTopBanner == entry) _currentTopBanner = null;
                        },
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(Icons.close, color: Colors.white70, size: 18),
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

      overlay.insert(entry);
      _currentTopBanner = entry;

      Future.delayed(const Duration(seconds: 4), () {
        if (_currentTopBanner == entry) {
          entry.remove();
          _currentTopBanner = null;
        }
      });
    } catch (_) {
      final topMargin = MediaQuery.of(context).size.height - 90;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
          backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: topMargin > 50 ? topMargin : 50,
            left: 24,
            right: 24,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _loadInventoryData({bool isSilent = false}) async {
    if (!mounted) return;
    if (!isSilent && _items.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final responses = await Future.wait([
        ApiService.get('$baseUrl/inventory/items'),
        ApiService.get('$baseUrl/inventory/alerts'),
        ApiService.get('$baseUrl/inventory/purchase-requests'),
      ]);

      final itemsBody = ApiService.decodeJsonResponse(responses[0]);
      final alertsBody = ApiService.decodeJsonResponse(responses[1]);
      final prBody = ApiService.decodeJsonResponse(responses[2]);

      if (mounted) {
        final isPharmacy = Provider.of<AuthProvider>(context, listen: false).user?.role == 'Pharmacy';
        final List<dynamic> rawItems = itemsBody['data'] ?? [];
        final List<dynamic> rawLow = alertsBody['data']?['low_stock'] ?? [];
        final List<dynamic> rawExp = alertsBody['data']?['expiring'] ?? [];
        final List<dynamic> rawPR = prBody['data'] ?? [];

        bool isFoodCategory(dynamic item) {
          final cat = (item['category'] ?? '').toString().trim().toLowerCase();
          return cat == 'food stock' || cat == 'food';
        }

        setState(() {
          if (widget.isFoodStockOnly) {
            _items = rawItems.where(isFoodCategory).toList();
            _lowStockItems = rawLow.where(isFoodCategory).toList();
            _expiringItems = rawExp.where(isFoodCategory).toList();
            _purchaseRequests = rawPR.where(isFoodCategory).toList();
          } else {
            _items = isPharmacy ? rawItems.where((i) => !isFoodCategory(i)).toList() : rawItems;
            _lowStockItems = isPharmacy ? rawLow.where((i) => !isFoodCategory(i)).toList() : rawLow;
            _expiringItems = isPharmacy ? rawExp.where((i) => !isFoodCategory(i)).toList() : rawExp;
            _purchaseRequests = isPharmacy ? rawPR.where((i) => !isFoodCategory(i)).toList() : rawPR;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addInventoryItem() async {
    // ── 1. Fetch medicine catalog if not food only ────────────────────────
    List<Map<String, dynamic>> catalog = [];
    if (!widget.isFoodStockOnly) {
      try {
        final resp = await ApiService.get('$baseUrl/inventory/medicine-catalog');
        final body = ApiService.decodeJsonResponse(resp);
        if (body['success'] == true) {
          catalog = List<Map<String, dynamic>>.from(body['data'] ?? []);
        }
      } catch (_) {}
    }

    // ── 2. Dialog state ────────────────────────────────────────────────────
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: widget.isFoodStockOnly ? 'kg' : '');
    final qtyCtrl = TextEditingController();
    final thresholdCtrl = TextEditingController(text: '10');
    String category = widget.isFoodStockOnly ? 'Food Stock' : 'Medicine';
    bool isControlled = false;
    DateTime? expiryDate;
    String? dialogError;

    final foodUnits = ['kg', 'Kg', 'grams', 'litres', 'ml', 'packets', 'bags', 'boxes', 'tins', 'cans', 'pcs'];

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setD) {
          final selectedCatalogItem = catalog.firstWhere(
            (m) => m['name'] == nameCtrl.text,
            orElse: () => {},
          );
          final bool isCatalogItemControlled = selectedCatalogItem['is_controlled'] == true;
          final bool isFoodCategory = widget.isFoodStockOnly || category == 'Food Stock';

          final Widget qtyField = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Initial Stock Quantity',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                decoration: AppTheme.standardInputDecoration(
                  label: null,
                  prefixIcon: isFoodCategory ? Icons.restaurant : Icons.inventory,
                  hintText: 'Enter initial quantity',
                ).copyWith(counterText: ''),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter initial quantity';
                  }
                  final val = int.tryParse(v);
                  if (val == null || val <= 0) {
                    return 'Initial stock quantity must be greater than zero';
                  }
                  if (val > 1000000) {
                    return 'Quantity cannot exceed 1,000,000';
                  }
                  return null;
                },
              ),
            ],
          );

          final Widget unitField = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Measurement Unit',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              isFoodCategory
                  ? CustomDropdownSearch(
                      label: '',
                      hint: 'Select unit',
                      value: unitCtrl.text.isEmpty ? 'kg' : unitCtrl.text,
                      dropdownItems: foodUnits,
                      onChanged: (val) {
                        if (val != null) setD(() => unitCtrl.text = val);
                      },
                    )
                  : MouseRegion(
                      cursor: SystemMouseCursors.forbidden,
                      child: TextFormField(
                        controller: unitCtrl,
                        readOnly: true,
                        mouseCursor: SystemMouseCursors.forbidden,
                        decoration: AppTheme.standardInputDecoration(
                          label: null,
                          prefixIcon: Icons.square_foot,
                          hintText: 'Auto-filled from item',
                        ).copyWith(counterText: ''),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please select a stock item' : null,
                      ),
                    ),
            ],
          );

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                Icon(
                  isFoodCategory ? Icons.restaurant_menu : Icons.inventory_2_outlined,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.isFoodStockOnly ? 'Add Food Stock Item' : 'Add Inventory Item',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            content: SizedBox(
              width: widget.isMobile ? double.infinity : 420,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dialogError != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF87171)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dialogError!,
                                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setD(() => dialogError = null),
                                child: const Icon(Icons.close, color: Color(0xFFDC2626), size: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // ── Supply Category dropdown (only for general inventory) ──
                      if (!widget.isFoodStockOnly) ...[
                        CustomDropdownSearch(
                          label: 'Supply Category',
                          requiredMark: true,
                          hint: 'Select supply category',
                          value: category,
                          dropdownItems: Provider.of<AuthProvider>(context, listen: false).user?.role == 'Pharmacy'
                              ? const ['Medicine', 'ICU Consumable', 'Surgical Item']
                              : const ['Medicine', 'ICU Consumable', 'Surgical Item', 'Food Stock'],
                          onChanged: (val) {
                            if (val != null) {
                              setD(() {
                                category = val;
                                nameCtrl.clear();
                                unitCtrl.text = val == 'Food Stock' ? 'kg' : '';
                                isControlled = false;
                              });
                            }
                          },
                          validator: (v) => v == null || v.isEmpty ? 'Please select supply category' : null,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Stock Item Name: text field for Food, dropdown for others ──
                      if (isFoodCategory) ...[
                        Text(
                          'Food Item Name *',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            color: Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nameCtrl,
                          keyboardType: TextInputType.text,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/#\-]'))],
                          maxLength: 60,
                          decoration: AppTheme.standardInputDecoration(
                            label: null,
                            prefixIcon: Icons.restaurant,
                            hintText: 'e.g. Rice, Toor Dal, Sunflower Oil, Milk',
                          ).copyWith(counterText: ''),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Please enter food item name'
                                  : null,
                        ),
                      ] else ...[
                        CustomDropdownSearch(
                          label: 'Stock Item Name',
                          requiredMark: true,
                          hint: 'Select medicine / stock item',
                          value: nameCtrl.text.isEmpty ? null : nameCtrl.text,
                          dropdownItems: catalog
                              .where((m) => m['category'] == category)
                              .map((m) => m['name'] as String)
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            nameCtrl.text = val;
                            final match = catalog.firstWhere(
                              (m) => m['name'] == val,
                              orElse: () => {},
                            );
                            if (match.isNotEmpty) {
                              setD(() {
                                category = (match['category'] as String?) ?? 'Medicine';
                                isControlled = (match['is_controlled'] as bool?) ?? false;
                                unitCtrl.text = (match['default_unit'] as String?) ?? '';
                              });
                            } else {
                              setD(() {});
                            }
                          },
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Please select a stock item'
                                  : null,
                        ),
                      ],
                      const SizedBox(height: 12),
                      widget.isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                qtyField,
                                const SizedBox(height: 12),
                                unitField,
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: qtyField),
                                const SizedBox(width: 12),
                                Expanded(child: unitField),
                              ],
                            ),
                      const SizedBox(height: 12),
                      Text(
                        'Low Stock Alert Threshold',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: thresholdCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 6,
                        decoration: AppTheme.standardInputDecoration(
                          label: null,
                          prefixIcon: Icons.notifications_active,
                          hintText: 'Enter low stock alert threshold',
                        ).copyWith(counterText: ''),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter low stock alert threshold';
                          }
                          final val = int.tryParse(v);
                          if (val == null || val < 0) {
                            return 'Must be >= 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: widget.isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_month, color: AppTheme.textSecondaryColor, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          expiryDate == null 
                                              ? 'Expiration Date: Not Set' 
                                              : 'Expiration: ${DateFormat('dd MMM yyyy').format(expiryDate!)}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.primaryColor,
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () async {
                                        final now = DateTime.now();
                                        final today = DateTime(now.year, now.month, now.day);
                                        final picked = await showDatePicker(
                                          context: dialogCtx,
                                          initialDate: today.add(const Duration(days: 365)),
                                          firstDate: today,
                                          lastDate: today.add(const Duration(days: 3650)),
                                        );
                                        if (picked != null) {
                                          setD(() => expiryDate = picked);
                                        }
                                      },
                                      icon: const Icon(Icons.edit_calendar, size: 16),
                                      label: const Text('Select Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_month, color: AppTheme.textSecondaryColor, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        expiryDate == null 
                                            ? 'Expiration Date: Not Set' 
                                            : 'Expiration: ${DateFormat('dd MMM yyyy').format(expiryDate!)}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.primaryColor,
                                    ),
                                    onPressed: () async {
                                      final now = DateTime.now();
                                      final today = DateTime(now.year, now.month, now.day);
                                      final picked = await showDatePicker(
                                        context: dialogCtx,
                                        initialDate: today.add(const Duration(days: 365)),
                                        firstDate: today,
                                        lastDate: today.add(const Duration(days: 3650)),
                                      );
                                      if (picked != null) {
                                        setD(() => expiryDate = picked);
                                      }
                                    },
                                    icon: const Icon(Icons.edit_calendar, size: 16),
                                    label: const Text('Select Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ],
                              ),
                      ),
                      if (isCatalogItemControlled) ...[
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: CheckboxListTile(
                            activeColor: AppTheme.primaryColor,
                            title: const Text(
                              'Controlled Pharmaceutical Substance?',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                            ),
                            subtitle: const Text(
                              'Requires secure logging and validation when dispensing.',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                            ),
                            value: isControlled,
                            onChanged: (val) {
                              if (val != null) setD(() => isControlled = val);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: widget.isMobile
                ? [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4A5568),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.logoRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              minimumSize: const Size(0, 48),
                              elevation: 0,
                            ),
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                final now = DateTime.now();
                                final today = DateTime(now.year, now.month, now.day);
                                if (expiryDate != null && expiryDate!.isBefore(today)) {
                                  const errMsg = 'Expiry date cannot be a past date. Please select a valid future date.';
                                  setD(() => dialogError = errMsg);
                                  _showTopNotification(errMsg, isError: true, targetCtx: dialogCtx);
                                  return;
                                }
                                final enteredName = nameCtrl.text.trim().toLowerCase();
                                final currentCat = category.trim().toLowerCase();
                                final isFood = widget.isFoodStockOnly || category == 'Food Stock';
                                final isDuplicate = _items.any((it) =>
                                    (it['name'] ?? '').toString().trim().toLowerCase() == enteredName &&
                                    (it['category'] ?? '').toString().trim().toLowerCase() == currentCat);
                                if (isDuplicate) {
                                  final errMsg = isFood ? 'A food item with this name already exists.' : 'An item with this name already exists in this category.';
                                  setD(() => dialogError = errMsg);
                                  _showTopNotification(errMsg, isError: true, targetCtx: dialogCtx);
                                  return;
                                }
                                Navigator.pop(ctx, true);
                              }
                            },
                            child: const Text('Save Item', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ]
                : [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4A5568),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size(130, 52),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.logoRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size(130, 52),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          if (expiryDate != null && expiryDate!.isBefore(today)) {
                            const errMsg = 'Expiry date cannot be a past date. Please select a valid future date.';
                            setD(() => dialogError = errMsg);
                            _showTopNotification(errMsg, isError: true, targetCtx: dialogCtx);
                            return;
                          }
                          final enteredName = nameCtrl.text.trim().toLowerCase();
                          final currentCat = category.trim().toLowerCase();
                          final isFood = widget.isFoodStockOnly || category == 'Food Stock';
                          final isDuplicate = _items.any((it) =>
                              (it['name'] ?? '').toString().trim().toLowerCase() == enteredName &&
                              (it['category'] ?? '').toString().trim().toLowerCase() == currentCat);
                          if (isDuplicate) {
                            final errMsg = isFood ? 'A food item with this name already exists.' : 'An item with this name already exists in this category.';
                            setD(() => dialogError = errMsg);
                            _showTopNotification(errMsg, isError: true, targetCtx: dialogCtx);
                            return;
                          }
                          Navigator.pop(ctx, true);
                        }
                      },
                      child: const Text('Save Item', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
          );
        },
      ),
    );

    if (confirm != true) return;

    try {
      final response = await ApiService.post(
        '$baseUrl/inventory/items',
        {
          'name': nameCtrl.text.trim(),
          'category': category,
          'quantity': int.tryParse(qtyCtrl.text) ?? 0,
          'unit': unitCtrl.text.trim(),
          'threshold': int.tryParse(thresholdCtrl.text) ?? 10,
          'expiry_date': expiryDate?.toIso8601String(),
          'is_controlled': isControlled,
        },
      );
      final body = ApiService.decodeJsonResponse(response);
      if (response.statusCode == 201 && body['success'] == true) {
        if (!mounted) return;
        _showTopNotification('Item added successfully!', isError: false);
        _loadInventoryData(isSilent: true);
      } else {
        throw Exception(body['message'] ?? 'Failed to add item');
      }
    } catch (e) {
      if (!mounted) return;
      final cleanMsg = e.toString().replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
      _showTopNotification(cleanMsg, isError: true);
    }
  }

  Future<void> _processPurchaseRequest(int requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: const Text(
          'Approve & Replenish Stock',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const SizedBox(
          width: 440,
          child: Text(
            'Confirm that this purchase order has arrived, and items should be added back into stock.',
            softWrap: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: AppTheme.cancelButton,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: AppTheme.primaryButton,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark Fulfill'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await ApiService.post(
        '$baseUrl/inventory/purchase-requests/$requestId/process',
        {'status': 'Purchased'},
      );
      final body = ApiService.decodeJsonResponse(response);
      if (response.statusCode == 200 && body['success'] == true) {
        if (!mounted) return;
        _showTopNotification('Purchase request fulfilled, stock replenished!', isError: false);
        _loadInventoryData(isSilent: true);
      } else {
        throw Exception(body['message'] ?? 'Failed to process request');
      }
    } catch (e) {
      if (!mounted) return;
      _showTopNotification('Fulfillment failed: $e', isError: true);
    }
  }

  Future<void> _showReplenishmentDialog([Map<String, dynamic>? item]) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: item?['name']?.toString() ?? '');
    final category = item?['category']?.toString() ?? (widget.isFoodStockOnly ? 'Food Stock' : 'Medicine');
    final unit = item?['unit']?.toString() ?? (widget.isFoodStockOnly ? 'kg' : 'pcs');

    // Suggest order qty based on shortfall
    int suggestedQty = 10;
    if (item != null) {
      final int q = item['quantity'] ?? 0;
      final int t = item['threshold'] ?? 10;
      suggestedQty = (t * 2) - q;
      if (suggestedQty <= 0) suggestedQty = t * 2;
      if (suggestedQty < 5) suggestedQty = 10;
    }
    final qtyCtrl = TextEditingController(text: suggestedQty.toString());

    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    final requester = (currentUser?.fullname.isNotEmpty == true) ? currentUser!.fullname : (currentUser?.role ?? 'Admin');
    bool isSubmitting = false;

    // Available items for selection if no specific item was pre-selected
    final availableItems = _items.map((i) => i['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(widget.isFoodStockOnly ? Icons.restaurant_menu : Icons.add_shopping_cart, color: AppTheme.primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item != null ? 'Replenish: ${item['name']}' : 'New Purchase Replenishment Request',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: widget.isMobile ? double.infinity : 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppTheme.dangerColor, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Current Stock: ${item['quantity'] ?? 0} $unit • Min Threshold: ${item['threshold'] ?? 10} $unit',
                                style: const TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Item Name
                    Text(
                      'Item Name *',
                      style: TextStyle(fontFamily: 'Manrope', color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    if (item != null)
                      TextFormField(
                        controller: nameCtrl,
                        readOnly: true,
                        decoration: AppTheme.standardInputDecoration(label: null, prefixIcon: Icons.inventory_2),
                      )
                    else if (availableItems.isNotEmpty)
                      CustomDropdownSearch(
                        label: '',
                        hint: 'Select food item to replenish',
                        value: nameCtrl.text.isEmpty ? null : nameCtrl.text,
                        dropdownItems: availableItems,
                        onChanged: (val) {
                          if (val != null) {
                            setD(() {
                              nameCtrl.text = val;
                              final match = _items.firstWhere((i) => i['name'] == val, orElse: () => {});
                              if (match.isNotEmpty) {
                                final int q = match['quantity'] ?? 0;
                                final int t = match['threshold'] ?? 10;
                                int calc = (t * 2) - q;
                                if (calc <= 0) calc = t * 2;
                                if (calc < 5) calc = 10;
                                qtyCtrl.text = calc.toString();
                              }
                            });
                          }
                        },
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please select or enter item name' : null,
                      )
                    else
                      TextFormField(
                        controller: nameCtrl,
                        decoration: AppTheme.standardInputDecoration(label: null, prefixIcon: Icons.restaurant, hintText: 'e.g. Rice'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Item name is required' : null,
                      ),
                    const SizedBox(height: 14),

                    // Order Quantity
                    Text(
                      'Replenishment Order Quantity ($unit) *',
                      style: TextStyle(fontFamily: 'Manrope', color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: AppTheme.standardInputDecoration(label: null, prefixIcon: Icons.numbers, hintText: 'Enter quantity to order'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Order quantity is required';
                        final val = int.tryParse(v);
                        if (val == null || val <= 0) return 'Must be greater than 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Category info
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Category:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600)),
                          Text(category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Requested By:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600)),
                          Text(requester, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: AppTheme.cancelButton,
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: AppTheme.primaryButton,
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setD(() => isSubmitting = true);
                      try {
                        final resp = await ApiService.post(
                          '$baseUrl/inventory/purchase-requests',
                          {
                            'item_name': nameCtrl.text.trim(),
                            'category': category,
                            'quantity': int.tryParse(qtyCtrl.text.trim()) ?? 10,
                            'requested_by': requester,
                          },
                        );
                        final body = ApiService.decodeJsonResponse(resp);
                        if (resp.statusCode == 201 || resp.statusCode == 200) {
                          if (mounted) {
                            Navigator.pop(ctx, true);
                            _showTopNotification('Replenishment request for "${nameCtrl.text.trim()}" created successfully!', isError: false);
                            _loadInventoryData(isSilent: true);
                          }
                        } else {
                          throw Exception(body['message'] ?? 'Failed to submit request');
                        }
                      } catch (e) {
                        setD(() => isSubmitting = false);
                        if (mounted) {
                          final cleanMsg = e.toString().replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
                          _showTopNotification(cleanMsg, isError: true);
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm & Create Request'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePurchaseRequest(int requestId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Cancel Replenishment Request', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to cancel the replenishment request for "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: AppTheme.cancelButton,
            child: const Text('Back'),
          ),
          ElevatedButton(
            style: AppTheme.dangerButton,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      final resp = await ApiService.delete('$baseUrl/inventory/purchase-requests/$requestId');
      final body = ApiService.decodeJsonResponse(resp);
      if (resp.statusCode == 200 && body['success'] == true) {
        if (!mounted) return;
        _showTopNotification(body['message'] ?? 'Request cancelled', isError: false);
        _loadInventoryData(isSilent: true);
      } else {
        throw Exception(body['message'] ?? 'Failed to cancel request');
      }
    } catch (e) {
      if (!mounted) return;
      final cleanMsg = e.toString().replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
      _showTopNotification(cleanMsg, isError: true);
    }
  }

  Future<void> _editInventoryItem(Map<String, dynamic> item) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: item['name']?.toString() ?? '');
    final unitCtrl = TextEditingController(text: item['unit']?.toString() ?? 'kg');
    final qtyCtrl = TextEditingController(text: (item['quantity'] ?? 0).toString());
    final thresholdCtrl = TextEditingController(text: (item['threshold'] ?? 10).toString());
    DateTime? expiryDate = item['expiry_date'] != null ? DateTime.tryParse(item['expiry_date']) : null;
    bool isSaving = false;
    String? editError;
    final isFood = widget.isFoodStockOnly || item['category'] == 'Food Stock';

    final foodUnits = ['kg', 'Kg', 'grams', 'litres', 'ml', 'packets', 'bags', 'boxes', 'tins', 'cans', 'pcs'];
    if (!foodUnits.contains(unitCtrl.text)) foodUnits.add(unitCtrl.text);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(isFood ? Icons.restaurant : Icons.inventory_2, color: AppTheme.primaryColor),
              const SizedBox(width: 10),
              Text(isFood ? 'Edit Food Stock Item' : 'Edit Inventory Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: widget.isMobile ? double.infinity : 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (editError != null) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF87171)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                editError!,
                                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setD(() => editError = null),
                              child: const Icon(Icons.close, color: Color(0xFFDC2626), size: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Text('Item Name *', style: TextStyle(fontFamily: 'Manrope', color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: AppTheme.standardInputDecoration(label: null, prefixIcon: isFood ? Icons.restaurant : Icons.inventory, hintText: 'Item Name'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Item name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Stock Quantity *', style: TextStyle(fontFamily: 'Manrope', color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                maxLength: 7,
                                decoration: AppTheme.standardInputDecoration(label: null, prefixIcon: Icons.numbers, hintText: '0').copyWith(counterText: ''),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Stock quantity is required';
                                  final val = int.tryParse(v);
                                  if (val == null || val < 0) return 'Please enter a valid stock quantity';
                                  if (val > 1000000) return 'Quantity cannot exceed 1,000,000';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Unit *', style: TextStyle(fontFamily: 'Manrope', color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              isFood
                                  ? CustomDropdownSearch(
                                      label: '',
                                      hint: 'Select unit',
                                      value: unitCtrl.text,
                                      dropdownItems: foodUnits,
                                      onChanged: (val) {
                                        if (val != null) setD(() => unitCtrl.text = val);
                                      },
                                    )
                                  : TextFormField(
                                      controller: unitCtrl,
                                      decoration: AppTheme.standardInputDecoration(label: null, prefixIcon: Icons.square_foot, hintText: 'Unit'),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Low Stock Threshold', style: TextStyle(fontFamily: 'Manrope', color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: thresholdCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: AppTheme.standardInputDecoration(label: null, prefixIcon: Icons.notifications_active, hintText: '10'),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_month, color: AppTheme.textSecondaryColor, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                expiryDate == null ? 'No Expiration Date' : 'Exp: ${DateFormat('dd MMM yyyy').format(expiryDate!)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () async {
                              final now = DateTime.now();
                              final today = DateTime(now.year, now.month, now.day);
                              final validInitialDate = (expiryDate != null && expiryDate!.isAfter(today))
                                  ? expiryDate!
                                  : today.add(const Duration(days: 180));
                              final picked = await showDatePicker(
                                context: dialogCtx,
                                initialDate: validInitialDate,
                                firstDate: today,
                                lastDate: today.add(const Duration(days: 3650)),
                              );
                              if (picked != null) setD(() => expiryDate = picked);
                            },
                            child: const Text('Change', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              style: AppTheme.cancelButton,
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: AppTheme.primaryButton,
              onPressed: isSaving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                if (expiryDate != null && expiryDate!.isBefore(today)) {
                  const errMsg = 'Expiry date cannot be a past date. Please select a valid future date.';
                  setD(() => editError = errMsg);
                  _showTopNotification(errMsg, isError: true, targetCtx: dialogCtx);
                  return;
                }

                final enteredName = nameCtrl.text.trim().toLowerCase();
                final currentId = item['id'];
                final itemCategory = (item['category'] ?? (isFood ? 'Food Stock' : 'Medicine')).toString().trim().toLowerCase();
                final isDuplicate = _items.any((it) =>
                    it['id'] != currentId &&
                    (it['name'] ?? '').toString().trim().toLowerCase() == enteredName &&
                    (it['category'] ?? '').toString().trim().toLowerCase() == itemCategory);
                if (isDuplicate) {
                  final errMsg = isFood ? 'A food item with this name already exists.' : 'An item with this name already exists in this category.';
                  setD(() => editError = errMsg);
                  _showTopNotification(errMsg, isError: true, targetCtx: dialogCtx);
                  return;
                }

                setD(() => isSaving = true);
                try {
                  final resp = await ApiService.put(
                    '$baseUrl/inventory/items/${item['id']}',
                    {
                      'name': nameCtrl.text.trim(),
                      'quantity': int.tryParse(qtyCtrl.text) ?? 0,
                      'unit': unitCtrl.text.trim(),
                      'threshold': int.tryParse(thresholdCtrl.text) ?? 10,
                      'expiry_date': expiryDate?.toIso8601String(),
                    },
                  );
                  final body = ApiService.decodeJsonResponse(resp);
                  if (resp.statusCode == 200 && body['success'] == true) {
                    if (mounted) Navigator.pop(dialogCtx, true);
                  } else {
                    throw Exception(body['message'] ?? 'Failed to update item');
                  }
                } catch (e) {
                  final cleanMsg = e.toString().replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
                  setD(() {
                    isSaving = false;
                    editError = cleanMsg;
                  });
                  if (mounted) {
                    _showTopNotification(cleanMsg, isError: true, targetCtx: dialogCtx);
                  }
                }
              },
              child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _showTopNotification('Item updated successfully', isError: false);
      _loadInventoryData(isSilent: true);
    }
  }

  Future<void> _deleteInventoryItem(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Stock Item', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete "${item['name']}" from inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: AppTheme.cancelButton,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: AppTheme.dangerButton,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      final resp = await ApiService.delete('$baseUrl/inventory/items/${item['id']}');
      final body = ApiService.decodeJsonResponse(resp);
      if (resp.statusCode == 200 && body['success'] == true) {
        if (mounted) {
          _showTopNotification(body['message'] ?? 'Item removed', isError: false);
          _loadInventoryData(isSilent: true);
        }
      } else {
        throw Exception(body['message'] ?? 'Failed to delete item');
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = e.toString().replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
        _showTopNotification(cleanMsg, isError: true);
      }
    }
  }

  Widget _buildFoodStatBadge(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Medicine':
        return Icons.vaccines;
      case 'ICU Consumable':
        return Icons.monitor_heart;
      case 'Surgical Item':
        return Icons.healing;
      case 'Food Stock':
        return Icons.restaurant;
      default:
        return Icons.inventory_2;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Medicine':
        return AppTheme.primaryColor;
      case 'ICU Consumable':
        return Colors.purple;
      case 'Surgical Item':
        return Colors.teal;
      case 'Food Stock':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildLeftColumn(List<dynamic> filteredItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isFoodStockOnly)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _buildFoodStatBadge(Icons.restaurant, AppTheme.primaryColor, 'Total Food Items', '${_items.length}'),
                _buildFoodStatBadge(Icons.warning_amber_rounded, AppTheme.dangerColor, 'Low Stock', '${_lowStockItems.length}'),
                _buildFoodStatBadge(Icons.hourglass_bottom, Colors.orange, 'Expiring Soon', '${_expiringItems.length}'),
              ],
            ),
          )
        else
          // Filter row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: (Provider.of<AuthProvider>(context, listen: false).user?.role == 'Pharmacy'
                      ? const ['All', 'Medicine', 'ICU Consumable', 'Surgical Item']
                      : const ['All', 'Medicine', 'ICU Consumable', 'Surgical Item', 'Food Stock'])
                  .map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textSecondaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // Search bar
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: widget.isFoodStockOnly
                  ? 'Search food items by name, category (e.g. Rice, Milk)...'
                  : 'Search items by name, category, or unit...',
              hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondaryColor),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppTheme.textSecondaryColor),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        // Items custom card list
        if (filteredItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, color: Colors.grey, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No inventory items found matching "$_searchQuery".'
                        : 'No inventory items found in this category.',
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredItems.length,
            itemBuilder: (ctx, idx) {
              final item = filteredItems[idx];
              final isLow = item['quantity'] <= item['threshold'];
              final category = item['category'] ?? 'Medicine';
              final itemColor = _getCategoryColor(category);
              final itemIcon = _getCategoryIcon(category);

              final expDate = item['expiry_date'] != null
                  ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['expiry_date']))
                  : 'No Expiry';

              final int thresholdVal = item['threshold'] ?? 10;
              final int quantityVal = item['quantity'] ?? 0;
              final double progress = (quantityVal / (thresholdVal > 0 ? thresholdVal * 2.5 : 25)).clamp(0.0, 1.0);

              return Card(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isLow ? AppTheme.dangerColor.withValues(alpha: 0.3) : AppTheme.borderColor,
                    width: isLow ? 1.5 : 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: widget.isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: itemColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(itemIcon, color: itemColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            item['name'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          if (item['is_controlled'] == true)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.dangerBg,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.2)),
                                              ),
                                              child: const Text(
                                                'CONTROLLED',
                                                style: TextStyle(color: AppTheme.dangerColor, fontSize: 8, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 12,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              category.toUpperCase(),
                                              style: TextStyle(color: Colors.grey.shade700, fontSize: 9, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.calendar_today, size: 12, color: AppTheme.textSecondaryColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Exp: $expDate',
                                                style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: AppTheme.borderColor),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  textBaseline: TextBaseline.alphabetic,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  children: [
                                    Text(
                                      '$quantityVal',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        color: isLow ? AppTheme.dangerColor : AppTheme.successColor,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item['unit'] ?? 'pcs',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondaryColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Min Threshold: $thresholdVal',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isLow ? 'LOW STOCK' : 'Optimal Stock',
                                      style: TextStyle(
                                        color: isLow ? AppTheme.dangerColor : AppTheme.successColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (isLow) ...[
                                  SizedBox(
                                    height: 30,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.dangerColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        elevation: 0,
                                      ),
                                      onPressed: () => _showReplenishmentDialog(Map<String, dynamic>.from(item)),
                                      icon: const Icon(Icons.add_shopping_cart, size: 13),
                                      label: const Text('Replenish', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryColor),
                                  onPressed: () => _editInventoryItem(Map<String, dynamic>.from(item)),
                                  tooltip: 'Edit Item',
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.dangerColor),
                                  onPressed: () => _deleteInventoryItem(Map<String, dynamic>.from(item)),
                                  tooltip: 'Delete Item',
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            // Category Icon badge
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: itemColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(itemIcon, color: itemColor, size: 24),
                            ),
                            const SizedBox(width: 16),

                            // Middle details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item['name'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (item['is_controlled'] == true) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.dangerBg,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.2)),
                                          ),
                                          child: const Text(
                                            'CONTROLLED',
                                            style: TextStyle(color: AppTheme.dangerColor, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          category.toUpperCase(),
                                          style: TextStyle(color: Colors.grey.shade700, fontSize: 10, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_today, size: 12, color: AppTheme.textSecondaryColor),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Exp: $expDate',
                                            style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Right Side: Stock quantity and progress status
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  textBaseline: TextBaseline.alphabetic,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  children: [
                                    Text(
                                      '$quantityVal',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20,
                                        color: isLow ? AppTheme.dangerColor : AppTheme.successColor,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item['unit'] ?? 'pcs',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Min Threshold: $thresholdVal',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isLow ? 'LOW STOCK' : 'Optimal Stock',
                                  style: TextStyle(
                                    color: isLow ? AppTheme.dangerColor : AppTheme.successColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isLow) ...[
                                  SizedBox(
                                    height: 30,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.dangerColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        elevation: 0,
                                      ),
                                      onPressed: () => _showReplenishmentDialog(Map<String, dynamic>.from(item)),
                                      icon: const Icon(Icons.add_shopping_cart, size: 13),
                                      label: const Text('Replenish', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryColor),
                                  onPressed: () => _editInventoryItem(Map<String, dynamic>.from(item)),
                                  tooltip: 'Edit Item',
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                ),
                                const SizedBox(height: 6),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.dangerColor),
                                  onPressed: () => _deleteInventoryItem(Map<String, dynamic>.from(item)),
                                  tooltip: 'Delete Item',
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRightColumn() {
    final pendingRequests = _purchaseRequests.where((r) => r['status'] == 'Pending').toList();
    final otherRequests = _purchaseRequests.where((r) => r['status'] != 'Pending').toList();
    final displayRequests = [...pendingRequests, ...otherRequests];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Low Stock Items Alert Section
        Row(
          children: [
            const Expanded(
              child: Text(
                'Low Stock Alerts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_lowStockItems.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.dangerBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${_lowStockItems.length} ACTION REQUIRED',
                  style: const TextStyle(color: AppTheme.dangerColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        if (_lowStockItems.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.dangerBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.dangerColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Items below configured minimum stock level',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._lowStockItems.map((item) {
                  final int q = item['quantity'] ?? 0;
                  final int t = item['threshold'] ?? 10;
                  final String u = item['unit'] ?? 'kg';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Available: $q $u • Minimum: $t $u',
                                style: const TextStyle(fontSize: 12, color: AppTheme.dangerColor, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 32,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.dangerColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showReplenishmentDialog(Map<String, dynamic>.from(item)),
                            icon: const Icon(Icons.add_shopping_cart, size: 14),
                            label: const Text('Replenish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.successBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No Low Stock Alerts: All items are at or above configured thresholds.',
                    style: TextStyle(fontSize: 12, color: AppTheme.successColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Expiring Soon Alerts Section
        Row(
          children: [
            const Expanded(
              child: Text(
                'Expiring Soon Alerts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_expiringItems.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${_expiringItems.length} EXPIRING IN 30 DAYS',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        if (_expiringItems.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hourglass_bottom_rounded, color: Colors.orange.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Items approaching expiration date (within 30 days)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._expiringItems.map((item) {
                  final int q = item['quantity'] ?? 0;
                  final String u = item['unit'] ?? 'kg';
                  DateTime? expDate;
                  if (item['expiry_date'] != null) {
                    expDate = DateTime.tryParse(item['expiry_date'].toString());
                  }
                  final expFormatted = expDate != null ? DateFormat('dd MMM yyyy').format(expDate) : 'No Expiry';
                  final now = DateTime.now();
                  final daysLeft = expDate != null
                      ? expDate.difference(DateTime(now.year, now.month, now.day)).inDays
                      : null;

                  String urgencyBadge;
                  Color badgeColor;
                  Color badgeBg;
                  if (daysLeft == null) {
                    urgencyBadge = 'Unknown Date';
                    badgeColor = Colors.grey;
                    badgeBg = Colors.grey.shade100;
                  } else if (daysLeft < 0) {
                    urgencyBadge = 'EXPIRED (${-daysLeft}d ago)';
                    badgeColor = Colors.red.shade700;
                    badgeBg = Colors.red.shade50;
                  } else if (daysLeft == 0) {
                    urgencyBadge = 'EXPIRES TODAY';
                    badgeColor = Colors.red.shade700;
                    badgeBg = Colors.red.shade50;
                  } else if (daysLeft == 1) {
                    urgencyBadge = '1 DAY LEFT';
                    badgeColor = Colors.deepOrange;
                    badgeBg = Colors.orange.shade100;
                  } else {
                    urgencyBadge = '$daysLeft DAYS LEFT';
                    badgeColor = Colors.orange.shade800;
                    badgeBg = Colors.orange.shade100;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item['name'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      urgencyBadge,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Available: $q $u',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '• Expiry: $expFormatted',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: daysLeft != null && daysLeft <= 7 ? Colors.red.shade700 : Colors.orange.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 32,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade800,
                              side: BorderSide(color: Colors.orange.shade300),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _editInventoryItem(Map<String, dynamic>.from(item)),
                            icon: const Icon(Icons.edit_outlined, size: 13),
                            label: const Text('Update', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.successBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No Expiring Items: All inventory items have valid expiration dates.',
                    style: TextStyle(fontSize: 12, color: AppTheme.successColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Purchase Replenishment Requests Section
        Row(
          children: [
            const Expanded(
              child: Text(
                'Purchase Replenishment Requests',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showReplenishmentDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Request', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (displayRequests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.shopping_cart_outlined, color: Colors.grey, size: 36),
                  SizedBox(height: 12),
                  Text(
                    'No Active Purchase Requests',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Stock replenishments are fully completed.',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 420,
            child: ListView.builder(
              itemCount: displayRequests.length,
              itemBuilder: (ctx, idx) {
                final req = displayRequests[idx];
                final isPending = req['status'] == 'Pending';

                return Card(
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isPending ? AppTheme.warningColor.withValues(alpha: 0.3) : AppTheme.borderColor,
                      width: isPending ? 1.4 : 1.0,
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isPending ? AppTheme.warningBg : AppTheme.successBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.shopping_bag,
                                color: isPending ? AppTheme.warningColor : AppTheme.successColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        req['item_name'] ?? 'Unknown Item',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isPending ? AppTheme.warningBg : AppTheme.successBg,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isPending ? AppTheme.warningColor.withValues(alpha: 0.3) : AppTheme.successColor.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          isPending ? 'PENDING' : 'FULFILLED',
                                          style: TextStyle(
                                            color: isPending ? AppTheme.warningColor : AppTheme.successColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Order Qty: ${req['quantity']} • Req: ${req['requested_by'] ?? 'System'}',
                                    style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (isPending) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                height: 32,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                    side: BorderSide(color: Colors.grey.shade300),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _deletePurchaseRequest(req['id'], req['item_name'] ?? 'Item'),
                                  icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                                  label: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 32,
                                child: ElevatedButton.icon(
                                  onPressed: () => _processPurchaseRequest(req['id']),
                                  icon: const Icon(Icons.check, size: 15, color: Colors.white),
                                  label: const Text(
                                    'Fulfill Request',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, color: AppTheme.successColor, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'COMPLETED & RESTOCKED',
                                  style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDashboardSummaryCards() {
    final pendingCount = _purchaseRequests.where((r) => r['status'] == 'Pending').length;
    final totalLabel = widget.isFoodStockOnly ? 'Total Food Items' : 'Total Items';
    final totalSubtitle = widget.isFoodStockOnly ? 'Food & pantry records' : 'Total items tracked';

    final cards = [
      _buildSummaryCard(
        title: totalLabel,
        count: '${_items.length}',
        subtitle: totalSubtitle,
        icon: widget.isFoodStockOnly ? Icons.restaurant_menu : Icons.inventory_2,
        color: AppTheme.primaryColor,
        bgColor: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderColor: AppTheme.primaryColor.withValues(alpha: 0.25),
      ),
      _buildSummaryCard(
        title: 'Low Stock Items',
        count: '${_lowStockItems.length}',
        subtitle: _lowStockItems.isNotEmpty ? '${_lowStockItems.length} below threshold' : 'All stock levels healthy',
        icon: Icons.warning_amber_rounded,
        color: _lowStockItems.isNotEmpty ? AppTheme.dangerColor : AppTheme.successColor,
        bgColor: _lowStockItems.isNotEmpty ? AppTheme.dangerBg : AppTheme.successBg,
        borderColor: _lowStockItems.isNotEmpty ? AppTheme.dangerColor.withValues(alpha: 0.3) : AppTheme.successColor.withValues(alpha: 0.3),
      ),
      _buildSummaryCard(
        title: 'Expiring Soon',
        count: '${_expiringItems.length}',
        subtitle: _expiringItems.isNotEmpty ? '${_expiringItems.length} expiring in 30 days' : 'No items expiring soon',
        icon: Icons.hourglass_bottom_rounded,
        color: _expiringItems.isNotEmpty ? AppTheme.warningColor : AppTheme.infoColor,
        bgColor: _expiringItems.isNotEmpty ? AppTheme.warningBg : AppTheme.infoBg,
        borderColor: _expiringItems.isNotEmpty ? AppTheme.warningColor.withValues(alpha: 0.3) : AppTheme.infoColor.withValues(alpha: 0.3),
      ),
      _buildSummaryCard(
        title: 'Replenishment Requests',
        count: '$pendingCount',
        subtitle: pendingCount > 0 ? '$pendingCount pending fulfillment' : 'All orders fulfilled',
        icon: Icons.shopping_cart_outlined,
        color: Colors.purple.shade700,
        bgColor: Colors.purple.shade50,
        borderColor: Colors.purple.shade200,
      ),
    ];

    if (widget.isMobile) {
      return Column(
        children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList(),
      );
    }

    return Row(
      children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFamily: 'Manrope',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading Inventory: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadInventoryData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final query = _searchQuery.trim().toLowerCase();
    final filteredItems = _items.where((i) {
      if (!widget.isFoodStockOnly && _selectedCategory != 'All') {
        if (i['category'] != _selectedCategory) return false;
      }
      if (query.isNotEmpty) {
        final name = (i['name'] ?? '').toString().toLowerCase();
        final cat = (i['category'] ?? '').toString().toLowerCase();
        final unit = (i['unit'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !cat.contains(query) && !unit.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    final title = widget.isFoodStockOnly ? 'Food Stock Management' : 'Inventory Management';
    final subtitle = widget.isFoodStockOnly
        ? 'Track kitchen groceries, pantry supplies, food stock levels, and dietary replenishment alerts'
        : 'Track medical supplies, ICU consumables, surgical inventory, and replenishment queues';
    final addLabel = widget.isFoodStockOnly ? 'Add Food Stock' : 'Add Stock Item';
    final addIcon = widget.isFoodStockOnly ? Icons.restaurant_outlined : Icons.add;

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          widget.isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isFoodStockOnly ? AppTheme.primaryColor : AppTheme.logoRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(180, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _addInventoryItem,
                        icon: Icon(addIcon, size: 20),
                        label: Text(
                          addLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isFoodStockOnly ? AppTheme.primaryColor : AppTheme.logoRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(180, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _addInventoryItem,
                      icon: Icon(addIcon, size: 20),
                      label: Text(
                        addLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 20),

          // Dashboard Summary Cards Row
          _buildDashboardSummaryCards(),
          const SizedBox(height: 24),

          // Main Section: Left and Right Columns
          widget.isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLeftColumn(filteredItems),
                    const SizedBox(height: 32),
                    _buildRightColumn(),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildLeftColumn(filteredItems),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 4,
                      child: _buildRightColumn(),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}
