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
  const InventoryManagementView({super.key, this.isMobile = false});

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

  String get baseUrl => ApiEndpoints.baseUrl;

  @override
  void initState() {
    super.initState();
    _loadInventoryData();
  }

  Future<void> _loadInventoryData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

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

        setState(() {
          _items = isPharmacy ? rawItems.where((i) => i['category'] != 'Food Stock').toList() : rawItems;
          _lowStockItems = isPharmacy ? rawLow.where((i) => i['category'] != 'Food Stock').toList() : rawLow;
          _expiringItems = isPharmacy ? rawExp.where((i) => i['category'] != 'Food Stock').toList() : rawExp;
          _purchaseRequests = isPharmacy ? rawPR.where((i) => i['category'] != 'Food Stock').toList() : rawPR;
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
    // ── 1. Fetch medicine catalog ──────────────────────────────────────────
    List<Map<String, dynamic>> catalog = [];
    try {
      final resp = await ApiService.get('$baseUrl/inventory/medicine-catalog');
      final body = ApiService.decodeJsonResponse(resp);
      if (body['success'] == true) {
        catalog = List<Map<String, dynamic>>.from(body['data'] ?? []);
      }
    } catch (_) {}

    // ── 2. Dialog state ────────────────────────────────────────────────────
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final thresholdCtrl = TextEditingController();
    String category = 'Medicine';
    bool isControlled = false;
    DateTime? expiryDate;


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
                  prefixIcon: Icons.inventory,
                  hintText: 'Enter initial quantity',
                ).copyWith(counterText: ''),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter initial quantity';
                  }
                  final val = int.tryParse(v);
                  if (val == null || val < 0) {
                    return 'Must be >= 0';
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
              MouseRegion(
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
            title: const Text('Add Inventory Item', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: widget.isMobile ? double.infinity : 420,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Supply Category dropdown ───────────────────────────
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
                              unitCtrl.clear();
                              isControlled = false;
                            });
                          }
                        },
                        validator: (v) => v == null || v.isEmpty ? 'Please select supply category' : null,
                      ),

                      const SizedBox(height: 12),
                      // ── Stock Item Name: text field for Food, dropdown for others ──
                      if (category == 'Food Stock') ...[
                        Text(
                          'Stock Item Name *',
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
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]'))],
                          maxLength: 50,
                          decoration: AppTheme.standardInputDecoration(
                            label: null,
                            prefixIcon: Icons.fastfood_outlined,
                            hintText: 'Enter food item name (e.g. Rice, Dal)',
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
                            // Auto-fill category, unit, controlled from catalog
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
                                        final picked = await showDatePicker(
                                          context: dialogCtx,
                                          initialDate: DateTime.now().add(const Duration(days: 365)),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now().add(const Duration(days: 3650)),
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
                                      final picked = await showDatePicker(
                                        context: dialogCtx,
                                        initialDate: DateTime.now().add(const Duration(days: 365)),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 3650)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added successfully!'), backgroundColor: Colors.green),
        );
        _loadInventoryData();
      } else {
        throw Exception(body['message'] ?? 'Failed to add item');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase request fulfilled, stock replenished!'), backgroundColor: Colors.green),
        );
        _loadInventoryData();
      } else {
        throw Exception(body['message'] ?? 'Failed to process request');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fulfillment failed: $e'), backgroundColor: Colors.red),
      );
    }
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
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.inventory, color: Colors.grey, size: 48),
                  SizedBox(height: 16),
                  Text('No inventory items found in this category.', style: TextStyle(color: Colors.grey)),
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
                                      'Min: $thresholdVal • Target: ${(thresholdVal * 2.5).toInt()}',
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
                                      Text(
                                        item['name'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(width: 8),
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
                                            style: TextStyle(color: AppTheme.dangerColor, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
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
                                      const SizedBox(width: 12),
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
                                  'Min Threshold: $thresholdVal • Target: ${(thresholdVal * 2.5).toInt()}',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // System Warnings & Alerts Header
        const Text('System Warnings & Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),

        // Grid of Alert Cards
        Row(
          children: [
            // Card 1: Low Stock count
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: _lowStockItems.isNotEmpty ? AppTheme.dangerBg : AppTheme.successBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _lowStockItems.isNotEmpty ? AppTheme.dangerColor.withValues(alpha: 0.3) : AppTheme.successColor.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _lowStockItems.isNotEmpty ? Icons.report_problem : Icons.check_circle,
                      color: _lowStockItems.isNotEmpty ? AppTheme.dangerColor : AppTheme.successColor,
                      size: 28,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_lowStockItems.length}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _lowStockItems.isNotEmpty ? AppTheme.dangerColor : AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Low Stock Items',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _lowStockItems.isNotEmpty ? AppTheme.dangerColor : AppTheme.successColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Card 2: Expiring Items count
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: _expiringItems.isNotEmpty ? AppTheme.warningBg : AppTheme.infoBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _expiringItems.isNotEmpty ? AppTheme.warningColor.withValues(alpha: 0.3) : AppTheme.infoColor.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _expiringItems.isNotEmpty ? Icons.warning : Icons.date_range,
                      color: _expiringItems.isNotEmpty ? AppTheme.warningColor : AppTheme.infoColor,
                      size: 28,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_expiringItems.length}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _expiringItems.isNotEmpty ? AppTheme.warningColor : AppTheme.infoColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expiring Soon',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _expiringItems.isNotEmpty ? AppTheme.warningColor : AppTheme.infoColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Purchase Requests queue Header
        const Text('Purchase Replenishment Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),

        if (_purchaseRequests.isEmpty)
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
                    'System stock replenishments are fully completed.',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 400,
            child: ListView.builder(
              itemCount: _purchaseRequests.length,
              itemBuilder: (ctx, idx) {
                final req = _purchaseRequests[idx];
                final isPending = req['status'] == 'Pending';

                return Card(
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: widget.isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isPending ? AppTheme.warningBg : AppTheme.successBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.shopping_bag,
                                      color: isPending ? AppTheme.warningColor : AppTheme.successColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          req['item_name'] ?? 'Unknown Item',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Order Qty: ${req['quantity']} • Req: ${req['requested_by']}',
                                          style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (isPending) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _processPurchaseRequest(req['id']),
                                    icon: const Icon(Icons.check, size: 14, color: Colors.white),
                                    label: const Text('Fulfill Request', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successColor,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check, color: AppTheme.successColor, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'COMPLETED',
                                        style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isPending ? AppTheme.warningBg : AppTheme.successBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.shopping_bag,
                                  color: isPending ? AppTheme.warningColor : AppTheme.successColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      req['item_name'] ?? 'Unknown Item',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Order Qty: ${req['quantity']} • Req: ${req['requested_by']}',
                                      style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              if (isPending)
                                ElevatedButton.icon(
                                  onPressed: () => _processPurchaseRequest(req['id']),
                                  icon: const Icon(Icons.check, size: 14, color: Colors.white),
                                  label: const Text('Fulfill', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.successColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check, color: AppTheme.successColor, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'COMPLETED',
                                        style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
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

    final filteredItems = _items.where((i) {
      if (_selectedCategory == 'All') return true;
      return i['category'] == _selectedCategory;
    }).toList();

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
                    const Text(
                      'Inventory Management',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track medical supplies, ICU consumables, surgical inventory, and replenishment queues',
                      style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.logoRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(180, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _addInventoryItem,
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text(
                          'Add Stock Item',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
                          const Text(
                            'Inventory Management',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track medical supplies, ICU consumables, surgical inventory, and replenishment queues',
                            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.logoRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(180, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _addInventoryItem,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text(
                        'Add Stock Item',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
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
