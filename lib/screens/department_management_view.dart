import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../controllers/department_controller.dart';
import '../models/department_model.dart';

class DepartmentManagementView extends StatefulWidget {
  final bool isMobile;

  const DepartmentManagementView({
    super.key,
    this.isMobile = false,
  });

  @override
  State<DepartmentManagementView> createState() => _DepartmentManagementViewState();
}

class _DepartmentManagementViewState extends State<DepartmentManagementView> {
  final DepartmentController _controller = DepartmentController();
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All'; // 'All', 'Active', 'Inactive'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _controller.fetchDepartments(includeInactive: true, forceRefresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DepartmentModel> _getFilteredDepartments() {
    return _controller.departments.where((d) {
      if (_statusFilter == 'Active' && !d.isActive) return false;
      if (_statusFilter == 'Inactive' && d.isActive) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatches = d.name.toLowerCase().contains(q);
        final codeMatches = d.code.toLowerCase().contains(q);
        final descMatches = (d.description ?? '').toLowerCase().contains(q);
        if (!nameMatches && !codeMatches && !descMatches) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isNarrow = widget.isMobile || MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final allDepts = _controller.departments;
          final activeCount = allDepts.where((d) => d.isActive).length;
          final inactiveCount = allDepts.length - activeCount;
          final filtered = _getFilteredDepartments();

          return SingleChildScrollView(
            padding: EdgeInsets.all(isNarrow ? 14.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── HEADER & ACTIONS ──────────────────────────────────────────
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.apartment_rounded, color: AppTheme.primaryColor, size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Department Master',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Centralized hospital master controlling OPD, IPD, OT, Staff, and Billing departments',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      onPressed: () => _showAddEditDepartmentDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ─── QUICK METRICS STATS ───────────────────────────────────────
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _buildStatCard('Total Departments', allDepts.length.toString(), Icons.domain_rounded, const Color(0xFF0284C7)),
                    _buildStatCard('Active Departments', activeCount.toString(), Icons.check_circle_outline_rounded, const Color(0xFF16A34A)),
                    _buildStatCard('Inactive / Archived', inactiveCount.toString(), Icons.pause_circle_outline_rounded, const Color(0xFF64748B)),
                  ],
                ),
                const SizedBox(height: 18),

                // ─── SEARCH & FILTER BAR ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: isNarrow ? double.infinity : 320,
                        height: 40,
                        child: TextFormField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          decoration: InputDecoration(
                            hintText: 'Search by name, code, description...',
                            hintStyle: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryColor),
                            prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.primaryColor),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 40,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildFilterPill('All', 'All (${allDepts.length})'),
                                _buildFilterPill('Active', 'Active ($activeCount)'),
                                _buildFilterPill('Inactive', 'Inactive ($inactiveCount)'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: AppTheme.primaryColor, size: 20),
                            tooltip: 'Refresh Master List',
                            onPressed: () => _controller.fetchDepartments(includeInactive: true, forceRefresh: true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ─── DEPARTMENTS LISTING ────────────────────────────────────────
                if (_controller.isLoading && allDepts.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (filtered.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.apartment_rounded, size: 54, color: Color(0xFFCBD5E1)),
                        const SizedBox(height: 14),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No departments matching "$_searchQuery"'
                              : 'No $_statusFilter departments found.',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 6),
                        const Text('Use the "Add Department" button to register new hospital departments.', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                      ],
                    ),
                  )
                else if (isNarrow)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) => _buildDepartmentCard(filtered[idx]),
                  )
                else
                  _buildDepartmentsTable(filtered),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String filterKey, String label) {
    final bool isSelected = _statusFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _statusFilter = filterKey),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentCard(DepartmentModel dept) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: dept.isActive ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dept.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        dept.code,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: dept.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: dept.isActive ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    dept.status,
                    style: TextStyle(
                      color: dept.isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (dept.description != null && dept.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                dept.description!,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showAddEditDepartmentDialog(context, existing: dept),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: dept.isActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: Icon(dept.isActive ? Icons.archive_outlined : Icons.unarchive_outlined, size: 15),
                  label: Text(dept.isActive ? 'Deactivate' : 'Activate', style: const TextStyle(fontSize: 12)),
                  onPressed: () => _confirmToggleStatus(dept),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentsTable(List<DepartmentModel> list) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          horizontalMargin: 20,
          columnSpacing: 24,
          dataRowMaxHeight: 58,
          columns: const [
            DataColumn(label: Text('Department Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)))),
            DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)))),
            DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)))),
          ],
          rows: list.map((dept) {
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.apartment_rounded, size: 16, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        dept.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      dept.code,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF475569)),
                    ),
                  ),
                ),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      dept.description ?? '—',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: dept.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: dept.isActive ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      dept.status,
                      style: TextStyle(
                        color: dept.isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                        tooltip: 'Edit Department',
                        onPressed: () => _showAddEditDepartmentDialog(context, existing: dept),
                      ),
                      IconButton(
                        icon: Icon(
                          dept.isActive ? Icons.archive_outlined : Icons.unarchive_outlined,
                          size: 18,
                          color: dept.isActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                        ),
                        tooltip: dept.isActive ? 'Deactivate Department' : 'Activate Department',
                        onPressed: () => _confirmToggleStatus(dept),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAddEditDepartmentDialog(BuildContext context, {DepartmentModel? existing}) {
    final bool isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String status = existing?.status ?? 'Active';
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            final isNarrow = MediaQuery.of(ctx).size.width < 500;
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: EdgeInsets.symmetric(horizontal: isNarrow ? 14 : 40, vertical: 24),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(isEdit ? Icons.edit_note : Icons.add_business, color: AppTheme.primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Department' : 'Add New Department',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: isNarrow ? double.maxFinite : 460,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Department Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Cardiology, Neurology, General Medicine',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Department name is mandatory' : null,
                        ),
                        const SizedBox(height: 14),

                        const Text('Department Code *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            hintText: 'e.g. CARD, NEUR, GMED',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Code is mandatory';
                            if (v.trim().length < 2 || v.trim().length > 15) return 'Code must be between 2 and 15 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        const Text('Description (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: descCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Clinical focus or operational scope',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),

                        const Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Active', child: Text('Active')),
                            DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDlgState(() => status = v);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          setDlgState(() => isSaving = true);
                          try {
                            if (isEdit) {
                              await _controller.updateDepartment(
                                existing.id,
                                name: nameCtrl.text.trim(),
                                code: codeCtrl.text.trim().toUpperCase(),
                                description: descCtrl.text.trim(),
                                status: status,
                              );
                            } else {
                              await _controller.createDepartment(
                                name: nameCtrl.text.trim(),
                                code: codeCtrl.text.trim().toUpperCase(),
                                description: descCtrl.text.trim(),
                                status: status,
                              );
                            }
                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Department "${nameCtrl.text.trim()}" successfully ${isEdit ? 'updated' : 'registered'}!'),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          } catch (e) {
                            setDlgState(() => isSaving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Save Changes' : 'Create Department'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmToggleStatus(DepartmentModel dept) {
    final bool newActive = !dept.isActive;
    final String actionText = newActive ? 'Activate' : 'Deactivate';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('$actionText Department?'),
        content: Text(
          newActive
              ? 'Are you sure you want to activate "${dept.name}"? It will become visible in all doctor, appointment, and clinical department selection lists.'
              : 'Are you sure you want to deactivate "${dept.name}"? Existing patient records will remain completely intact, but new appointments cannot select it.',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await _controller.toggleDepartmentStatus(dept.id, newActive ? 'Active' : 'Inactive');
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Department "${dept.name}" is now ${newActive ? 'Active' : 'Inactive'}.'),
                    backgroundColor: newActive ? const Color(0xFF059669) : const Color(0xFF475569),
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: Text(actionText),
          ),
        ],
      ),
    );
  }
}

