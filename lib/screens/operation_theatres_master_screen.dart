import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/operation_theatre_controller.dart';
import '../models/operation_theatre_model.dart';
import '../utils/app_theme.dart';
import '../utils/discard_dialog_helper.dart';
import '../widgets/custom_dropdown_search.dart';

class OperationTheatresMasterScreen extends StatefulWidget {
  final bool isMobile;

  const OperationTheatresMasterScreen({
    super.key,
    this.isMobile = false,
  });

  @override
  State<OperationTheatresMasterScreen> createState() => _OperationTheatresMasterScreenState();
}

class _OperationTheatresMasterScreenState extends State<OperationTheatresMasterScreen> {
  final OperationTheatreController _controller = OperationTheatreController();
  final TextEditingController _searchController = TextEditingController();

  String _typeFilter = 'All'; // 'All', 'Major', 'Minor', 'Speciality'
  String _statusFilter = 'All'; // 'All', 'Active', 'Inactive', 'Maintenance'
  String _searchQuery = '';

  // Pagination
  int _currentPage = 1;
  int _rowsPerPage = 10;
  final List<int> _pageSizeOptions = [5, 10, 20, 50];

  @override
  void initState() {
    super.initState();
    _controller.fetchTheatres(includeInactive: true, forceRefresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OperationTheatreModel> _getFilteredTheatres() {
    return _controller.theatres.where((t) {
      if (_typeFilter != 'All' && t.theatreType.toLowerCase() != _typeFilter.toLowerCase()) {
        return false;
      }
      if (_statusFilter != 'All') {
        if (_statusFilter == 'Active' && !t.isOperational) return false;
        if (_statusFilter == 'Inactive' && !t.isInactive) return false;
        if (_statusFilter == 'Maintenance' && !t.isMaintenance) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatches = t.theatreName.toLowerCase().contains(q);
        final codeMatches = t.theatreCode.toLowerCase().contains(q);
        final locMatches = (t.location ?? '').toLowerCase().contains(q);
        final typeMatches = t.theatreType.toLowerCase().contains(q);
        if (!nameMatches && !codeMatches && !locMatches && !typeMatches) return false;
      }
      return true;
    }).toList();
  }

  List<OperationTheatreModel> _getPaginatedTheatres(List<OperationTheatreModel> filtered) {
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
          final allTheatres = _controller.theatres;
          final activeCount = allTheatres.where((t) => t.isOperational).length;
          final maintenanceCount = allTheatres.where((t) => t.isMaintenance).length;
          final inactiveCount = allTheatres.where((t) => t.isInactive && !t.isMaintenance).length;
          final majorCount = allTheatres.where((t) => t.theatreType.toLowerCase() == 'major').length;
          final minorCount = allTheatres.where((t) => t.theatreType.toLowerCase() == 'minor').length;

          final filtered = _getFilteredTheatres();
          final totalPages = (filtered.length / _rowsPerPage).ceil().clamp(1, 9999);
          if (_currentPage > totalPages) {
            _currentPage = totalPages;
          }
          final paginated = _getPaginatedTheatres(filtered);

          return SingleChildScrollView(
            padding: EdgeInsets.all(isNarrow ? 14.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── HEADER & ACTIONS ──────────────────────────────────────────
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
                                child: const Icon(Icons.meeting_room_rounded, color: AppTheme.primaryColor, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Operation Theatres Master',
                                style: AppTheme.pageTitleStyle(context, isMobile: isMobile),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage operating suites, surgical rooms, booking availability & status (Active, Maintenance, Inactive)',
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
                            label: const Text('Seed Standard Theatres', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                            label: const Text('Add Operation Theatre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            onPressed: () => _showAddEditTheatreDialog(context),
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

                // ─── QUICK METRICS STATS ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double cardWidth;
                      if (constraints.maxWidth < 600) {
                        cardWidth = (constraints.maxWidth - 10) / 2;
                      } else if (constraints.maxWidth < 960) {
                        cardWidth = (constraints.maxWidth - 20) / 3;
                      } else {
                        cardWidth = (constraints.maxWidth - 40) / 5;
                      }

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(width: cardWidth.clamp(130.0, 360.0), child: _buildStatCard('Total OT Suites', allTheatres.length.toString(), Icons.meeting_room_outlined, const Color(0xFF0284C7))),
                          SizedBox(width: cardWidth.clamp(130.0, 360.0), child: _buildStatCard('Active & Available', activeCount.toString(), Icons.check_circle_outline_rounded, const Color(0xFF16A34A))),
                          SizedBox(width: cardWidth.clamp(130.0, 360.0), child: _buildStatCard('Under Maintenance', maintenanceCount.toString(), Icons.build_circle_outlined, const Color(0xFFD97706))),
                          SizedBox(width: cardWidth.clamp(130.0, 360.0), child: _buildStatCard('Inactive / Closed', inactiveCount.toString(), Icons.pause_circle_outline_rounded, const Color(0xFF64748B))),
                          SizedBox(width: cardWidth.clamp(130.0, 360.0), child: _buildStatCard('Major / Minor OT', '$majorCount / $minorCount', Icons.medical_services_outlined, const Color(0xFF7C3AED))),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // ─── SEARCH & FILTER BAR ───────────────────────────────────────
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

                      final searchBox = SizedBox(
                        width: isNarrowBar ? double.infinity : 320,
                        height: 40,
                        child: TextFormField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim();
                              _currentPage = 1;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search by theatre name, code, location...',
                            hintStyle: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryColor),
                            prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.primaryColor),
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
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      );

                      final typeFilterDropdown = Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _typeFilter,
                            isDense: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF475569)),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Types')),
                              DropdownMenuItem(value: 'Major', child: Text('Major OT')),
                              DropdownMenuItem(value: 'Minor', child: Text('Minor OT')),
                              DropdownMenuItem(value: 'Speciality', child: Text('Speciality OT')),
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
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildFilterPill('All', 'All (${allTheatres.length})'),
                              _buildFilterPill('Active', 'Active ($activeCount)'),
                              _buildFilterPill('Maintenance', 'Maint. ($maintenanceCount)'),
                              _buildFilterPill('Inactive', 'Inactive ($inactiveCount)'),
                            ],
                          ),
                        ),
                      );

                      final refreshBtn = Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.refresh, color: AppTheme.primaryColor, size: 20),
                          tooltip: 'Refresh OT Master',
                          onPressed: () => _controller.fetchTheatres(includeInactive: true, forceRefresh: true),
                        ),
                      );

                      if (isNarrowBar) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            searchBox,
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
                          searchBox,
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

                // ─── LISTING & PAGINATION ──────────────────────────────────────
                if (_controller.isLoading && allTheatres.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(strokeWidth: 2.5),
                        SizedBox(height: 16),
                        Text('Loading operation theatres...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      ],
                    ),
                  )
                else if (_controller.errorMessage != null && allTheatres.isEmpty)
                  _buildEmptyState(
                    icon: Icons.cloud_off_rounded,
                    iconColor: AppTheme.dangerColor,
                    title: 'Error loading data',
                    subtitle: _controller.errorMessage ?? 'Unable to connect to OT master service.',
                    action: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      onPressed: () => _controller.fetchTheatres(includeInactive: true, forceRefresh: true),
                    ),
                  )
                else if (filtered.isEmpty)
                  if (allTheatres.isEmpty)
                    _buildEmptyState(
                      icon: Icons.meeting_room_outlined,
                      iconColor: AppTheme.primaryColor,
                      title: 'No Operation Theatres Found',
                      subtitle: 'No surgical theatres have been registered yet in the hospital master. Click "Seed Standard Theatres" or "Add Operation Theatre" to begin.',
                      action: Wrap(
                        spacing: 10,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                            icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                            label: const Text('Seed Standard Theatres'),
                            onPressed: () => _handleSeedDefaults(),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Operation Theatre'),
                            onPressed: () => _showAddEditTheatreDialog(context),
                          ),
                        ],
                      ),
                    )
                  else if (_searchQuery.isNotEmpty)
                    _buildEmptyState(
                      icon: Icons.search_off_rounded,
                      iconColor: const Color(0xFF64748B),
                      title: 'No matching theatres found',
                      subtitle: 'No theatres match "$_searchQuery". Check spelling or clear search filters.',
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
                      title: 'No theatres in this filter',
                      subtitle: 'There are no theatres matching type "$_typeFilter" and status "$_statusFilter".',
                      action: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Show All Theatres'),
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
                      itemBuilder: (context, idx) => _buildTheatreCard(paginated[idx]),
                    )
                  else
                    _buildTheatresTable(paginated),

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

  // ─── STAT CARD ─────────────────────────────────────────────────────────────
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
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

  // ─── FILTER PILL ───────────────────────────────────────────────────────────
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

  // ─── STATUS BADGE ──────────────────────────────────────────────────────────
  Widget _buildStatusBadge(OperationTheatreModel theatre) {
    Color bg;
    Color border;
    Color text;
    IconData icon;

    if (theatre.isOperational) {
      bg = const Color(0xFFDCFCE7);
      border = const Color(0xFF86EFAC);
      text = const Color(0xFF15803D);
      icon = Icons.check_circle_rounded;
    } else if (theatre.isMaintenance) {
      bg = const Color(0xFFFEF3C7);
      border = const Color(0xFFFCD34D);
      text = const Color(0xFFB45309);
      icon = Icons.build_circle_rounded;
    } else {
      bg = const Color(0xFFF1F5F9);
      border = const Color(0xFFCBD5E1);
      text = const Color(0xFF64748B);
      icon = Icons.pause_circle_rounded;
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
            theatre.status,
            style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ─── TYPE BADGE ────────────────────────────────────────────────────────────
  Widget _buildTypeBadge(String type) {
    Color bg = const Color(0xFFEFF6FF);
    Color border = const Color(0xFFBFDBFE);
    Color text = const Color(0xFF1D4ED8);

    if (type.toLowerCase() == 'minor') {
      bg = const Color(0xFFFAF5FF);
      border = const Color(0xFFE9D5FF);
      text = const Color(0xFF7E22CE);
    } else if (type.toLowerCase() == 'speciality') {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      text = const Color(0xFFB45309);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        type,
        style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ─── DESKTOP DATA TABLE ────────────────────────────────────────────────────
  Widget _buildTheatresTable(List<OperationTheatreModel> list) {
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
                  minWidth: constraints.maxWidth > 920 ? constraints.maxWidth : 920,
                ),
                child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              horizontalMargin: 20,
              columnSpacing: 22,
              dataRowMaxHeight: 56,
              columns: const [
                DataColumn(label: Text('Theatre Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155)))),
                DataColumn(label: Text('Theatre Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155)))),
                DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155)))),
                DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155)))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155)))),
                DataColumn(label: Text('Today\'s Surgeries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155)))),
                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155)))),
              ],
              rows: list.map((t) {
                return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          t.theatreCode,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ),
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
                            child: const Icon(Icons.meeting_room_rounded, size: 15, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.theatreName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                    DataCell(_buildTypeBadge(t.theatreType)),
                    DataCell(
                      Text(
                        (t.location != null && t.location!.isNotEmpty) ? t.location! : '—',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ),
                    DataCell(_buildStatusBadge(t)),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: t.activeTodayCount > 0 ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          t.activeTodayCount > 0 ? '${t.activeTodayCount} Scheduled' : 'None scheduled',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: t.activeTodayCount > 0 ? const Color(0xFF0369A1) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 17, color: Color(0xFF0284C7)),
                            tooltip: 'View Details',
                            onPressed: () => _showTheatreDetailsDialog(context, t),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF475569)),
                            tooltip: 'Edit Theatre',
                            onPressed: () => _showAddEditTheatreDialog(context, existing: t),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Quick Status Change',
                            icon: const Icon(Icons.more_vert, size: 17, color: Color(0xFF64748B)),
                            onSelected: (val) => _handleStatusChange(t, val),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'Active',
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                                    SizedBox(width: 8),
                                    Text('Set Active (Operational)', style: TextStyle(fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'Maintenance',
                                child: Row(
                                  children: [
                                    Icon(Icons.build_circle_outlined, size: 16, color: Color(0xFFD97706)),
                                    SizedBox(width: 8),
                                    Text('Set Maintenance', style: TextStyle(fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'Inactive',
                                child: Row(
                                  children: [
                                    Icon(Icons.pause_circle_outline, size: 16, color: Color(0xFF64748B)),
                                    SizedBox(width: 8),
                                    Text('Set Inactive', style: TextStyle(fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'Delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                    SizedBox(width: 8),
                                    Text('Delete / Deactivate', style: TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
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

  // ─── MOBILE CARD VIEW ──────────────────────────────────────────────────────
  Widget _buildTheatreCard(OperationTheatreModel t) {
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
                child: Text(t.theatreCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.theatreName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusBadge(t),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTypeBadge(t.theatreType),
              const SizedBox(width: 8),
              if (t.location != null && t.location!.isNotEmpty)
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          t.location!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  t.activeTodayCount > 0 ? '${t.activeTodayCount} surgery today' : 'No surgery today',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: t.activeTodayCount > 0 ? const Color(0xFF0369A1) : const Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0284C7)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'View Details',
                    onPressed: () => _showTheatreDetailsDialog(context, t),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Edit Theatre',
                    onPressed: () => _showAddEditTheatreDialog(context, existing: t),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'More Options',
                    onSelected: (val) => _handleStatusChange(t, val),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'Active', child: Text('Set Active')),
                      const PopupMenuItem(value: 'Maintenance', child: Text('Set Maintenance')),
                      const PopupMenuItem(value: 'Inactive', child: Text('Set Inactive')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'Delete', child: Text('Delete / Deactivate', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── PAGINATION BAR ────────────────────────────────────────────────────────
  Widget _buildPaginationBar(int totalCount, int totalPages) {
    final start = totalCount == 0 ? 0 : ((_currentPage - 1) * _rowsPerPage) + 1;
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
            'Showing $start to $end of $totalCount operation theatres',
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

          // Mobile Viewport (< 460px): Stack into 2 clean rows
          if (constraints.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: countText),
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

          // Tablet Viewport (< 680px)
          if (constraints.maxWidth < 680) {
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    countText,
                    pageSizeWidget,
                  ],
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: navControls),
              ],
            );
          }

          // Desktop Viewport (>= 680px)
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  countText,
                  const SizedBox(width: 14),
                  pageSizeWidget,
                ],
              ),
              navControls,
            ],
          );
        },
      ),
    );
  }

  // ─── EMPTY STATE ───────────────────────────────────────────────────────────
  Widget _buildEmptyState({
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
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

  // ─── ADD / EDIT THEATRE DIALOG ─────────────────────────────────────────────
  void _showAddEditTheatreDialog(BuildContext context, {OperationTheatreModel? existing}) {
    final bool isEdit = existing != null;
    final codeCtrl = TextEditingController(text: existing?.theatreCode ?? '');
    final nameCtrl = TextEditingController(text: existing?.theatreName ?? '');
    final locCtrl = TextEditingController(text: existing?.location ?? '');
    String theatreType = existing?.theatreType ?? 'Major';
    String status = existing?.status ?? 'Active';
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    bool isDirty() {
      return codeCtrl.text.trim().toUpperCase() != (existing?.theatreCode.toUpperCase() ?? '') ||
          nameCtrl.text.trim() != (existing?.theatreName ?? '') ||
          locCtrl.text.trim() != (existing?.location ?? '') ||
          theatreType != (existing?.theatreType ?? 'Major') ||
          status != (existing?.status ?? 'Active');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            final isNarrow = MediaQuery.of(ctx).size.width < 520;
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (bool didPop, dynamic result) async {
                if (didPop) return;
                DiscardDialogHelper.handleCancelOrDismiss(ctx, isDirty: isDirty());
              },
              child: AlertDialog(
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
                      child: Icon(isEdit ? Icons.edit_note : Icons.add_home_work, color: AppTheme.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Operation Theatre' : 'Add Operation Theatre',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: isNarrow ? double.maxFinite : 480,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Theatre Code
                          const Text('Theatre Code *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'e.g. MOT-01, MOT-02, MIN-01',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Theatre Code is mandatory.';
                              final clean = v.trim().toUpperCase();
                              if (clean.length < 2 || clean.length > 20) return 'Code must be between 2 and 20 characters.';
                              if (_controller.isCodeDuplicate(clean, excludeId: existing?.id)) {
                                return 'Theatre Code "$clean" is already in use.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Theatre Name
                          const Text('Theatre Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Major OT 1, Laparoscopic Suite',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Theatre Name is mandatory.' : null,
                          ),
                          const SizedBox(height: 14),

                          // Theatre Type
                          const Text('Theatre Type *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          CustomDropdownSearch(
                            label: '',
                            hint: 'Select theatre type',
                            value: theatreType,
                            dropdownMap: const {
                              'Major': 'Major OT',
                              'Minor': 'Minor OT',
                              'Speciality': 'Speciality OT',
                            },
                            height: 44,
                            onChanged: (val) {
                              if (val != null) setDlgState(() => theatreType = val);
                            },
                          ),
                          const SizedBox(height: 14),

                          // Location
                          const Text('Location / Floor (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: locCtrl,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 1st Floor - Surgical Suite, Block B',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Status
                          const Text('Status *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          CustomDropdownSearch(
                            label: '',
                            hint: 'Select status',
                            value: status,
                            dropdownMap: const {
                              'Active': 'Active (Available for Surgery Booking)',
                              'Maintenance': 'Maintenance (Blocked for Bookings)',
                              'Inactive': 'Inactive (Deactivated)',
                            },
                            height: 44,
                            onChanged: (val) {
                              if (val != null) setDlgState(() => status = val);
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            status == 'Active'
                                ? '✓ Only Active theatres are available for new surgery bookings.'
                                : '⚠ Maintenance and Inactive theatres will be locked from new surgery scheduling.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: status == 'Active' ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              fontWeight: FontWeight.w500,
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

                            Map<String, dynamic> result;
                            if (isEdit) {
                              result = await _controller.updateTheatre(
                                id: existing.id,
                                theatreCode: codeCtrl.text.trim(),
                                theatreName: nameCtrl.text.trim(),
                                theatreType: theatreType,
                                location: locCtrl.text.trim(),
                                status: status,
                              );
                            } else {
                              result = await _controller.createTheatre(
                                theatreCode: codeCtrl.text.trim(),
                                theatreName: nameCtrl.text.trim(),
                                theatreType: theatreType,
                                location: locCtrl.text.trim(),
                                status: status,
                              );
                            }

                            setDlgState(() => isSaving = false);

                            if (ctx.mounted) {
                              if (result['success'] == true) {
                                Navigator.pop(ctx);
                                _showNotification(result['message'] ?? 'Operation Theatre saved.', isSuccess: true);
                              } else {
                                _showNotification(result['message'] ?? 'Failed to save theatre.', isSuccess: false);
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isEdit ? 'Update Theatre' : 'Add Theatre'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── VIEW THEATRE DETAILS DIALOG ───────────────────────────────────────────
  void _showTheatreDetailsDialog(BuildContext context, OperationTheatreModel t) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.meeting_room_rounded, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.theatreName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Code: ${t.theatreCode} • ID: ${t.id}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              _buildStatusBadge(t),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 14),
                  _buildDetailRow('Theatre Type', t.theatreType),
                  _buildDetailRow('Location / Floor', (t.location != null && t.location!.isNotEmpty) ? t.location! : 'Not specified'),
                  _buildDetailRow('Status Mode', t.status),
                  _buildDetailRow('Surgery Booking', t.isOperational ? 'Available for new scheduling' : 'Locked from new bookings'),
                  _buildDetailRow('Today\'s Surgeries', '${t.activeTodayCount} active/scheduled case(s)'),
                  if (t.createdAt != null)
                    _buildDetailRow('Created At', DateFormat('dd MMM yyyy, hh:mm a').format(t.createdAt!)),
                  if (t.updatedAt != null)
                    _buildDetailRow('Last Updated', DateFormat('dd MMM yyyy, hh:mm a').format(t.updatedAt!)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit Details'),
              onPressed: () {
                Navigator.pop(ctx);
                _showAddEditTheatreDialog(context, existing: t);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }

  // ─── ACTION HANDLERS ───────────────────────────────────────────────────────
  void _handleStatusChange(OperationTheatreModel t, String newStatus) async {
    if (newStatus == 'Delete') {
      _confirmDelete(t);
      return;
    }

    final res = await _controller.updateStatus(t.id, newStatus);
    if (mounted) {
      _showNotification(res['message'] ?? 'Status updated', isSuccess: res['success'] == true);
    }
  }

  void _confirmDelete(OperationTheatreModel t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 10),
            Text('Confirm Removal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete or deactivate theatre "${t.theatreName}" (${t.theatreCode})?\n\n'
          'If this theatre has linked surgeries, it will be safely deactivated to preserve surgical history.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _controller.deleteTheatre(t.id);
              if (mounted) {
                _showNotification(res['message'] ?? 'Theatre updated', isSuccess: res['success'] == true);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _handleSeedDefaults() async {
    final res = await _controller.seedDefaultTheatres();
    if (mounted) {
      _showNotification(res['message'] ?? 'Seeding complete', isSuccess: res['success'] == true);
    }
  }

  void _showNotification(String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

