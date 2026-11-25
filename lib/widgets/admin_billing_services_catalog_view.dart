import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../config/api_config.dart';
import '../services/token_service.dart';

class AdminBillingServicesCatalogView extends StatefulWidget {
  final bool isMobile;

  const AdminBillingServicesCatalogView({super.key, this.isMobile = false});

  @override
  State<AdminBillingServicesCatalogView> createState() =>
      _AdminBillingServicesCatalogViewState();
}

class _AdminBillingServicesCatalogViewState
    extends State<AdminBillingServicesCatalogView> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _services = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';
  int _currentPage = 0;
  final int _itemsPerPage = 12;

  final List<String> _categories = [
    'All',
    'OP',
    'IP',
    'OT',
    'General',
    'Lab',
    'Pharmacy',
  ];

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token ?? await TokenService.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/billing/services');
      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && data['data'] is List) {
          setState(() {
            _services = List<Map<String, dynamic>>.from(data['data']);
            _isLoading = false;
          });
          return;
        }
      }
      throw Exception('Failed to load billing services (${res.statusCode})');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredServices {
    return _services.where((s) {
      final cat = (s['category'] ?? '').toString();
      if (_selectedCategory != 'All' && cat != _selectedCategory) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (s['name'] ?? '').toString().toLowerCase();
        final desc = (s['description'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !desc.contains(q) && !cat.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _showAddEditServiceDialog([Map<String, dynamic>? item]) async {
    final bool isEdit = item != null;
    final nameCtrl = TextEditingController(text: item?['name']?.toString() ?? '');
    final priceCtrl = TextEditingController(
      text: item != null ? (item['price']?.toString() ?? '0') : '',
    );
    final descCtrl = TextEditingController(text: item?['description']?.toString() ?? '');
    String catVal = item?['category']?.toString() ?? 'OP';
    if (!_categories.contains(catVal) && catVal != 'All') {
      catVal = 'OP';
    }

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    isEdit ? Icons.edit_note : Icons.add_circle_outline,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Edit Billing Service' : 'Add Billing Service',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Service Name *',
                            hintText: 'e.g. Minor Surgical Dressing',
                            prefixIcon: Icon(Icons.receipt_long_outlined),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: catVal,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: _categories
                              .where((c) => c != 'All')
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => catVal = v);
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Price (₹) *',
                            hintText: 'e.g. 500.00',
                            prefixIcon: Icon(Icons.currency_rupee),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Price is required';
                            final parsed = double.tryParse(v.trim());
                            if (parsed == null || parsed < 0) return 'Enter a valid amount';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: descCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description / Remarks',
                            hintText: 'Optional service details or clinical scope',
                            prefixIcon: Icon(Icons.description_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(isEdit ? 'Update' : 'Create'),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);
                    await _saveService(
                      id: item?['id'],
                      name: nameCtrl.text.trim(),
                      category: catVal,
                      price: double.parse(priceCtrl.text.trim()),
                      description: descCtrl.text.trim(),
                      isEdit: isEdit,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveService({
    int? id,
    required String name,
    required String category,
    required double price,
    required String description,
    required bool isEdit,
  }) async {
    setState(() => _isLoading = true);
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token ?? await TokenService.getToken();
      final uri = isEdit
          ? Uri.parse('${ApiEndpoints.baseUrl}/billing/services/$id')
          : Uri.parse('${ApiEndpoints.baseUrl}/billing/services');

      final body = json.encode({
        'name': name,
        'category': category,
        'price': price,
        'description': description,
      });

      final res = isEdit
          ? await http.put(
              uri,
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
              body: body,
            )
          : await http.post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
              body: body,
            );

      final data = json.decode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300 && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEdit ? 'Service updated successfully!' : 'Service created!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _fetchServices();
      } else {
        throw Exception(data['message'] ?? 'Failed to save service');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteService(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Confirm Delete'),
          ],
        ),
        content: Text('Are you sure you want to delete billing service "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token ?? await TokenService.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/billing/services/$id');
      final res = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Billing service deleted!'), backgroundColor: Colors.green),
          );
        }
        await _fetchServices();
      } else {
        throw Exception(data['message'] ?? 'Failed to delete service');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredServices;
    final totalItems = filtered.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
    if (_currentPage < 0) _currentPage = 0;

    final paginated = filtered.skip(_currentPage * _itemsPerPage).take(_itemsPerPage).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Controls
        Container(
          padding: EdgeInsets.fromLTRB(
            widget.isMobile ? 16 : 24,
            widget.isMobile ? 16 : 20,
            widget.isMobile ? 16 : 24,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.payments_outlined, color: AppTheme.primaryColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Billing & Services Master',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: $totalItems configured billing services across hospital departments',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Service'),
                    onPressed: () => _showAddEditServiceDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search & Category Filters
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() {
                          _searchQuery = val;
                          _currentPage = 0;
                        }),
                        decoration: const InputDecoration(
                          hintText: 'Search service name, category, or description...',
                          hintStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                          prefixIcon: Icon(Icons.search, size: 20, color: AppTheme.textSecondaryColor),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                    tooltip: 'Refresh',
                    onPressed: _fetchServices,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) setState(() {
                            _selectedCategory = cat;
                            _currentPage = 0;
                          });
                        },
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : AppTheme.textPrimaryColor,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSel ? AppTheme.primaryColor : AppTheme.borderColor,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Main Table Area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _fetchServices, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(
                            child: Text('No billing services found matching your filters.',
                                style: TextStyle(color: AppTheme.textSecondaryColor)),
                          )
                        : _buildTable(paginated, totalPages, totalItems),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> items, int totalPages, int totalItems) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            // Standardized Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: AppTheme.tableHeaderDecoration(context),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: AppTheme.tableHeaderCell(
                      context: context,
                      label: 'S.No',
                      flex: 0,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: AppTheme.tableHeaderCell(
                      context: context,
                      label: 'Service Name',
                      flex: 0,
                      padding: const EdgeInsets.only(right: 8),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: AppTheme.tableHeaderCell(
                      context: context,
                      label: 'Category',
                      flex: 0,
                      textAlign: TextAlign.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: AppTheme.tableHeaderCell(
                      context: context,
                      label: 'Price (₹)',
                      flex: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: AppTheme.tableHeaderCell(
                      context: context,
                      label: 'Description',
                      flex: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: AppTheme.tableHeaderCell(
                      context: context,
                      label: 'Actions',
                      flex: 0,
                      textAlign: TextAlign.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderColor),

            // Rows
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderColor),
                itemBuilder: (ctx, idx) {
                  final item = items[idx];
                  final sNo = (_currentPage * _itemsPerPage) + idx + 1;
                  final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                  final category = item['category']?.toString() ?? 'General';

                  Color badgeColor = Colors.blueGrey;
                  if (category == 'OP') badgeColor = Colors.blue;
                  if (category == 'IP') badgeColor = Colors.teal;
                  if (category == 'OT') badgeColor = Colors.purple;
                  if (category == 'Lab') badgeColor = Colors.orange;
                  if (category == 'Pharmacy') badgeColor = Colors.green;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text(
                            '$sNo',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              item['name']?.toString() ?? '--',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: badgeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '₹${price.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              item['description']?.toString() ?? '--',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 96,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                                tooltip: 'Edit',
                                onPressed: () => _showAddEditServiceDialog(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                tooltip: 'Delete',
                                onPressed: () => _deleteService(
                                  item['id'],
                                  item['name']?.toString() ?? 'Service',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Pagination Footer
            if (totalPages > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.getTableHeadingRowColor(context),
                  border: Border(top: BorderSide(color: AppTheme.getBorderColor(context))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Page ${_currentPage + 1} of $totalPages ($totalItems items)',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _currentPage < totalPages - 1
                              ? () => setState(() => _currentPage++)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
