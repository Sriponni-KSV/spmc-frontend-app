import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../utils/app_theme.dart';
import '../controllers/ipd_controller.dart';

class IpdBedsCatalogView extends StatefulWidget {
  final bool isMobile;

  const IpdBedsCatalogView({
    Key? key,
    this.isMobile = false,
  }) : super(key: key);

  @override
  State<IpdBedsCatalogView> createState() => _IpdBedsCatalogViewState();
}

class _IpdBedsCatalogViewState extends State<IpdBedsCatalogView> {
  final IpdController _ipdController = IpdController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _beds = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedWardFilter = 'All';
  String _selectedStatusFilter = 'All';
  int _currentPage = 0;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadBeds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBeds() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bedsList = await _ipdController.fetchBeds();
      if (mounted) {
        setState(() {
          _beds = bedsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ─── Filtered Data ─────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredBeds {
    return _beds.where((bed) {
      final bedNum = (bed['bed_number'] ?? '').toString().toLowerCase();
      final ward = (bed['ward_type'] ?? '').toString().toLowerCase();
      final status = (bed['status'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase().trim();

      final matchesQuery = q.isEmpty || bedNum.contains(q) || ward.contains(q);
      final matchesWard = _selectedWardFilter == 'All' ||
          ward == _selectedWardFilter.toLowerCase();
      final matchesStatus = _selectedStatusFilter == 'All' ||
          status == _selectedStatusFilter.toLowerCase();

      return matchesQuery && matchesWard && matchesStatus;
    }).toList();
  }

  List<String> get _availableWards {
    final Set<String> wards = {'General', 'Semi-Private', 'Private', 'ICU'};
    for (final b in _beds) {
      final w = (b['ward_type'] ?? '').toString();
      if (w.isNotEmpty) wards.add(w);
    }
    return wards.toList();
  }

  // ─── Add Bed Dialog ────────────────────────────────────────────────────────

  void _showAddBedDialog() {
    final formKey = GlobalKey<FormState>();
    final bedNumController = TextEditingController();
    String selectedWard = 'General';
    String selectedStatus = 'Available';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.hotel_outlined,
                            color: AppTheme.primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Add New IPD Bed',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 18),

                    // Bed Number Field
                    _buildLabel('Bed Number *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: bedNumController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      decoration: InputDecoration(
                        hintText: 'e.g. G-109, SP-205, ICU-406',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.dangerColor),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Bed number is required';
                        }
                        if (val.trim().length < 2) {
                          return 'Minimum 2 characters required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Ward Category Dropdown
                    _buildLabel('Ward Category *'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedWard,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _availableWards.map((w) {
                        return DropdownMenuItem<String>(
                          value: w,
                          child: Text(w),
                        );
                      }).toList(),
                      onChanged: isSaving
                          ? null
                          : (val) {
                              if (val != null) {
                                setDialogState(() => selectedWard = val);
                              }
                            },
                    ),
                    const SizedBox(height: 16),

                    // Initial Status Dropdown
                    _buildLabel('Initial Status *'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Available',
                          child: Text('Available (Ready for admission)'),
                        ),
                        DropdownMenuItem(
                          value: 'Maintenance',
                          child: Text('Under Maintenance'),
                        ),
                        DropdownMenuItem(
                          value: 'Cleaning',
                          child: Text('Cleaning / Sanitizing'),
                        ),
                      ],
                      onChanged: isSaving
                          ? null
                          : (val) {
                              if (val != null) {
                                setDialogState(() => selectedStatus = val);
                              }
                            },
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                          style: AppTheme.cancelButton,
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setDialogState(() => isSaving = true);
                                  try {
                                    await _ipdController.createBed(
                                      bedNumber: bedNumController.text.trim().toUpperCase(),
                                      wardType: selectedWard,
                                      status: selectedStatus,
                                    );
                                    if (mounted) {
                                      Navigator.pop(dialogCtx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Bed ${bedNumController.text.trim().toUpperCase()} added successfully',
                                          ),
                                          backgroundColor: AppTheme.secondaryColor,
                                        ),
                                      );
                                      _loadBeds();
                                    }
                                  } catch (e) {
                                    setDialogState(() => isSaving = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString()),
                                          backgroundColor: AppTheme.dangerColor,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: AppTheme.primaryButton,
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save Bed'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Edit Bed Dialog ───────────────────────────────────────────────────────

  void _showEditBedDialog(Map<String, dynamic> bed) {
    final formKey = GlobalKey<FormState>();
    final bedNumController =
        TextEditingController(text: bed['bed_number']?.toString() ?? '');
    String selectedWard = (bed['ward_type']?.toString() ?? 'General');
    if (!_availableWards.contains(selectedWard)) {
      selectedWard = 'General';
    }
    String selectedStatus = (bed['status']?.toString() ?? 'Available');
    final bool isCurrentlyOccupied = selectedStatus == 'Occupied';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: AppTheme.primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Edit Bed: ${bed['bed_number']}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 18),

                    if (isCurrentlyOccupied) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFB45309), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This bed is currently occupied by an admitted patient. Changing its status directly to Available is restricted until the patient is discharged.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF92400E),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Bed Number Field
                    _buildLabel('Bed Number *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: bedNumController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.dangerColor),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Bed number is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Ward Category Dropdown
                    _buildLabel('Ward Category *'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedWard,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _availableWards.map((w) {
                        return DropdownMenuItem<String>(
                          value: w,
                          child: Text(w),
                        );
                      }).toList(),
                      onChanged: isSaving
                          ? null
                          : (val) {
                              if (val != null) {
                                setDialogState(() => selectedWard = val);
                              }
                            },
                    ),
                    const SizedBox(height: 16),

                    // Status Dropdown
                    _buildLabel('Status *'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'Available',
                          child: Text('Available'),
                        ),
                        const DropdownMenuItem(
                          value: 'Occupied',
                          child: Text('Occupied'),
                        ),
                        const DropdownMenuItem(
                          value: 'Maintenance',
                          child: Text('Maintenance'),
                        ),
                        const DropdownMenuItem(
                          value: 'Cleaning',
                          child: Text('Cleaning'),
                        ),
                      ],
                      onChanged: isSaving || isCurrentlyOccupied
                          ? null
                          : (val) {
                              if (val != null) {
                                setDialogState(() => selectedStatus = val);
                              }
                            },
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                          style: AppTheme.cancelButton,
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setDialogState(() => isSaving = true);
                                  try {
                                    final bedId = bed['id'] as int;
                                    await _ipdController.updateBed(
                                      id: bedId,
                                      bedNumber: bedNumController.text.trim().toUpperCase(),
                                      wardType: selectedWard,
                                      status: selectedStatus,
                                    );
                                    if (mounted) {
                                      Navigator.pop(dialogCtx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Bed ${bedNumController.text.trim().toUpperCase()} updated successfully',
                                          ),
                                          backgroundColor: AppTheme.secondaryColor,
                                        ),
                                      );
                                      _loadBeds();
                                    }
                                  } catch (e) {
                                    setDialogState(() => isSaving = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString()),
                                          backgroundColor: AppTheme.dangerColor,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: AppTheme.primaryButton,
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Update Bed'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Delete Bed Dialog ─────────────────────────────────────────────────────

  void _showDeleteBedConfirmation(Map<String, dynamic> bed) {
    final bool isOccupied = bed['status'] == 'Occupied';
    final bedNumber = bed['bed_number']?.toString() ?? '';
    final bedId = bed['id'] as int?;
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.dangerColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isOccupied ? 'Cannot Delete Bed' : 'Delete Bed Confirmation',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isOccupied)
                  Text(
                    'Bed "$bedNumber" is currently occupied by an admitted patient.\n\nPlease discharge or transfer the patient before attempting to delete this bed from the catalog.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimaryColor,
                      height: 1.4,
                    ),
                  )
                else
                  Text(
                    'Are you sure you want to permanently delete bed "$bedNumber" from the Master Catalog?\n\nThis will remove it from future admissions.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimaryColor,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                style: AppTheme.cancelButton,
                child: Text(isOccupied ? 'Close' : 'Cancel'),
              ),
              if (!isOccupied && bedId != null)
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          try {
                            await _ipdController.deleteBed(bedId);
                            if (mounted) {
                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Bed "$bedNumber" deleted successfully'),
                                  backgroundColor: AppTheme.secondaryColor,
                                ),
                              );
                              _loadBeds();
                            }
                          } catch (e) {
                            setDialogState(() => isDeleting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: AppTheme.dangerColor,
                                ),
                              );
                            }
                          }
                        },
                  style: AppTheme.dangerButton,
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Delete Bed'),
                ),
            ],
          );
        },
      ),
    );
  }

  // ─── Main UI Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBeds;
    final totalItems = filtered.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();

    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
    if (_currentPage < 0) _currentPage = 0;

    final paginatedItems = filtered
        .skip(_currentPage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          _buildHeaderBar(),
          const SizedBox(height: 20),

          // KPI Stats Row
          _buildKpiStatsRow(),
          const SizedBox(height: 20),

          // Filter Controls
          _buildFilterControls(),
          const SizedBox(height: 16),

          // Bed List / Table Card
          _buildBedsTableCard(paginatedItems, totalItems, totalPages),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: widget.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderTitle(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildSearchBar()),
                    const SizedBox(width: 8),
                    _buildAddButton(),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                _buildHeaderTitle(),
                const Spacer(),
                SizedBox(width: 320, child: _buildSearchBar()),
                const SizedBox(width: 12),
                _buildAddButton(),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Refresh Beds',
                  icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                  onPressed: _loadBeds,
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.hotel_outlined,
            color: AppTheme.primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IPD Beds Master Catalog',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Configure hospital beds, wards, and admission availability',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (val) {
        setState(() {
          _searchQuery = val;
          _currentPage = 0;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search bed number or ward...',
        prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondaryColor),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _currentPage = 0;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton.icon(
      onPressed: _showAddBedDialog,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add Bed'),
      style: AppTheme.primaryButton,
    );
  }

  // ─── KPI Stats Row ─────────────────────────────────────────────────────────

  Widget _buildKpiStatsRow() {
    final total = _beds.length;
    final available = _beds.where((b) => b['status'] == 'Available').length;
    final occupied = _beds.where((b) => b['status'] == 'Occupied').length;
    final maintenance = _beds.where((b) => b['status'] != 'Available' && b['status'] != 'Occupied').length;

    if (widget.isMobile) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = math.max(0.0, (constraints.maxWidth - 12) / 2);
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: cardWidth,
                child: _buildKpiCard('Total Beds', '$total', Icons.hotel_outlined, AppTheme.primaryColor),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildKpiCard('Available', '$available', Icons.check_circle_outline, AppTheme.secondaryColor),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildKpiCard('Occupied', '$occupied', Icons.personal_injury_outlined, AppTheme.logoRed),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildKpiCard('Maintenance', '$maintenance', Icons.build_outlined, AppTheme.warningColor),
              ),
            ],
          );
        },
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildKpiCard('Total Beds', '$total', Icons.hotel_outlined, AppTheme.primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildKpiCard('Available Beds', '$available', Icons.check_circle_outline, AppTheme.secondaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildKpiCard('Occupied Beds', '$occupied', Icons.personal_injury_outlined, AppTheme.logoRed),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildKpiCard('Under Maintenance', '$maintenance', Icons.build_outlined, AppTheme.warningColor),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.6)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondaryColor,
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

  // ─── Filter Controls ───────────────────────────────────────────────────────

  Widget _buildFilterControls() {
    final wards = ['All', ..._availableWards];
    final statuses = ['All', 'Available', 'Occupied', 'Maintenance', 'Cleaning'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: widget.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWardChips(wards),
                const SizedBox(height: 10),
                _buildStatusDropdown(statuses),
              ],
            )
          : Row(
              children: [
                const Text(
                  'Ward Category:',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _buildWardChips(wards)),
                const SizedBox(width: 16),
                _buildStatusDropdown(statuses),
              ],
            ),
    );
  }

  Widget _buildWardChips(List<String> wards) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: wards.map((w) {
          final isSelected = _selectedWardFilter == w;
          final count = w == 'All'
              ? _beds.length
              : _beds.where((b) => b['ward_type'] == w).length;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('$w ($count)'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedWardFilter = w;
                    _currentPage = 0;
                  });
                }
              },
              selectedColor: AppTheme.primaryColor,
              backgroundColor: const Color(0xFFF1F5F9),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusDropdown(List<String> statuses) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatusFilter,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
          items: statuses.map((s) {
            return DropdownMenuItem<String>(
              value: s,
              child: Text('Status: $s'),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedStatusFilter = val;
                _currentPage = 0;
              });
            }
          },
        ),
      ),
    );
  }

  // ─── Beds Table Card ───────────────────────────────────────────────────────

  Widget _buildBedsTableCard(
    List<Map<String, dynamic>> paginatedItems,
    int totalItems,
    int totalPages,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header info
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hospital Beds ($totalItems beds found)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 36, color: AppTheme.dangerColor),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.dangerColor),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadBeds,
                      style: AppTheme.primaryButton,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          else if (_isLoading && _beds.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (paginatedItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.hotel_outlined,
                      size: 48,
                      color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No beds match your filter criteria.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _showAddBedDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Bed'),
                      style: AppTheme.outlinedButton,
                    ),
                  ],
                ),
              ),
            )
          else if (widget.isMobile)
            // Mobile Card View
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paginatedItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final bed = paginatedItems[index];
                return _buildMobileBedCard(bed, index);
              },
            )
          else
            // Desktop Table View
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: AppTheme.textPrimaryColor,
                ),
                dataTextStyle: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimaryColor,
                ),
                columns: const [
                  DataColumn(label: Text('S.No')),
                  DataColumn(label: Text('Bed Number')),
                  DataColumn(label: Text('Ward Category')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Last Updated')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: List.generate(paginatedItems.length, (index) {
                  final bed = paginatedItems[index];
                  final sNo = (_currentPage * _itemsPerPage) + index + 1;
                  final bedNum = (bed['bed_number'] ?? '--').toString();
                  final ward = (bed['ward_type'] ?? '--').toString();
                  final status = (bed['status'] ?? 'Available').toString();
                  final updated = _formatDate(bed['updated_at']?.toString());

                  return DataRow(
                    cells: [
                      DataCell(Text('$sNo')),
                      DataCell(_buildBedBadge(bedNum)),
                      DataCell(_buildWardBadge(ward)),
                      DataCell(_buildStatusBadge(status)),
                      DataCell(Text(updated, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit Bed',
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryColor),
                              onPressed: () => _showEditBedDialog(bed),
                            ),
                            IconButton(
                              tooltip: status == 'Occupied' ? 'Cannot delete occupied bed' : 'Delete Bed',
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: status == 'Occupied'
                                    ? Colors.grey.shade400
                                    : AppTheme.dangerColor,
                              ),
                              onPressed: () => _showDeleteBedConfirmation(bed),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),

          // Pagination Footer
          if (totalPages > 1) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Page ${_currentPage + 1} of $totalPages (${totalItems} total)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _currentPage > 0
                            ? () => setState(() => _currentPage--)
                            : null,
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
        ],
      ),
    );
  }

  Widget _buildMobileBedCard(Map<String, dynamic> bed, int index) {
    final sNo = (_currentPage * _itemsPerPage) + index + 1;
    final bedNum = (bed['bed_number'] ?? '--').toString();
    final ward = (bed['ward_type'] ?? '--').toString();
    final status = (bed['status'] ?? 'Available').toString();
    final updated = _formatDate(bed['updated_at']?.toString());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '#$sNo',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildBedBadge(bedNum),
                ],
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildWardBadge(ward),
              const Spacer(),
              Text(
                'Updated: $updated',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showEditBedDialog(bed),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.borderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showDeleteBedConfirmation(bed),
                icon: const Icon(Icons.delete_outline, size: 15),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: status == 'Occupied' ? Colors.grey : AppTheme.dangerColor,
                  side: BorderSide(
                    color: status == 'Occupied' ? Colors.grey.shade300 : AppTheme.dangerColor.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimaryColor,
      ),
    );
  }

  Widget _buildBedBadge(String bedNum) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        bedNum,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          color: AppTheme.textPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildWardBadge(String ward) {
    Color color;
    switch (ward.toLowerCase()) {
      case 'general':
        color = const Color(0xFF2563EB); // Blue
        break;
      case 'semi-private':
        color = const Color(0xFF7C3AED); // Purple
        break;
      case 'private':
        color = const Color(0xFF059669); // Emerald
        break;
      case 'icu':
        color = const Color(0xFFDC2626); // Red
        break;
      default:
        color = AppTheme.primaryColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        ward,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'available':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        icon = Icons.check_circle_outline;
        break;
      case 'occupied':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        icon = Icons.personal_injury_outlined;
        break;
      case 'maintenance':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        icon = Icons.build_outlined;
        break;
      case 'cleaning':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        icon = Icons.cleaning_services_outlined;
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        icon = Icons.info_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '--';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }
}
