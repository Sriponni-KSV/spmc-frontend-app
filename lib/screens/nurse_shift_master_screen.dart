import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/nurse_shift_controller.dart';
import '../models/nurse_shift_model.dart';
import '../utils/app_theme.dart';
import '../utils/discard_dialog_helper.dart';
import '../widgets/custom_dropdown_search.dart';

class NurseShiftMasterScreen extends StatefulWidget {
  final bool isMobile;

  const NurseShiftMasterScreen({
    super.key,
    this.isMobile = false,
  });

  @override
  State<NurseShiftMasterScreen> createState() => _NurseShiftMasterScreenState();
}

class _NurseShiftMasterScreenState extends State<NurseShiftMasterScreen> {
  final NurseShiftController _controller = NurseShiftController();
  final TextEditingController _searchController = TextEditingController();

  String _typeFilter = 'All'; // 'All', 'Morning', 'Evening', 'Night'
  String _statusFilter = 'All'; // 'All', 'Active', 'Inactive'
  String _searchQuery = '';

  // Pagination
  int _currentPage = 1;
  int _rowsPerPage = 10;
  final List<int> _pageSizeOptions = [5, 10, 20, 50];

  @override
  void initState() {
    super.initState();
    _controller.fetchShiftModels(includeInactive: true, forceRefresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<NurseShiftModel> _getFilteredShifts() {
    return _controller.shiftModels.where((s) {
      if (_typeFilter != 'All') {
        if (_typeFilter == 'Morning' && !s.shiftType.toLowerCase().contains('morning')) {
          return false;
        }
        if (_typeFilter == 'Evening' && !s.shiftType.toLowerCase().contains('evening')) {
          return false;
        }
        if (_typeFilter == 'Night' && !s.shiftType.toLowerCase().contains('night')) {
          return false;
        }
      }
      if (_statusFilter != 'All') {
        if (_statusFilter == 'Active' && !s.isOperational) return false;
        if (_statusFilter == 'Inactive' && s.isOperational) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatches = s.name.toLowerCase().contains(q);
        final codeMatches = s.code.toLowerCase().contains(q);
        final descMatches = (s.description ?? '').toLowerCase().contains(q);
        final typeMatches = s.shiftType.toLowerCase().contains(q);
        if (!nameMatches && !codeMatches && !descMatches && !typeMatches) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<NurseShiftModel> _getPaginatedShifts(List<NurseShiftModel> filtered) {
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    if (startIndex >= filtered.length) {
      return [];
    }
    final endIndex = (startIndex + _rowsPerPage).clamp(0, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    final bool isNarrow = widget.isMobile || MediaQuery.of(context).size.width < 960;
    final bool isMobile = isNarrow;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final allShifts = _controller.shiftModels;
          final activeCount = allShifts.where((s) => s.isOperational).length;
          final inactiveCount = allShifts.where((s) => !s.isOperational).length;
          final overnightCount = allShifts.where((s) => s.isOvernight).length;
          final morningCount = allShifts.where((s) => s.shiftType.toLowerCase().contains('morning')).length;
          final eveningCount = allShifts.where((s) => s.shiftType.toLowerCase().contains('evening')).length;

          final filtered = _getFilteredShifts();
          final totalPages = (filtered.length / _rowsPerPage).ceil().clamp(1, 9999);
          if (_currentPage > totalPages) {
            _currentPage = totalPages;
          }
          final paginated = _getPaginatedShifts(filtered);

          return SingleChildScrollView(
            padding: EdgeInsets.all(isNarrow ? 14.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── HEADER & ACTIONS ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final isNarrowHeader = headerConstraints.maxWidth < 680;
                      final titleCol = Column(
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
                                child: const Icon(
                                  Icons.schedule_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Nurse Shift Master',
                                style: AppTheme.pageTitleStyle(context, isMobile: isMobile),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configure nurse duty shifts, timing windows, break periods & roster availability',
                            style: AppTheme.pageSubtitleStyle(context, isMobile: isMobile),
                          ),
                        ],
                      );

                      final actionBtns = Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                            label: const Text(
                              'Seed Standard Shifts',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            onPressed: () => _handleSeedDefaults(),
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
                            label: const Text(
                              'Add Nurse Shift',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            onPressed: () => _showAddEditShiftDialog(context),
                          ),
                        ],
                      );

                      if (isNarrowHeader) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleCol,
                            const SizedBox(height: 12),
                            actionBtns,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: titleCol),
                          const SizedBox(width: 16),
                          actionBtns,
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // ─── QUICK METRICS STATS ──────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final int crossAxisCount;
                      if (constraints.maxWidth < 600) {
                        crossAxisCount = 2;
                      } else if (constraints.maxWidth < 960) {
                        crossAxisCount = 3;
                      } else {
                        crossAxisCount = 5;
                      }

                      final double spacing = 10.0;
                      final double cardWidth = ((constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount).floorToDouble();

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _buildStatCard(
                              'Total Shifts',
                              allShifts.length.toString(),
                              Icons.schedule_outlined,
                              const Color(0xFF0284C7),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildStatCard(
                              'Active & Operational',
                              activeCount.toString(),
                              Icons.check_circle_outline_rounded,
                              const Color(0xFF16A34A),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildStatCard(
                              'Inactive Shifts',
                              inactiveCount.toString(),
                              Icons.pause_circle_outline_rounded,
                              const Color(0xFF64748B),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildStatCard(
                              'Overnight Shifts',
                              overnightCount.toString(),
                              Icons.nightlight_round,
                              const Color(0xFF6366F1),
                            ),
                          ),
                          SizedBox(
                            width: crossAxisCount == 2 ? constraints.maxWidth : cardWidth,
                            child: _buildStatCard(
                              'Day / Evening',
                              '$morningCount / $eveningCount',
                              Icons.wb_sunny_outlined,
                              const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // ─── SEARCH & FILTER BAR ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, barConstraints) {
                      final isNarrowBar = barConstraints.maxWidth < 720;

                      final searchWidget = SizedBox(
                        width: isNarrowBar ? double.infinity : 320,
                        height: 40,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search by shift code, name, description...',
                            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _currentPage = 1;
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim();
                              _currentPage = 1;
                            });
                          },
                        ),
                      );

                      final typeFilterDropdown = Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _typeFilter,
                            isDense: true,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Shift Types')),
                              DropdownMenuItem(value: 'Morning', child: Text('Morning / Day')),
                              DropdownMenuItem(value: 'Evening', child: Text('Evening / Afternoon')),
                              DropdownMenuItem(value: 'Night', child: Text('Night / Overnight')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _typeFilter = val;
                                  _currentPage = 1;
                                });
                              }
                            },
                          ),
                        ),
                      );

                      final statusPills = SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildFilterPill('All', 'All (${allShifts.length})'),
                              _buildFilterPill('Active', 'Active ($activeCount)'),
                              _buildFilterPill('Inactive', 'Inactive ($inactiveCount)'),
                            ],
                          ),
                        ),
                      );

                      final refreshBtn = Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF64748B)),
                          tooltip: 'Refresh Shift Master',
                          onPressed: () => _controller.fetchShiftModels(includeInactive: true, forceRefresh: true),
                        ),
                      );

                      if (isNarrowBar) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            searchWidget,
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: typeFilterDropdown),
                                const SizedBox(width: 8),
                                refreshBtn,
                              ],
                            ),
                            const SizedBox(height: 10),
                            statusPills,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          searchWidget,
                          const SizedBox(width: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              typeFilterDropdown,
                              const SizedBox(width: 8),
                              statusPills,
                              const SizedBox(width: 8),
                              refreshBtn,
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // ─── LISTING & PAGINATION ─────────────────────────────────────
                if (_controller.isLoading && allShifts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(strokeWidth: 2.5),
                        SizedBox(height: 16),
                        Text('Loading nurse shifts...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      ],
                    ),
                  )
                else if (_controller.errorMessage != null && allShifts.isEmpty)
                  _buildEmptyState(
                    icon: Icons.cloud_off_rounded,
                    iconColor: AppTheme.dangerColor,
                    title: 'Error loading shifts',
                    subtitle: _controller.errorMessage ?? 'Unable to connect to shift catalog service.',
                    action: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      onPressed: () => _controller.fetchShiftModels(includeInactive: true, forceRefresh: true),
                    ),
                  )
                else if (filtered.isEmpty)
                  if (allShifts.isEmpty)
                    _buildEmptyState(
                      icon: Icons.schedule_outlined,
                      iconColor: AppTheme.primaryColor,
                      title: 'No Nurse Shifts Found',
                      subtitle: 'No shift schedules have been registered yet. Click "Seed Standard Shifts" to auto-populate Morning, Evening, and Night shifts, or add a custom shift.',
                      action: Wrap(
                        spacing: 10,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                            icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                            label: const Text('Seed Standard Shifts'),
                            onPressed: () => _handleSeedDefaults(),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Nurse Shift'),
                            onPressed: () => _showAddEditShiftDialog(context),
                          ),
                        ],
                      ),
                    )
                  else if (_searchQuery.isNotEmpty)
                    _buildEmptyState(
                      icon: Icons.search_off_rounded,
                      iconColor: const Color(0xFF64748B),
                      title: 'No matching shifts found',
                      subtitle: 'No shifts match "$_searchQuery". Check spelling or clear your search query.',
                      action: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear Search'),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                    )
                  else
                    _buildEmptyState(
                      icon: Icons.filter_list_off_rounded,
                      iconColor: const Color(0xFF64748B),
                      title: 'No shifts in this filter',
                      subtitle: 'There are no shifts matching type "$_typeFilter" and status "$_statusFilter".',
                      action: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Show All Shifts'),
                        onPressed: () => setState(() {
                          _typeFilter = 'All';
                          _statusFilter = 'All';
                        }),
                      ),
                    )
                else ...[
                  if (isNarrow)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: paginated.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) => _buildShiftCard(paginated[idx]),
                    )
                  else
                    _buildShiftsTable(paginated),

                  // Pagination Footer
                  const SizedBox(height: 14),
                  _buildPaginationBar(filtered.length, totalPages),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── STAT CARD WIDGET ────────────────────────────────────────────────────────
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: color)),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── FILTER PILL ─────────────────────────────────────────────────────────────
  Widget _buildFilterPill(String filterValue, String label) {
    final isSelected = _statusFilter == filterValue;
    return InkWell(
      onTap: () {
        setState(() {
          _statusFilter = filterValue;
          _currentPage = 1;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
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

  // ─── STATUS BADGE ────────────────────────────────────────────────────────────
  Widget _buildStatusBadge(NurseShiftModel shift) {
    final bool isOp = shift.isOperational;
    final Color bg = isOp ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9);
    final Color border = isOp ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1);
    final Color text = isOp ? const Color(0xFF15803D) : const Color(0xFF64748B);
    final IconData icon = isOp ? Icons.check_circle_rounded : Icons.pause_circle_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            isOp ? 'Active' : 'Inactive',
            style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ─── SHIFT TYPE BADGE ────────────────────────────────────────────────────────
  Widget _buildShiftTypeBadge(NurseShiftModel shift) {
    Color bg;
    Color border;
    Color text;
    IconData icon;

    if (shift.isOvernight) {
      bg = const Color(0xFFEEF2FF);
      border = const Color(0xFFC7D2FE);
      text = const Color(0xFF4338CA);
      icon = Icons.nightlight_round;
    } else if (shift.shiftType.toLowerCase().contains('morning')) {
      bg = const Color(0xFFFEF3C7);
      border = const Color(0xFFFDE68A);
      text = const Color(0xFFB45309);
      icon = Icons.wb_sunny_rounded;
    } else {
      bg = const Color(0xFFFFEDD5);
      border = const Color(0xFFFED7AA);
      text = const Color(0xFFC2410C);
      icon = Icons.wb_twilight_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            shift.shiftType,
            style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ─── DESKTOP DATA TABLE ──────────────────────────────────────────────────────
  Widget _buildShiftsTable(List<NurseShiftModel> shifts) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth > 880 ? constraints.maxWidth : 880,
                ),
                child: DataTable(
                  headingRowHeight: 44,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 58,
                  horizontalMargin: 20,
                  columnSpacing: 24,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(
                  label: Text('Shift Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                ),
                DataColumn(
                  label: Text('Shift Name & Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                ),
                DataColumn(
                  label: Text('Duty Timings (12h)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                ),
                DataColumn(
                  label: Text('Duration & Break', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                ),
                DataColumn(
                  label: Text('Shift Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                ),
                DataColumn(
                  label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                ),
                DataColumn(
                  label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                ),
              ],
              rows: shifts.map((shift) {
                return DataRow(
                  cells: [
                    // Code
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          shift.code,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ),

                    // Name & Description
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            shift.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                          if (shift.description != null && shift.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              shift.description!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Timings (12h AM/PM)
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            shift.formattedTiming,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF1E293B)),
                          ),
                          if (shift.isOvernight) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'Crosses midnight into the next day',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '+1d',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Duration & Break
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            shift.formattedDuration,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Net: ${shift.netWorkingHours.toStringAsFixed(1)} hrs work',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),

                    // Shift Type Badge
                    DataCell(_buildShiftTypeBadge(shift)),

                    // Status Badge
                    DataCell(_buildStatusBadge(shift)),

                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 17, color: Color(0xFF0284C7)),
                            tooltip: 'View Shift Details',
                            onPressed: () => _showShiftDetailsDialog(context, shift),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF64748B)),
                            tooltip: 'Edit Shift',
                            onPressed: () => _showAddEditShiftDialog(context, existing: shift),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                            tooltip: 'More actions',
                            onSelected: (action) {
                              if (action == 'toggle_status') {
                                _handleToggleStatus(shift);
                              } else if (action == 'delete') {
                                _handleDeleteShift(shift);
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'toggle_status',
                                child: Row(
                                  children: [
                                    Icon(
                                      shift.isOperational ? Icons.pause_circle_outline : Icons.check_circle_outline,
                                      size: 16,
                                      color: shift.isOperational ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      shift.isOperational ? 'Deactivate Shift' : 'Activate Shift',
                                      style: const TextStyle(fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                    SizedBox(width: 8),
                                    Text('Delete Shift', style: TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
                                  ],
                                ),
                              ),
                            ],
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
      },
    ),
  ),
);
  }

  // ─── MOBILE CARD VIEW ────────────────────────────────────────────────────────
  Widget _buildShiftCard(NurseShiftModel s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(s.code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusBadge(s),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildShiftTypeBadge(s),
              const SizedBox(width: 8),
              const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 3),
              Text(
                s.formattedTiming,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ],
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  s.formattedDuration,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0284C7)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    tooltip: 'View Details',
                    onPressed: () => _showShiftDetailsDialog(context, s),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    tooltip: 'Edit',
                    onPressed: () => _showAddEditShiftDialog(context, existing: s),
                  ),
                  IconButton(
                    icon: Icon(
                      s.isOperational ? Icons.pause_circle_outline : Icons.check_circle_outline,
                      size: 18,
                      color: s.isOperational ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    tooltip: s.isOperational ? 'Deactivate' : 'Activate',
                    onPressed: () => _handleToggleStatus(s),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    tooltip: 'Delete',
                    onPressed: () => _handleDeleteShift(s),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── PAGINATION BAR ──────────────────────────────────────────────────────────
  Widget _buildPaginationBar(int totalCount, int totalPages) {
    final start = totalCount == 0 ? 0 : (_currentPage - 1) * _rowsPerPage + 1;
    final end = (_currentPage * _rowsPerPage).clamp(0, totalCount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final countText = Text(
            'Showing $start to $end of $totalCount nurse shifts',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          );

          final pageSizeWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Per page:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(width: 6),
              DropdownButton<int>(
                value: _rowsPerPage,
                isDense: true,
                underline: const SizedBox.shrink(),
                style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                items: _pageSizeOptions.map((sz) => DropdownMenuItem(value: sz, child: Text('$sz'))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _rowsPerPage = val;
                      _currentPage = 1;
                    });
                  }
                },
              ),
            ],
          );

          final navControls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Previous Page',
                onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
              ),
              Text(
                'Page $_currentPage of $totalPages',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Next Page',
                onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
              ),
            ],
          );

          // Narrow Viewport (< 620px): Clean 2-row layout with FittedBox to prevent any overflow
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: countText,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    pageSizeWidget,
                    navControls,
                  ],
                ),
              ],
            );
          }

          // Desktop Viewport (>= 620px)
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(child: countText),
                    const SizedBox(width: 14),
                    pageSizeWidget,
                  ],
                ),
              ),
              const SizedBox(width: 10),
              navControls,
            ],
          );
        },
      ),
    );
  }

  // ─── EMPTY STATE ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState({
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (iconColor ?? const Color(0xFF94A3B8)).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: iconColor ?? const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4), textAlign: TextAlign.center),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action,
          ],
        ],
      ),
    );
  }

  // ─── TIME HELPER FOR PICKER ──────────────────────────────────────────────────
  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      final hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 6, minute: 0);
    }
  }

  String _formatTimeOfDayTo24h(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  // ─── ADD / EDIT SHIFT DIALOG ─────────────────────────────────────────────────
  void _showAddEditShiftDialog(BuildContext context, {NurseShiftModel? existing}) {
    final bool isEdit = existing != null;
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');

    TimeOfDay startTime = isEdit ? _parseTimeOfDay(existing.startTime) : const TimeOfDay(hour: 6, minute: 0);
    TimeOfDay endTime = isEdit ? _parseTimeOfDay(existing.endTime) : const TimeOfDay(hour: 14, minute: 0);
    int breakMinutes = existing?.breakMinutes ?? 30;
    String status = existing?.status ?? 'Active';

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    bool isDirty() {
      return codeCtrl.text.trim().toUpperCase() != (existing?.code.toUpperCase() ?? '') ||
          nameCtrl.text.trim() != (existing?.name ?? '') ||
          descCtrl.text.trim() != (existing?.description ?? '') ||
          breakMinutes != (existing?.breakMinutes ?? 30) ||
          status != (existing?.status ?? 'Active') ||
          _formatTimeOfDayTo24h(startTime) != (existing?.startTime ?? '06:00:00') ||
          _formatTimeOfDayTo24h(endTime) != (existing?.endTime ?? '14:00:00');
    }

    double calculateDuration(TimeOfDay start, TimeOfDay end) {
      final startMin = start.hour * 60 + start.minute;
      var endMin = end.hour * 60 + end.minute;
      if (endMin <= startMin) {
        endMin += 24 * 60; // Overnight wrap-around
      }
      return (endMin - startMin) / 60.0;
    }

    bool checkIsOvernight(TimeOfDay start, TimeOfDay end) {
      final startMin = start.hour * 60 + start.minute;
      final endMin = end.hour * 60 + end.minute;
      return endMin <= startMin;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            final isNarrow = MediaQuery.of(ctx).size.width < 560;
            final double currentDuration = calculateDuration(startTime, endTime);
            final bool isOvernight = checkIsOvernight(startTime, endTime);
            final double netWorking = (currentDuration - (breakMinutes / 60.0)).clamp(0.0, 24.0);

            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (bool didPop, dynamic result) async {
                if (didPop) return;
                DiscardDialogHelper.handleCancelOrDismiss(ctx, isDirty: isDirty());
              },
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.schedule_rounded, color: AppTheme.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Nurse Shift (${existing.code})' : 'Add Nurse Shift',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                content: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 520, minWidth: isNarrow ? 280 : 460),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Shift Code & Shift Name
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Shift Code
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Shift Code *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: codeCtrl,
                                      textCapitalization: TextCapitalization.characters,
                                      decoration: const InputDecoration(
                                        hintText: 'e.g. MOR',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Code required';
                                        }
                                        final clean = val.trim().toUpperCase();
                                        if (_controller.isCodeDuplicate(clean, excludeId: existing?.id)) {
                                          return 'Code already used';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Shift Name
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Shift Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: nameCtrl,
                                      decoration: const InputDecoration(
                                        hintText: 'e.g. Morning Shift',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Name required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Start Time & End Time Pickers
                          const Text('Shift Duty Window *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              // Start Time Button
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: ctx,
                                      initialTime: startTime,
                                      helpText: 'Select Shift Start Time',
                                    );
                                    if (picked != null) {
                                      setDlgState(() => startTime = picked);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(8),
                                      color: const Color(0xFFF8FAFC),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.login_rounded, size: 16, color: Color(0xFF0284C7)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Start Time', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                              Text(
                                                startTime.format(ctx),
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // End Time Button
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: ctx,
                                      initialTime: endTime,
                                      helpText: 'Select Shift End Time',
                                    );
                                    if (picked != null) {
                                      setDlgState(() => endTime = picked);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(8),
                                      color: const Color(0xFFF8FAFC),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.logout_rounded, size: 16, color: Color(0xFF0284C7)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('End Time', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                              Text(
                                                endTime.format(ctx),
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Live Shift Duration & Overnight Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isOvernight ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isOvernight ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isOvernight ? Icons.nightlight_round : Icons.timer_outlined,
                                  size: 16,
                                  color: isOvernight ? const Color(0xFF4338CA) : const Color(0xFF0284C7),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Duration: ${currentDuration.toStringAsFixed(1)} hrs  •  Net Work: ${netWorking.toStringAsFixed(1)} hrs',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isOvernight ? const Color(0xFF3730A3) : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                if (isOvernight)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4338CA),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Overnight',
                                      style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Break Duration & Status Dropdowns
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Break Duration
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Break Duration *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    CustomDropdownSearch(
                                      label: '',
                                      hint: 'Select break',
                                      value: breakMinutes.toString(),
                                      dropdownMap: const {
                                        '0': 'No Break (0 mins)',
                                        '15': '15 minutes',
                                        '30': '30 minutes (Standard)',
                                        '45': '45 minutes',
                                        '60': '60 minutes (1 hour)',
                                      },
                                      height: 44,
                                      onChanged: (val) {
                                        if (val != null) {
                                          final parsed = int.tryParse(val);
                                          if (parsed != null) setDlgState(() => breakMinutes = parsed);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Status
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Status *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    CustomDropdownSearch(
                                      label: '',
                                      hint: 'Select status',
                                      value: status,
                                      dropdownItems: const ['Active', 'Inactive'],
                                      height: 44,
                                      onChanged: (val) {
                                        if (val != null) setDlgState(() => status = val);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            status == 'Active'
                                ? '✓ Only Active shifts can be assigned to nurses in Shift Allocation & Roster.'
                                : '⚠️ Inactive shifts are locked from new duty assignments.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: status == 'Active' ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Description / Notes
                          const Text('Shift Description / Clinical Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: descCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Primary morning round, medication distribution, doctor handover',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving ? null : () => DiscardDialogHelper.handleCancelOrDismiss(ctx, isDirty: isDirty()),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setDlgState(() => isSaving = true);

                            final startStr = _formatTimeOfDayTo24h(startTime);
                            final endStr = _formatTimeOfDayTo24h(endTime);

                            Map<String, dynamic> result;
                            if (isEdit) {
                              result = await _controller.updateShiftModel(
                                existing.id,
                                code: codeCtrl.text.trim().toUpperCase(),
                                name: nameCtrl.text.trim(),
                                startTime: startStr,
                                endTime: endStr,
                                breakMinutes: breakMinutes,
                                description: descCtrl.text.trim(),
                                status: status,
                              );
                            } else {
                              result = await _controller.createShiftModel(
                                code: codeCtrl.text.trim().toUpperCase(),
                                name: nameCtrl.text.trim(),
                                startTime: startStr,
                                endTime: endStr,
                                breakMinutes: breakMinutes,
                                description: descCtrl.text.trim(),
                                status: status,
                              );
                            }

                            setDlgState(() => isSaving = false);

                            if (ctx.mounted) {
                              if (result['success'] == true) {
                                Navigator.pop(ctx);
                                _showNotification(result['message'] ?? 'Shift saved successfully.', isSuccess: true);
                              } else {
                                _showNotification(result['message'] ?? 'Failed to save shift.', isSuccess: false);
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEdit ? 'Save Changes' : 'Create Shift'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── VIEW SHIFT DETAILS DIALOG ───────────────────────────────────────────────
  void _showShiftDetailsDialog(BuildContext context, NurseShiftModel shift) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${shift.name} (${shift.code})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _buildStatusBadge(shift),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, minWidth: 280),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Shift Code', shift.code),
                  _buildDetailRow('Shift Name', shift.name),
                  _buildDetailRow('Duty Window (12h)', shift.formattedTiming),
                  _buildDetailRow('24h Timings', '${shift.startTime} – ${shift.endTime}'),
                  _buildDetailRow('Total Duration', '${shift.shiftDurationHours.toStringAsFixed(1)} hours'),
                  _buildDetailRow('Break Duration', '${shift.breakMinutes} minutes'),
                  _buildDetailRow('Net Working Hours', '${shift.netWorkingHours.toStringAsFixed(1)} hours'),
                  _buildDetailRow('Shift Classification', shift.shiftType),
                  _buildDetailRow('Overnight Schedule', shift.isOvernight ? 'Yes (spans midnight)' : 'No (same day)'),
                  if (shift.description != null && shift.description!.trim().isNotEmpty)
                    _buildDetailRow('Description', shift.description!),
                  if (shift.createdAt != null)
                    _buildDetailRow('Created At', DateFormat('dd MMM yyyy, hh:mm a').format(shift.createdAt!)),
                  if (shift.updatedAt != null)
                    _buildDetailRow('Last Updated', DateFormat('dd MMM yyyy, hh:mm a').format(shift.updatedAt!)),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showAddEditShiftDialog(context, existing: shift);
              },
              child: const Text('Edit Shift'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TOGGLE STATUS ───────────────────────────────────────────────────────────
  void _handleToggleStatus(NurseShiftModel shift) async {
    final bool newIsActive = !shift.isOperational;
    final String newStatus = newIsActive ? 'Active' : 'Inactive';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(newIsActive ? 'Activate Nurse Shift' : 'Deactivate Nurse Shift'),
        content: Text(
          newIsActive
              ? 'Are you sure you want to activate "${shift.name}" (${shift.code})? It will become available for duty allocations and rosters.'
              : 'Are you sure you want to deactivate "${shift.name}" (${shift.code})? Inactive shifts are blocked from new duty allocations. Existing allocations remain unaffected.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newIsActive ? const Color(0xFF16A34A) : const Color(0xFFD97706),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newIsActive ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await _controller.toggleShiftStatus(shift.id, newStatus);
    _showNotification(result['message'] ?? 'Shift status updated.', isSuccess: result['success'] == true);
  }

  // ─── DELETE SHIFT ────────────────────────────────────────────────────────────
  void _handleDeleteShift(NurseShiftModel shift) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Nurse Shift'),
        content: Text(
          'Are you sure you want to delete "${shift.name}" (${shift.code})?\n\nIf nurses are linked to this shift in historical records, the system will safely deactivate it to preserve clinical duty logs.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await _controller.deleteShiftModel(shift.id);
    _showNotification(result['message'] ?? 'Shift removed.', isSuccess: result['success'] == true);
  }

  // ─── SEED DEFAULT SHIFTS ─────────────────────────────────────────────────────
  void _handleSeedDefaults() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Seed Standard Hospital Shifts'),
        content: const Text(
          'This will configure or update the 3 standard hospital nursing shifts:\n\n'
          '• MOR: Morning Shift (06:00 AM – 02:00 PM)\n'
          '• EVE: Evening Shift (02:00 PM – 10:00 PM)\n'
          '• NIG: Night Shift (10:00 PM – 06:00 AM, Overnight)\n\n'
          'Existing assignments will not be duplicated. Proceed?',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Seed Shifts'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await _controller.seedDefaultShiftModels();
    _showNotification(result['message'] ?? 'Default shifts configured.', isSuccess: result['success'] == true);
  }

  // ─── NOTIFICATION SNACKBAR ───────────────────────────────────────────────────
  void _showNotification(String message, {bool isSuccess = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF16A34A) : AppTheme.dangerColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

