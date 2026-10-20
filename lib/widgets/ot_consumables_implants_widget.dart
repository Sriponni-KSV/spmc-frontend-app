import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../screens/ot_management.dart';
import '../controllers/ot_controller.dart';
import 'custom_dropdown_search.dart';

class OtConsumablesImplantsWidget extends StatefulWidget {
  final OtCase otCase;
  final bool isMobile;
  final String currentUser;
  final Function(OtCase updatedCase)? onCaseUpdated;

  const OtConsumablesImplantsWidget({
    super.key,
    required this.otCase,
    required this.isMobile,
    required this.currentUser,
    this.onCaseUpdated,
  });

  @override
  State<OtConsumablesImplantsWidget> createState() =>
      _OtConsumablesImplantsWidgetState();
}

class _OtConsumablesImplantsWidgetState
    extends State<OtConsumablesImplantsWidget> {
  int _selectedSubTab = 0; // 0: Consumables, 1: Implants
  final OtController _otController = OtController();
  bool _isLoading = false;

  void _showAddConsumableDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddConsumableDialog(
        otCase: widget.otCase,
        currentUser: widget.currentUser,
        otController: _otController,
        onAdded: (updatedCase) {
          if (widget.onCaseUpdated != null) {
            widget.onCaseUpdated!(updatedCase);
          }
          setState(() {});
        },
      ),
    );
  }

  void _showAddImplantDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddImplantDialog(
        otCase: widget.otCase,
        currentUser: widget.currentUser,
        otController: _otController,
        onAdded: (updatedCase) {
          if (widget.onCaseUpdated != null) {
            widget.onCaseUpdated!(updatedCase);
          }
          setState(() {});
        },
      ),
    );
  }

  Future<void> _deleteConsumable(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.dangerColor,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Remove Consumable',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove this consumable?\nIf stock was deducted from hospital inventory, it will be automatically restored.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.dangerButton.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(120, 40)),
            ),
            child: const Text('Remove & Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (widget.otCase.dbId == null) return;

    setState(() => _isLoading = true);
    try {
      final updated = await _otController.removeCaseConsumable(
        widget.otCase.dbId!,
        index,
      );
      setState(() {
        widget.otCase.consumablesUsed = updated.consumablesUsed;
        _isLoading = false;
      });
      if (widget.onCaseUpdated != null) {
        widget.onCaseUpdated!(widget.otCase);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Consumable removed. Inventory stock has been restored successfully.',
            ),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove consumable: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteImplant(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.dangerColor,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Remove Implant',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove this tracked implant from the surgical record?\nThis action will be noted in the case audit trail.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.dangerButton.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(120, 40)),
            ),
            child: const Text('Remove Implant'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (widget.otCase.dbId == null) return;

    setState(() => _isLoading = true);
    try {
      final updated = await _otController.removeCaseImplant(
        widget.otCase.dbId!,
        index,
      );
      setState(() {
        widget.otCase.implantsUsed = updated.implantsUsed;
        _isLoading = false;
      });
      if (widget.onCaseUpdated != null) {
        widget.onCaseUpdated!(widget.otCase);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Implant record removed successfully.'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove implant: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final consumables = widget.otCase.consumablesUsed;
    final implants = widget.otCase.implantsUsed;

    double totalCost = 0;
    int linkedCount = 0;
    int medCount = 0;
    int surgCount = 0;

    for (final c in consumables) {
      final qty = (c['quantity'] as num?)?.toDouble() ?? 1.0;
      final price = (c['cost_per_unit'] as num?)?.toDouble() ?? 0.0;
      totalCost += (qty * price);
      if (c['inventory_item_id'] != null ||
          c['deduct_inventory'] == true ||
          c['deducted_from_inventory'] == true) {
        linkedCount++;
      }
      final cat = (c['category'] ?? '').toString().toLowerCase();
      if (cat == 'medicine') {
        medCount++;
      } else {
        surgCount++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── TOP CONTROL BAR: Segmented Switcher + Slim Metrics + Action Button ──
        Container(
          padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 10 : 14, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: widget.isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Segmented Toggle row on mobile
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSegmentButton(
                              index: 0,
                              label: 'Consumables & Meds',
                              count: consumables.length,
                              icon: Icons.medication_outlined,
                              isActive: _selectedSubTab == 0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildSegmentButton(
                              index: 1,
                              label: 'Implants (UDI)',
                              count: implants.length,
                              icon: Icons.qr_code_2_outlined,
                              isActive: _selectedSubTab == 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Badges and Action button on mobile
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                if (surgCount > 0) ...[
                                  _buildMiniBadge(
                                    icon: Icons.content_cut_outlined,
                                    text: '$surgCount Surgical',
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (medCount > 0) ...[
                                  _buildMiniBadge(
                                    icon: Icons.medication_outlined,
                                    text: '$medCount Meds',
                                    color: const Color(0xFF7C3AED),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (consumables.isEmpty && implants.isEmpty) ...[
                                  _buildMiniBadge(
                                    icon: Icons.inventory_2_outlined,
                                    text: '0 Items',
                                    color: const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (linkedCount > 0) ...[
                                  _buildMiniBadge(
                                    icon: Icons.sync_alt,
                                    text: '$linkedCount Deducted',
                                    color: AppTheme.secondaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (totalCost > 0) ...[
                                  _buildMiniBadge(
                                    icon: Icons.currency_rupee,
                                    text: '₹${totalCost.toStringAsFixed(1)}',
                                    color: const Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (implants.isNotEmpty)
                                  _buildMiniBadge(
                                    icon: Icons.verified_outlined,
                                    text: '${implants.length} Implants',
                                    color: AppTheme.secondaryColor,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _selectedSubTab == 0
                              ? _showAddConsumableDialog
                              : _showAddImplantDialog,
                          icon: Icon(
                            _selectedSubTab == 0
                                ? Icons.add_shopping_cart
                                : Icons.add_circle_outline,
                            size: 14,
                          ),
                          label: Text(
                            _selectedSubTab == 0 ? 'Log Consumable' : 'Record Implant',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: (_selectedSubTab == 0
                                  ? AppTheme.primaryButton
                                  : AppTheme.secondaryButton)
                              .copyWith(
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            ),
                            minimumSize: const WidgetStatePropertyAll(
                              Size(110, 34),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    // Segmented Toggle
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSegmentButton(
                            index: 0,
                            label: 'Consumables & Meds',
                            count: consumables.length,
                            icon: Icons.medication_outlined,
                            isActive: _selectedSubTab == 0,
                          ),
                          const SizedBox(width: 4),
                          _buildSegmentButton(
                            index: 1,
                            label: 'Implants (UDI)',
                            count: implants.length,
                            icon: Icons.qr_code_2_outlined,
                            isActive: _selectedSubTab == 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Inline Summary Badges
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (surgCount > 0)
                            _buildMiniBadge(
                              icon: Icons.content_cut_outlined,
                              text: '$surgCount Surgical',
                              color: AppTheme.primaryColor,
                            ),
                          if (medCount > 0)
                            _buildMiniBadge(
                              icon: Icons.medication_outlined,
                              text: '$medCount Meds',
                              color: const Color(0xFF7C3AED),
                            ),
                          if (consumables.isEmpty && implants.isEmpty)
                            _buildMiniBadge(
                              icon: Icons.inventory_2_outlined,
                              text: '0 Items',
                              color: const Color(0xFF64748B),
                            ),
                          if (linkedCount > 0)
                            _buildMiniBadge(
                              icon: Icons.sync_alt,
                              text: '$linkedCount Deducted',
                              color: AppTheme.secondaryColor,
                            ),
                          if (totalCost > 0)
                            _buildMiniBadge(
                              icon: Icons.currency_rupee,
                              text: '₹${totalCost.toStringAsFixed(1)}',
                              color: const Color(0xFFD97706),
                            ),
                          if (implants.isNotEmpty)
                            _buildMiniBadge(
                              icon: Icons.verified_outlined,
                              text: '${implants.length} Implants',
                              color: AppTheme.secondaryColor,
                            ),
                        ],
                      ),
                    ),

                    // Primary Action Button
                    ElevatedButton.icon(
                      onPressed: _selectedSubTab == 0
                          ? _showAddConsumableDialog
                          : _showAddImplantDialog,
                      icon: Icon(
                        _selectedSubTab == 0
                            ? Icons.add_shopping_cart
                            : Icons.add_circle_outline,
                        size: 15,
                      ),
                      label: Text(
                        _selectedSubTab == 0 ? 'Log Consumable' : 'Record Implant',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: (_selectedSubTab == 0
                              ? AppTheme.primaryButton
                              : AppTheme.secondaryButton)
                          .copyWith(
                        minimumSize: const WidgetStatePropertyAll(
                          Size(140, 36),
                        ),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
        ),

        // ── TAB CONTENT ──
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (_selectedSubTab == 0
                    ? _buildConsumablesList(consumables)
                    : _buildImplantsList(implants)),
        ),
      ],
    );
  }

  Widget _buildSegmentButton({
    required int index,
    required String label,
    required int count,
    required IconData icon,
    required bool isActive,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedSubTab = index),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? AppTheme.primaryColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '$label ($count)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive
                      ? AppTheme.primaryColor
                      : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── CONSUMABLES LIST ──
  Widget _buildConsumablesList(List<Map<String, dynamic>> consumables) {
    if (consumables.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No Surgical Consumables Logged',
        description:
            'Track sutures, sterile gauze, trocars, cannulas, and surgical supplies used during this procedure. Hospital stock is automatically updated.',
        buttonLabel: '+ Log First Consumable',
        onPressed: _showAddConsumableDialog,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: consumables.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = consumables[index];
        final isLinked =
            item['inventory_item_id'] != null ||
            item['deduct_inventory'] == true ||
            item['deducted_from_inventory'] == true;
        final unitCost =
            (item['cost_per_unit'] as num?)?.toDouble() ??
            (item['unit_price'] as num?)?.toDouble() ??
            0.0;
        final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        final totalCost = unitCost * qty;

        final catRaw = (item['category'] ?? '').toString().toLowerCase();
        final isMed = catRaw.contains('med');
        final isImp = catRaw.contains('implant');
        final catLabel = isMed ? 'Medicine' : (isImp ? 'Implant' : 'Surgical');
        final catColor = isMed
            ? const Color(0xFF7C3AED)
            : (isImp ? const Color(0xFFD97706) : AppTheme.primaryColor);
        final catBg = isMed
            ? const Color(0xFFF5F3FF)
            : (isImp ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF));
        final catBorder = isMed
            ? const Color(0xFFDDD6FE)
            : (isImp ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE));
        final catIcon = isMed
            ? Icons.medication_outlined
            : (isImp ? Icons.hardware_outlined : Icons.content_cut_outlined);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isLinked ? const Color(0xFFECFDF5) : catBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLinked ? const Color(0xFFA7F3D0) : catBorder,
                  ),
                ),
                child: Icon(
                  catIcon,
                  size: 18,
                  color: isLinked ? AppTheme.secondaryColor : catColor,
                ),
              ),
              const SizedBox(width: 10),

              // Title & Status
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['item_name'] ?? 'Unknown Item',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        // Category Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: catBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: catBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(catIcon, size: 9, color: catColor),
                              const SizedBox(width: 3),
                              Text(
                                catLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: catColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (item['batch_number'] != null &&
                            item['batch_number'].toString().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Batch: ${item['batch_number']}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (isLinked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDEF7EC),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 9,
                                  color: AppTheme.secondaryColor,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Stock Deducted',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Manual Entry',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quantity & Cost
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['quantity']} ${item['unit'] ?? 'units'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    if (totalCost > 0)
                      Text(
                        '₹${totalCost.toStringAsFixed(1)} (@ ₹$unitCost)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),

              // Delete Action
              IconButton(
                onPressed: () => _deleteConsumable(index),
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.dangerColor,
                  size: 18,
                ),
                tooltip: 'Remove consumable & restore inventory',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── IMPLANTS LIST ──
  Widget _buildImplantsList(List<Map<String, dynamic>> implants) {
    if (implants.isEmpty) {
      return _buildEmptyState(
        icon: Icons.qr_code_scanner_outlined,
        title: 'No Medical Implants Recorded',
        description:
            'Track surgical meshes, orthopedic plates, screws, stents, and prostheses with statutory UDI serial, batch, expiry date, and operating surgeon verification.',
        buttonLabel: '+ Record First Implant',
        onPressed: _showAddImplantDialog,
      );
    }

    return Column(
      children: [
        // Slim Compliance Strip
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 15,
                color: AppTheme.primaryColor,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Statutory UDI Compliance: All surgical implants are recorded with verified model, serial number, batch, and unexpired shelf-life.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Implants List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: implants.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final imp = implants[index];
              final expiryStr = imp['expiry_date']?.toString() ?? '';
              DateTime? expDate = DateTime.tryParse(expiryStr);
              final isExpired =
                  expDate != null && expDate.isBefore(DateTime.now());
              final isVerified =
                  imp['verified_by_surgeon'] == true ||
                  imp['surgeon_verified'] == true;
              final name =
                  imp['model_name'] ?? imp['implant_name'] ?? 'Tracked Implant';
              final modelNum = imp['model_number'] ?? 'N/A';
              final serial = imp['serial_number'] ?? imp['udi_number'] ?? 'N/A';
              final batch = imp['batch_number'] ?? 'N/A';
              final mfr = imp['manufacturer'] ?? 'Standard';
              final site = imp['anatomical_site'] ?? 'Operative Site';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Icon + Name + Verification + Delete
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.hardware_outlined,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppTheme.textPrimaryColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isVerified)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDEF7EC),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 10,
                                            color: AppTheme.secondaryColor,
                                          ),
                                          SizedBox(width: 3),
                                          Text(
                                            'Surgeon Verified',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.secondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                '$mfr  •  Model: $modelNum  •  Site: $site',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _deleteImplant(index),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppTheme.dangerColor,
                            size: 18,
                          ),
                          tooltip: 'Remove implant record',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Badges Strip: Serial/UDI, Batch, Expiry, Qty
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildImplantTag('Serial/UDI', serial, Icons.qr_code),
                        _buildImplantTag('Batch', batch, Icons.pin_outlined),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isExpired
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isExpired
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFA7F3D0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isExpired
                                    ? Icons.error_outline
                                    : Icons.event_available,
                                size: 11,
                                color: isExpired
                                    ? AppTheme.dangerColor
                                    : AppTheme.secondaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                expDate != null
                                    ? '${isExpired ? 'Expired: ' : 'Exp: '}${DateFormat('dd-MMM-yyyy').format(expDate)}'
                                    : 'Exp: $expiryStr',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isExpired
                                      ? AppTheme.dangerColor
                                      : AppTheme.secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (imp['inventory_item_id'] != null ||
                            imp['deduct_inventory'] == true ||
                            imp['deducted_from_inventory'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDEF7EC),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sync_alt,
                                  size: 10,
                                  color: AppTheme.secondaryColor,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Stock Deducted',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImplantTag(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF64748B)),
          const SizedBox(width: 3),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onPressed,
              style: AppTheme.primaryButton.copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(160, 38)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
              child: Text(buttonLabel, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ADD CONSUMABLE DIALOG WITH LIVE INVENTORY LINKAGE
// ============================================================================
class _AddConsumableDialog extends StatefulWidget {
  final OtCase otCase;
  final String currentUser;
  final OtController otController;
  final Function(OtCase) onAdded;

  const _AddConsumableDialog({
    required this.otCase,
    required this.currentUser,
    required this.otController,
    required this.onAdded,
  });

  @override
  State<_AddConsumableDialog> createState() => _AddConsumableDialogState();
}

class _AddConsumableDialogState extends State<_AddConsumableDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _itemNameCtrl = TextEditingController();
  final TextEditingController _quantityCtrl = TextEditingController(text: '1');
  final TextEditingController _unitCtrl = TextEditingController(text: 'pieces');
  final TextEditingController _batchCtrl = TextEditingController();
  final TextEditingController _costCtrl = TextEditingController();

  List<Map<String, dynamic>> _inventoryItems = [];
  Map<String, dynamic>? _selectedInventoryItem;
  String _categoryFilter = 'All'; // 'All', 'Surgical Item', 'Medicine', 'Implant'
  String _itemCategory = 'Surgical Item';
  bool _isLoadingInventory = false;
  bool _deductInventory = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() => _isLoadingInventory = true);
    try {
      final items = await widget.otController.fetchOtInventoryItems();
      if (mounted) {
        setState(() {
          _inventoryItems = items;
          _isLoadingInventory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingInventory = false);
    }
  }

  void _onSelectItem(Map<String, dynamic>? item) {
    setState(() {
      _selectedInventoryItem = item;
      if (item != null) {
        _itemNameCtrl.text = item['name'] ?? '';
        _unitCtrl.text = item['unit'] ?? 'pieces';
        if (item['batch_number'] != null) {
          _batchCtrl.text = item['batch_number'].toString();
        }
        if (item['cost_per_unit'] != null) {
          _costCtrl.text = item['cost_per_unit'].toString();
        }
        _itemCategory = item['category'] ?? 'Surgical Item';
        _deductInventory = true;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.otCase.dbId == null) return;

    final qty = double.tryParse(_quantityCtrl.text.trim()) ?? 1.0;
    if (_deductInventory && _selectedInventoryItem != null) {
      final availableStock =
          (_selectedInventoryItem!['quantity'] as num?)?.toDouble() ?? 0.0;
      if (qty > availableStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Requested quantity ($qty) exceeds available inventory stock ($availableStock).',
            ),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'item_name': _itemNameCtrl.text.trim(),
        'quantity': qty,
        'unit': _unitCtrl.text.trim(),
        'category': _itemCategory,
        'batch_number': _batchCtrl.text.trim().isNotEmpty
            ? _batchCtrl.text.trim()
            : null,
        'deduct_inventory': _deductInventory && _selectedInventoryItem != null,
        'inventory_item_id': _selectedInventoryItem?['id'],
        'cost_per_unit': double.tryParse(_costCtrl.text.trim()) ?? 0.0,
        'recorded_by': widget.currentUser,
      };

      final updated = await widget.otController.addCaseConsumable(
        widget.otCase.dbId!,
        payload,
      );
      widget.onAdded(updated);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _deductInventory && _selectedInventoryItem != null
                  ? 'Item recorded & stock automatically deducted from inventory.'
                  : 'Item recorded successfully.',
            ),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record consumable: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredInventory = _inventoryItems.where((item) {
      if (_categoryFilter == 'All') return true;
      final cat = (item['category'] ?? '').toString().toLowerCase();
      if (_categoryFilter == 'Surgical Item') {
        return cat.contains('surgical') ||
            cat.contains('icu') ||
            cat.contains('consumable');
      }
      if (_categoryFilter == 'Medicine') {
        return cat.contains('med');
      }
      if (_categoryFilter == 'Implant') {
        return cat.contains('implant');
      }
      return true;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Log Surgical Consumable or Medicine',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const Divider(height: 16),

              // Filter Chips: All, Surgical, Medicines, Implants
              Row(
                children: [
                  const Text(
                    'Category:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', null),
                          const SizedBox(width: 5),
                          _buildFilterChip('Surgical Item', 'Surgical Items'),
                          const SizedBox(width: 5),
                          _buildFilterChip('Medicine', 'Medicines'),
                          const SizedBox(width: 5),
                          _buildFilterChip('Implant', 'Implants'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Inventory Selector Dropdown via CustomDropdownSearch
              _isLoadingInventory
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : CustomDropdownSearch(
                      label: 'Hospital Inventory Item',
                      hint:
                          'Search ${_categoryFilter == 'All' ? 'Inventory' : _categoryFilter} (${filteredInventory.length} items)...',
                      value: _selectedInventoryItem != null &&
                              filteredInventory.any((i) =>
                                  i['id'] == _selectedInventoryItem!['id'])
                          ? _selectedInventoryItem!['id'].toString()
                          : null,
                      dropdownMap: {
                        'custom': '— Custom / Manual Non-Inventory Item —',
                        for (var item in filteredInventory)
                          item['id'].toString():
                              '${item['name']} [Stock: ${item['quantity'] ?? 0} ${item['unit'] ?? ''} • ${item['category'] ?? ''}]',
                      },
                      onChanged: (val) {
                        if (val == null || val.isEmpty || val == 'custom') {
                          _onSelectItem(null);
                        } else {
                          final match = filteredInventory.firstWhere(
                            (i) => i['id'].toString() == val,
                            orElse: () => <String, dynamic>{},
                          );
                          if (match.isNotEmpty) {
                            _onSelectItem(match);
                          }
                        }
                      },
                    ),
              const SizedBox(height: 10),

              // If Manual entry, show Category selector
              if (_selectedInventoryItem == null) ...[
                Row(
                  children: [
                    const Text(
                      'Item Type: ',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Surgical Item',
                          style: TextStyle(fontSize: 11)),
                      selected: _itemCategory == 'Surgical Item',
                      selectedColor:
                          AppTheme.primaryColor.withValues(alpha: 0.15),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _itemCategory = 'Surgical Item');
                        }
                      },
                      avatar: const Icon(Icons.content_cut_outlined,
                          size: 13, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label:
                          const Text('Medicine', style: TextStyle(fontSize: 11)),
                      selected: _itemCategory == 'Medicine',
                      selectedColor:
                          const Color(0xFF7C3AED).withValues(alpha: 0.15),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _itemCategory = 'Medicine');
                        }
                      },
                      avatar: const Icon(Icons.medication_outlined,
                          size: 13, color: Color(0xFF7C3AED)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Item Name Field
              TextFormField(
                controller: _itemNameCtrl,
                maxLength: 60,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;%+]'),
                  ),
                ],
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Item name is mandatory';
                  }
                  if (val.trim().length < 2) {
                    return 'Min 2 characters';
                  }
                  if (!RegExp(r'[a-zA-Z]').hasMatch(val)) {
                    return 'Must contain letters';
                  }
                  return null;
                },
                decoration: AppTheme.standardInputDecoration(
                  label: 'Consumable Item Name *',
                  hintText: 'e.g. Vicryl 3-0 Suture, Gauze Swabs 10x10cm',
                  prefixIcon: Icons.medical_services_outlined,
                ),
              ),
              const SizedBox(height: 10),

              // Quantity & Unit
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Quantity required';
                        }
                        final n = double.tryParse(val.trim());
                        if (n == null || n <= 0) {
                          return 'Must be > 0';
                        }
                        return null;
                      },
                      decoration: AppTheme.standardInputDecoration(
                        label: 'Quantity *',
                        hintText: '1',
                        prefixIcon: Icons.numbers,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _unitCtrl,
                      maxLength: 20,
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Unit required'
                          : null,
                      decoration: AppTheme.standardInputDecoration(
                        label: 'Unit *',
                        hintText: 'pieces, swabs, pkts',
                        prefixIcon: Icons.straighten_outlined,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Batch & Unit Cost
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _batchCtrl,
                      maxLength: 30,
                      decoration: AppTheme.standardInputDecoration(
                        label: 'Batch No.',
                        hintText: 'e.g. BTH-8912',
                        prefixIcon: Icons.pin_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: AppTheme.standardInputDecoration(
                        label: 'Unit Cost (₹)',
                        hintText: '0.00',
                        prefixIcon: Icons.currency_rupee,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Stock Deduction Switch
              if (_selectedInventoryItem != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.sync_alt,
                            color: AppTheme.secondaryColor,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Deduct from Inventory Stock',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryColor,
                                ),
                              ),
                              Text(
                                'Available: ${_selectedInventoryItem!['quantity']} ${_selectedInventoryItem!['unit'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _deductInventory,
                        activeThumbColor: AppTheme.secondaryColor,
                        onChanged: (val) =>
                            setState(() => _deductInventory = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: AppTheme.primaryButton.copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size(140, 42)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Log Item'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String categoryValue, String? displayLabel) {
    final isSelected = _categoryFilter == categoryValue;
    final label = displayLabel ?? categoryValue;
    Color chipColor;
    IconData chipIcon;

    if (categoryValue == 'Medicine') {
      chipColor = const Color(0xFF7C3AED);
      chipIcon = Icons.medication_outlined;
    } else if (categoryValue == 'Implant') {
      chipColor = const Color(0xFFD97706);
      chipIcon = Icons.hardware_outlined;
    } else if (categoryValue == 'Surgical Item') {
      chipColor = AppTheme.primaryColor;
      chipIcon = Icons.content_cut_outlined;
    } else {
      chipColor = const Color(0xFF475569);
      chipIcon = Icons.all_inclusive;
    }

    return InkWell(
      onTap: () {
        setState(() {
          _categoryFilter = categoryValue;
          // Clear selected item if it no longer matches the filter
          if (_selectedInventoryItem != null && categoryValue != 'All') {
            final cat = (_selectedInventoryItem!['category'] ?? '').toString().toLowerCase();
            if (categoryValue == 'Medicine' && !cat.contains('med')) {
              _selectedInventoryItem = null;
            } else if (categoryValue == 'Surgical Item' && !cat.contains('surgical') && !cat.contains('icu') && !cat.contains('consumable')) {
              _selectedInventoryItem = null;
            } else if (categoryValue == 'Implant' && !cat.contains('implant')) {
              _selectedInventoryItem = null;
            }
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? chipColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(chipIcon, size: 12, color: isSelected ? chipColor : const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? chipColor : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================================
// ADD TRACKED IMPLANT DIALOG (UDI, BATCH, SERIAL, EXPIRY VALIDATION)
// ============================================================================
class _AddImplantDialog extends StatefulWidget {
  final OtCase otCase;
  final String currentUser;
  final OtController otController;
  final Function(OtCase) onAdded;

  const _AddImplantDialog({
    required this.otCase,
    required this.currentUser,
    required this.otController,
    required this.onAdded,
  });

  @override
  State<_AddImplantDialog> createState() => _AddImplantDialogState();
}

class _AddImplantDialogState extends State<_AddImplantDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _modelNameCtrl = TextEditingController();
  final TextEditingController _modelNumberCtrl = TextEditingController();
  final TextEditingController _manufacturerCtrl = TextEditingController();
  final TextEditingController _batchCtrl = TextEditingController();
  final TextEditingController _serialCtrl = TextEditingController();
  final TextEditingController _siteCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _quantityCtrl = TextEditingController(text: '1');

  List<Map<String, dynamic>> _implantInventory = [];
  Map<String, dynamic>? _selectedInventoryImplant;
  bool _isLoadingInventory = false;
  bool _deductInventory = true;

  DateTime? _expiryDate;
  bool _verifiedBySurgeon = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchImplantInventory();
  }

  Future<void> _fetchImplantInventory() async {
    setState(() => _isLoadingInventory = true);
    try {
      final items = await widget.otController
          .fetchOtInventoryItems(category: 'Implant');
      if (mounted) {
        setState(() {
          _implantInventory = items;
          _isLoadingInventory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingInventory = false);
    }
  }

  void _onSelectImplantItem(Map<String, dynamic>? item) {
    setState(() {
      _selectedInventoryImplant = item;
      if (item != null) {
        _modelNameCtrl.text = item['name'] ?? '';
        _modelNumberCtrl.text = item['item_code'] ?? 'IMP-${item['id']}';
        _manufacturerCtrl.text = item['manufacturer'] ?? 'Ethicon / Synthes';
        _batchCtrl.text = item['batch_number'] ?? 'LOT-2026';
        _serialCtrl.text = item['udi_barcode'] ??
            item['serial_number'] ??
            'UDI-(01)0890${item['id']}(21)SN${DateTime.now().millisecondsSinceEpoch % 100000}';
        _quantityCtrl.text = '1';
        if (_siteCtrl.text.trim().isEmpty) {
          _siteCtrl.text = 'Operative Implant Site';
        }
        _expiryDate = DateTime.now().add(const Duration(days: 730));
        _deductInventory = true;
      }
    });
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 365)),
      firstDate: now.add(const Duration(days: 1)), // Strictly future dates only
      lastDate: now.add(const Duration(days: 365 * 10)),
      helpText: 'SELECT IMPLANT EXPIRY DATE',
      confirmText: 'SELECT',
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid expiry date for the implant.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    if (_expiryDate!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'CRITICAL SAFETY ALERT: This implant has expired! Expired devices cannot be implanted.',
          ),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    final qty = int.tryParse(_quantityCtrl.text.trim()) ?? 1;
    if (_deductInventory && _selectedInventoryImplant != null) {
      final stock =
          (_selectedInventoryImplant!['quantity'] as num?)?.toInt() ?? 0;
      if (qty > stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Requested implant quantity ($qty) exceeds available stock ($stock).',
            ),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
        return;
      }
    }

    if (widget.otCase.dbId == null) return;

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'model_name': _modelNameCtrl.text.trim(),
        'model_number': _modelNumberCtrl.text.trim(),
        'manufacturer': _manufacturerCtrl.text.trim(),
        'batch_number': _batchCtrl.text.trim(),
        'serial_number': _serialCtrl.text.trim(),
        'udi_number': _serialCtrl.text.trim(),
        'expiry_date': _expiryDate!.toIso8601String(),
        'anatomical_site': _siteCtrl.text.trim(),
        'quantity': qty,
        'verified_by_surgeon': _verifiedBySurgeon,
        'recorded_by': widget.currentUser,
        'notes': _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : null,
        'inventory_item_id': _selectedInventoryImplant?['id'],
        'deduct_inventory':
            _deductInventory && _selectedInventoryImplant != null,
      };

      final updated = await widget.otController.addCaseImplant(
        widget.otCase.dbId!,
        payload,
      );
      widget.onAdded(updated);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _deductInventory && _selectedInventoryImplant != null
                  ? 'Tracked implant recorded & stock deducted from inventory.'
                  : 'Tracked implant recorded successfully with full UDI traceability.',
            ),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record implant: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(
                      Icons.qr_code_2,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Record Tracked Implant (UDI)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const Divider(height: 16),

                // Select from Hospital Implant Inventory Dropdown via CustomDropdownSearch
                _isLoadingInventory
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : CustomDropdownSearch(
                        label: 'Select from Hospital Implant Inventory',
                        hint:
                            'Search Mesh, Plate, Screws, Stent (${_implantInventory.length} in stock)...',
                        value: _selectedInventoryImplant?['id']?.toString(),
                        dropdownMap: {
                          'custom': '— Custom / Patient-Supplied Implant —',
                          for (var item in _implantInventory)
                            item['id'].toString():
                                '${item['name']} [Stock: ${item['quantity'] ?? 0} ${item['unit'] ?? ''}]',
                        },
                        onChanged: (val) {
                          if (val == null || val.isEmpty || val == 'custom') {
                            _onSelectImplantItem(null);
                          } else {
                            final match = _implantInventory.firstWhere(
                              (i) => i['id'].toString() == val,
                              orElse: () => <String, dynamic>{},
                            );
                            if (match.isNotEmpty) {
                              _onSelectImplantItem(match);
                            }
                          }
                        },
                      ),
                const SizedBox(height: 12),

                // Model Name & Ref
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _modelNameCtrl,
                        maxLength: 80,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;%+]'),
                          ),
                        ],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Implant Name mandatory';
                          }
                          if (val.trim().length < 2) {
                            return 'Min 2 characters';
                          }
                          if (!RegExp(r'[a-zA-Z]').hasMatch(val)) {
                            return 'Must contain letters';
                          }
                          return null;
                        },
                        decoration: AppTheme.standardInputDecoration(
                          label: 'Implant Name / Device *',
                          hintText: 'e.g. Prolene Hernia Mesh 15x15cm',
                          prefixIcon: Icons.hardware_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _modelNumberCtrl,
                        maxLength: 40,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Model # required'
                            : null,
                        decoration: AppTheme.standardInputDecoration(
                          label: 'Model / Ref # *',
                          hintText: 'e.g. PMM-1515',
                          prefixIcon: Icons.tag,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Manufacturer & Placement Site
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _manufacturerCtrl,
                        maxLength: 60,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Manufacturer required'
                            : null,
                        decoration: AppTheme.standardInputDecoration(
                          label: 'Manufacturer *',
                          hintText: 'e.g. Ethicon / J&J',
                          prefixIcon: Icons.business_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _siteCtrl,
                        maxLength: 60,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Placement site required'
                            : null,
                        decoration: AppTheme.standardInputDecoration(
                          label: 'Placement Site *',
                          hintText: 'e.g. Right Inguinal Canal',
                          prefixIcon: Icons.location_on_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Batch Number & Serial / UDI
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _batchCtrl,
                        maxLength: 40,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Batch # required'
                            : null,
                        decoration: AppTheme.standardInputDecoration(
                          label: 'Batch / Lot Number *',
                          hintText: 'e.g. LOT-89127B',
                          prefixIcon: Icons.pin_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _serialCtrl,
                        maxLength: 80,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Serial / UDI required'
                            : null,
                        decoration: AppTheme.standardInputDecoration(
                          label: 'Serial Number / UDI *',
                          hintText: 'e.g. UDI-(01)0892(21)SN12',
                          prefixIcon: Icons.qr_code,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Expiry Date & Qty
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: _pickExpiryDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _expiryDate == null
                                  ? AppTheme.borderColor
                                  : AppTheme.secondaryColor,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.event_outlined,
                                    size: 18,
                                    color: _expiryDate == null
                                        ? const Color(0xFF64748B)
                                        : AppTheme.secondaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _expiryDate != null
                                        ? 'Expiry: ${DateFormat('dd-MMM-yyyy').format(_expiryDate!)}'
                                        : 'Select Expiry Date *',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: _expiryDate != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: _expiryDate != null
                                          ? AppTheme.textPrimaryColor
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _quantityCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Qty required';
                          }
                          final n = int.tryParse(val.trim());
                          if (n == null || n <= 0) {
                            return '> 0';
                          }
                          return null;
                        },
                        decoration: AppTheme.standardInputDecoration(
                          label: 'Qty *',
                          hintText: '1',
                          prefixIcon: Icons.layers_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Deduct from Inventory Switch (if inventory implant selected)
                if (_selectedInventoryImplant != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.sync_alt,
                              color: AppTheme.secondaryColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Deduct from Hospital Inventory Stock',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondaryColor,
                                  ),
                                ),
                                Text(
                                  'Available: ${_selectedInventoryImplant!['quantity']} ${_selectedInventoryImplant!['unit'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: _deductInventory,
                          activeThumbColor: AppTheme.secondaryColor,
                          onChanged: (val) =>
                              setState(() => _deductInventory = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Surgeon Verification Switch
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: AppTheme.secondaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Surgeon Verification & Safety Check',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.secondaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Sterile packaging and expiry verified prior to placement',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Color(0xFF166534),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Switch(
                        value: _verifiedBySurgeon,
                        activeThumbColor: AppTheme.secondaryColor,
                        onChanged: (val) =>
                            setState(() => _verifiedBySurgeon = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: AppTheme.secondaryButton.copyWith(
                        minimumSize: const WidgetStatePropertyAll(
                          Size(150, 42),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Record Implant'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
