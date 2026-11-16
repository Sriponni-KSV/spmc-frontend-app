import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../config/api_config.dart';
import '../services/token_service.dart';

class AdminLabTestsCatalogView extends StatefulWidget {
  final bool isMobile;

  const AdminLabTestsCatalogView({super.key, this.isMobile = false});

  @override
  State<AdminLabTestsCatalogView> createState() => _AdminLabTestsCatalogViewState();
}

class _AdminLabTestsCatalogViewState extends State<AdminLabTestsCatalogView> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _tests = [];
  String _searchQuery = '';
  int _currentPage = 0;
  final int _itemsPerPage = 12;

  @override
  void initState() {
    super.initState();
    _fetchTests();
  }

  Future<void> _fetchTests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token ?? await TokenService.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/lab/test-master');
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
            _tests = List<Map<String, dynamic>>.from(data['data']);
            _isLoading = false;
          });
          return;
        }
      }
      throw Exception('Failed to load lab tests (${res.statusCode})');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTests {
    if (_searchQuery.trim().isEmpty) return _tests;
    final q = _searchQuery.toLowerCase();
    return _tests.where((t) {
      final name = (t['test_name'] ?? '').toString().toLowerCase();
      final desc = (t['description'] ?? '').toString().toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();
  }

  Future<void> _showAddEditTestDialog([Map<String, dynamic>? item]) async {
    final bool isEdit = item != null;
    final nameCtrl = TextEditingController(text: item?['test_name']?.toString() ?? '');
    final tatCtrl = TextEditingController(
      text: item != null ? (item['target_tat_minutes']?.toString() ?? '30') : '30',
    );
    final durationCtrl = TextEditingController(
      text: item != null ? (item['processing_duration_minutes']?.toString() ?? '30') : '30',
    );
    final descCtrl = TextEditingController(text: item?['description']?.toString() ?? '');

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
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
                isEdit ? 'Edit Lab Test' : 'Add Lab Test',
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
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Test Name *',
                        hintText: 'e.g. Complete Blood Count (CBC)',
                        prefixIcon: Icon(Icons.science_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Test name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: tatCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Target TAT (mins) *',
                              hintText: 'e.g. 30',
                              prefixIcon: Icon(Icons.timer_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              final n = int.tryParse(v.trim());
                              if (n == null || n <= 0) return 'Valid minutes';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: durationCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duration (mins) *',
                              hintText: 'e.g. 20',
                              prefixIcon: Icon(Icons.hourglass_bottom_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              final n = int.tryParse(v.trim());
                              if (n == null || n <= 0) return 'Valid minutes';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description / Clinical Notes',
                        hintText: 'e.g. Platelets, Hemoglobin, WBC differential',
                        prefixIcon: Icon(Icons.info_outline),
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
                await _saveTest(
                  id: item?['id'],
                  testName: nameCtrl.text.trim(),
                  targetTatMinutes: int.parse(tatCtrl.text.trim()),
                  processingDurationMinutes: int.parse(durationCtrl.text.trim()),
                  description: descCtrl.text.trim(),
                  isEdit: isEdit,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveTest({
    int? id,
    required String testName,
    required int targetTatMinutes,
    required int processingDurationMinutes,
    required String description,
    required bool isEdit,
  }) async {
    setState(() => _isLoading = true);
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token ?? await TokenService.getToken();
      final uri = isEdit
          ? Uri.parse('${ApiEndpoints.baseUrl}/lab/test-master/$id')
          : Uri.parse('${ApiEndpoints.baseUrl}/lab/test-master');

      final body = json.encode({
        'test_name': testName,
        'target_tat_minutes': targetTatMinutes,
        'processing_duration_minutes': processingDurationMinutes,
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
              content: Text(isEdit ? 'Lab test updated!' : 'Lab test created!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _fetchTests();
      } else {
        throw Exception(data['message'] ?? 'Failed to save lab test');
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

  Future<void> _deleteTest(int id, String testName) async {
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
        content: Text('Are you sure you want to delete lab test "$testName"?'),
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
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/lab/test-master/$id');
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
            const SnackBar(content: Text('Lab test deleted!'), backgroundColor: Colors.green),
          );
        }
        await _fetchTests();
      } else {
        throw Exception(data['message'] ?? 'Failed to delete lab test');
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
    final filtered = _filteredTests;
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
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.biotech_outlined, color: Colors.teal, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Lab Tests Master Catalog',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: $totalItems tests configured for doctor lab orders & technician scheduling',
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
                    label: const Text('Add Lab Test'),
                    onPressed: () => _showAddEditTestDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search Input
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
                          hintText: 'Search test name or description...',
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
                    onPressed: _fetchTests,
                  ),
                ],
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
                            ElevatedButton(onPressed: _fetchTests, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(
                            child: Text('No lab tests found matching your search.',
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
                  AppTheme.tableHeaderCell(
                    context: context,
                    label: '#',
                    icon: Icons.tag,
                    flex: 1,
                  ),
                  AppTheme.tableHeaderCell(
                    context: context,
                    label: 'Test Name',
                    icon: Icons.science_outlined,
                    flex: 4,
                  ),
                  AppTheme.tableHeaderCell(
                    context: context,
                    label: 'Target TAT',
                    icon: Icons.timer_outlined,
                    flex: 2,
                    textAlign: TextAlign.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                  ),
                  AppTheme.tableHeaderCell(
                    context: context,
                    label: 'Processing Time',
                    icon: Icons.hourglass_bottom_outlined,
                    flex: 2,
                    textAlign: TextAlign.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                  ),
                  AppTheme.tableHeaderCell(
                    context: context,
                    label: 'Description',
                    icon: Icons.info_outline,
                    flex: 4,
                  ),
                  AppTheme.tableHeaderCell(
                    context: context,
                    label: 'Actions',
                    icon: Icons.settings_outlined,
                    flex: 2,
                    textAlign: TextAlign.center,
                    mainAxisAlignment: MainAxisAlignment.center,
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
                  final tat = item['target_tat_minutes']?.toString() ?? '30';
                  final dur = item['processing_duration_minutes']?.toString() ?? '30';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text(
                            '$sNo',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            item['test_name']?.toString() ?? '--',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '$tat mins',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '$dur mins',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
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
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                                tooltip: 'Edit',
                                onPressed: () => _showAddEditTestDialog(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                tooltip: 'Delete',
                                onPressed: () => _deleteTest(
                                  item['id'],
                                  item['test_name']?.toString() ?? 'Lab Test',
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
