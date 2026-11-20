import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../controllers/district_controller.dart';
import '../models/district_model.dart';
import '../utils/app_theme.dart';
import '../utils/discard_dialog_helper.dart';
import '../widgets/custom_dropdown_search.dart';

class RegionalAddressMasterScreen extends StatefulWidget {
  final bool isMobile;

  const RegionalAddressMasterScreen({
    super.key,
    this.isMobile = false,
  });

  @override
  State<RegionalAddressMasterScreen> createState() => _RegionalAddressMasterScreenState();
}

class _RegionalAddressMasterScreenState extends State<RegionalAddressMasterScreen>
    with SingleTickerProviderStateMixin {
  final DistrictController _controller = DistrictController();
  late TabController _tabController;

  // ─── DISTRICT MASTER STATE ──────────────────────────────────────────────────
  final TextEditingController _districtSearchCtrl = TextEditingController();
  String _districtSearchQuery = '';
  String _districtStatusFilter = 'All'; // 'All', 'Active', 'Inactive'
  int _districtCurrentPage = 1;
  int _districtRowsPerPage = 10;

  // ─── PIN CODE MASTER STATE ──────────────────────────────────────────────────
  final TextEditingController _pincodeSearchCtrl = TextEditingController();
  String _pincodeSearchQuery = '';
  String _pincodeDistrictFilter = 'All Districts';
  String _pincodeStatusFilter = 'All'; // 'All', 'Active', 'Inactive'
  int _pincodeCurrentPage = 1;
  int _pincodeRowsPerPage = 10;

  final List<int> _pageSizeOptions = [5, 10, 20, 50];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _loadData();
  }

  Future<void> _loadData({bool force = false}) async {
    await _controller.fetchDistricts(includeInactive: true, forceRefresh: force);
    await _controller.fetchAllPincodes(forceRefresh: force);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _districtSearchCtrl.dispose();
    _pincodeSearchCtrl.dispose();
    super.dispose();
  }

  // ─── FILTER LOGIC: DISTRICTS ────────────────────────────────────────────────
  List<DistrictModel> _getFilteredDistricts() {
    return _controller.districts.where((d) {
      if (_districtStatusFilter != 'All') {
        if (_districtStatusFilter == 'Active' && !d.isOperational) return false;
        if (_districtStatusFilter == 'Inactive' && d.isOperational) return false;
      }
      if (_districtSearchQuery.isNotEmpty) {
        final q = _districtSearchQuery.toLowerCase();
        final nameMatch = d.name.toLowerCase().contains(q);
        final codeMatch = (d.code ?? '').toLowerCase().contains(q);
        final stateMatch = d.state.toLowerCase().contains(q);
        if (!nameMatch && !codeMatch && !stateMatch) return false;
      }
      return true;
    }).toList();
  }

  List<DistrictModel> _getPaginatedDistricts(List<DistrictModel> filtered) {
    final start = (_districtCurrentPage - 1) * _districtRowsPerPage;
    if (start >= filtered.length) return [];
    final end = (start + _districtRowsPerPage).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  // ─── FILTER LOGIC: PIN CODES ────────────────────────────────────────────────
  List<PincodeModel> _getFilteredPincodes() {
    return _controller.allPincodes.where((p) {
      if (_pincodeStatusFilter != 'All') {
        if (_pincodeStatusFilter == 'Active' && !p.isOperational) return false;
        if (_pincodeStatusFilter == 'Inactive' && p.isOperational) return false;
      }
      if (_pincodeDistrictFilter != 'All Districts') {
        if ((p.districtName ?? '').toLowerCase() != _pincodeDistrictFilter.toLowerCase()) {
          return false;
        }
      }
      if (_pincodeSearchQuery.isNotEmpty) {
        final q = _pincodeSearchQuery.toLowerCase();
        final pinMatch = p.pincode.contains(q);
        final poMatch = (p.postOfficeName ?? '').toLowerCase().contains(q);
        final distMatch = (p.districtName ?? '').toLowerCase().contains(q);
        if (!pinMatch && !poMatch && !distMatch) return false;
      }
      return true;
    }).toList();
  }

  List<PincodeModel> _getPaginatedPincodes(List<PincodeModel> filtered) {
    final start = (_pincodeCurrentPage - 1) * _pincodeRowsPerPage;
    if (start >= filtered.length) return [];
    final end = (start + _pincodeRowsPerPage).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final bool isNarrow = widget.isMobile || MediaQuery.of(context).size.width < 960;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final allDistricts = _controller.districts;
          final activeDistricts = allDistricts.where((d) => d.isOperational).length;
          final allPincodes = _controller.allPincodes;
          final activePincodes = allPincodes.where((p) => p.isOperational).length;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isNarrow ? 14.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── HEADER & ACTIONS ─────────────────────────────────────────
                _buildHeader(isNarrow),

                const SizedBox(height: 18),

                // ─── STAT CARDS ───────────────────────────────────────────────
                _buildStatCardsRow(
                  totalDistricts: allDistricts.length,
                  activeDistricts: activeDistricts,
                  totalPincodes: allPincodes.length,
                  activePincodes: activePincodes,
                ),

                const SizedBox(height: 20),

                // ─── NAVIGATION TABS ──────────────────────────────────────────
                _buildTabsBar(),

                const SizedBox(height: 16),

                // ─── ACTIVE TAB CONTENT ───────────────────────────────────────
                if (_tabController.index == 0)
                  _buildDistrictMasterSection(isNarrow)
                else
                  _buildPincodeMasterSection(isNarrow),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── HEADER WIDGET ──────────────────────────────────────────────────────────
  Widget _buildHeader(bool isNarrow) {
    final isDistrictTab = _tabController.index == 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryNarrow = constraints.maxWidth < 680;

        final titleAndSubtitle = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.map_rounded, size: 24, color: AppTheme.primaryColor),
                SizedBox(width: 10),
                Text(
                  'Regional Address Master',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Maintains standardized Tamil Nadu districts, including Namakkal, Salem and Erode, along with PIN codes. These pre-seeded lookup values are used in patient registration forms.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.35),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildHeaderBadge(
                  icon: Icons.storage_rounded,
                  label: 'Tables: districts, pincodes',
                  bgColor: const Color(0xFFF1F5F9),
                  textColor: const Color(0xFF334155),
                  borderColor: const Color(0xFFCBD5E1),
                ),
                _buildHeaderBadge(
                  icon: Icons.hub_rounded,
                  label: 'Type: System Lookup / Pre-seeded Data',
                  bgColor: const Color(0xFFEFF6FF),
                  textColor: const Color(0xFF1D4ED8),
                  borderColor: const Color(0xFFBFDBFE),
                ),
                _buildHeaderBadge(
                  icon: Icons.account_tree_rounded,
                  label: 'Location: System Database → DB Seeds / Lookup',
                  bgColor: const Color(0xFFF0FDF4),
                  textColor: const Color(0xFF15803D),
                  borderColor: const Color(0xFFBBF7D0),
                ),
              ],
            ),
          ],
        );

        final actionButtons = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // Seed default standard data
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: const Text('Seed Standard Data', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              onPressed: _handleSeedDefaults,
            ),
            // Primary Add button (Context-aware)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                isDistrictTab ? 'Add District' : 'Add PIN Code',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () {
                if (isDistrictTab) {
                  _showAddEditDistrictDialog(context);
                } else {
                  _showAddEditPincodeDialog(context);
                }
              },
            ),
          ],
        );

        if (isVeryNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleAndSubtitle,
              const SizedBox(height: 14),
              actionButtons,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleAndSubtitle),
            const SizedBox(width: 16),
            actionButtons,
          ],
        );
      },
    );
  }

  // ─── STAT CARDS ROW ─────────────────────────────────────────────────────────
  Widget _buildStatCardsRow({
    required int totalDistricts,
    required int activeDistricts,
    required int totalPincodes,
    required int activePincodes,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 600
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth < 1000
                ? (constraints.maxWidth - 36) / 4
                : (constraints.maxWidth - 48) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth.clamp(140.0, 320.0),
              child: _buildStatCard('Total Districts', '$totalDistricts', Icons.location_city_rounded, const Color(0xFF0284C7)),
            ),
            SizedBox(
              width: cardWidth.clamp(140.0, 320.0),
              child: _buildStatCard('Active Districts', '$activeDistricts', Icons.check_circle_outline_rounded, const Color(0xFF16A34A)),
            ),
            SizedBox(
              width: cardWidth.clamp(140.0, 320.0),
              child: _buildStatCard('Total PIN Codes', '$totalPincodes', Icons.pin_drop_rounded, const Color(0xFF7C3AED)),
            ),
            SizedBox(
              width: cardWidth.clamp(140.0, 320.0),
              child: _buildStatCard('Active PIN Codes', '$activePincodes', Icons.markunread_mailbox_rounded, const Color(0xFF0D9488)),
            ),
          ],
        );
      },
    );
  }

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

  Widget _buildHeaderBadge({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ─── TABS BAR ───────────────────────────────────────────────────────────────
  Widget _buildTabsBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
        indicatorColor: AppTheme.primaryColor,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: [
          Tab(
            child: Row(
              children: [
                const Icon(Icons.location_city_rounded, size: 17),
                const SizedBox(width: 8),
                const Text('District Master'),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: _tabController.index == 0 ? AppTheme.primaryColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_controller.districts.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _tabController.index == 0 ? AppTheme.primaryColor : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                const Icon(Icons.markunread_mailbox_rounded, size: 17),
                const SizedBox(width: 8),
                const Text('PIN Code Master'),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: _tabController.index == 1 ? AppTheme.primaryColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_controller.allPincodes.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _tabController.index == 1 ? AppTheme.primaryColor : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: DISTRICT MASTER TAB
  // ===========================================================================
  Widget _buildDistrictMasterSection(bool isNarrow) {
    final filtered = _getFilteredDistricts();
    final totalPages = (filtered.length / _districtRowsPerPage).ceil().clamp(1, 9999);
    if (_districtCurrentPage > totalPages) {
      _districtCurrentPage = totalPages;
    }
    final paginated = _getPaginatedDistricts(filtered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter toolbar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 620;

              final searchField = SizedBox(
                width: isVeryNarrow ? double.infinity : 300,
                height: 40,
                child: TextField(
                  controller: _districtSearchCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by district name or code...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _districtSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _districtSearchCtrl.clear();
                              setState(() {
                                _districtSearchQuery = '';
                                _districtCurrentPage = 1;
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryColor)),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _districtSearchQuery = val.trim();
                      _districtCurrentPage = 1;
                    });
                  },
                ),
              );

              final statusPills = Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDistrictFilterPill('All', 'All (${_controller.districts.length})'),
                    _buildDistrictFilterPill('Active', 'Active (${_controller.districts.where((d) => d.isOperational).length})'),
                    _buildDistrictFilterPill('Inactive', 'Inactive (${_controller.districts.where((d) => !d.isOperational).length})'),
                  ],
                ),
              );

              if (isVeryNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    statusPills,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  searchField,
                  const SizedBox(width: 12),
                  statusPills,
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        // Listing Table or Cards
        if (_controller.isLoadingDistricts && _controller.districts.isEmpty)
          _buildLoadingState('Loading Tamil Nadu districts...')
        else if (filtered.isEmpty)
          _buildEmptyState(
            icon: Icons.location_city_outlined,
            title: 'No Districts Found',
            subtitle: _districtSearchQuery.isNotEmpty
                ? 'No district matches "$_districtSearchQuery".'
                : 'No district records found in catalog.',
            action: OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh Data'),
              onPressed: () => _loadData(force: true),
            ),
          )
        else ...[
          if (isNarrow)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paginated.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) => _buildDistrictCard(paginated[idx]),
            )
          else
            _buildDistrictsTable(paginated),

          const SizedBox(height: 14),
          _buildPaginationBar(
            totalCount: filtered.length,
            totalPages: totalPages,
            currentPage: _districtCurrentPage,
            rowsPerPage: _districtRowsPerPage,
            itemLabel: 'districts',
            onPageChanged: (p) => setState(() => _districtCurrentPage = p),
            onRowsPerPageChanged: (r) => setState(() {
              _districtRowsPerPage = r;
              _districtCurrentPage = 1;
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildDistrictFilterPill(String filterValue, String label) {
    final isSelected = _districtStatusFilter == filterValue;
    return InkWell(
      onTap: () {
        setState(() {
          _districtStatusFilter = filterValue;
          _districtCurrentPage = 1;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

  Widget _buildDistrictsTable(List<DistrictModel> districts) {
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
                  dataRowMaxHeight: 56,
                  horizontalMargin: 20,
                  columnSpacing: 24,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('District Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                    DataColumn(label: Text('State', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                    DataColumn(label: Text('District Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                    DataColumn(label: Text('Linked PIN Codes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  ],
                  rows: districts.map((d) {
                    final isOp = d.isOperational;

                    return DataRow(
                      cells: [
                        // District Name
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.location_city_rounded, size: 16, color: Color(0xFF475569)),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                d.name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),

                        // State
                        DataCell(
                          Text(d.state, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                        ),

                        // District Code
                        DataCell(
                          d.code != null && d.code!.isNotEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    d.code!,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF1E293B)),
                                  ),
                                )
                              : const Text('—', style: TextStyle(color: Color(0xFF94A3B8))),
                        ),

                        // Linked PIN Codes
                        DataCell(
                          InkWell(
                            onTap: () {
                              setState(() {
                                _pincodeDistrictFilter = d.name;
                                _tabController.animateTo(1);
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.pin_drop_rounded, size: 13, color: Color(0xFF1D4ED8)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${d.pincodeCount} PIN codes',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Status Badge
                        DataCell(_buildStatusBadge(isOp)),

                        // Actions
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0284C7)),
                                tooltip: 'View Details',
                                onPressed: () => _showDistrictDetailsDialog(d),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                                tooltip: 'Edit District',
                                onPressed: () => _showAddEditDistrictDialog(context, existing: d),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                                tooltip: 'More Options',
                                onSelected: (val) {
                                  if (val == 'toggle') {
                                    _handleToggleDistrictStatus(d);
                                  } else if (val == 'delete') {
                                    _handleDeleteDistrict(d);
                                  } else if (val == 'view_pins') {
                                    setState(() {
                                      _pincodeDistrictFilter = d.name;
                                      _tabController.animateTo(1);
                                    });
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'view_pins',
                                    child: Row(
                                      children: const [
                                        Icon(Icons.pin_drop_rounded, size: 16, color: Color(0xFF0284C7)),
                                        SizedBox(width: 8),
                                        Text('View Linked PIN Codes', style: TextStyle(fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Row(
                                      children: [
                                        Icon(isOp ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                                            size: 16, color: isOp ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                                        const SizedBox(width: 8),
                                        Text(isOp ? 'Deactivate' : 'Activate', style: const TextStyle(fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                        SizedBox(width: 8),
                                        Text('Delete District', style: TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
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

  Widget _buildDistrictCard(DistrictModel d) {
    final isOp = d.isOperational;

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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.location_city_rounded, size: 16, color: Color(0xFF475569)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  d.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                ),
              ),
              _buildStatusBadge(isOp),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('State: ${d.state}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              if (d.code != null && d.code!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text('Code: ${d.code}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _pincodeDistrictFilter = d.name;
                    _tabController.animateTo(1);
                  });
                },
                child: Text(
                  '${d.pincodeCount} PIN codes linked →',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
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
                    onPressed: () => _showDistrictDetailsDialog(d),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Edit District',
                    onPressed: () => _showAddEditDistrictDialog(context, existing: d),
                  ),
                  IconButton(
                    icon: Icon(isOp ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                        size: 18, color: isOp ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: isOp ? 'Deactivate' : 'Activate',
                    onPressed: () => _handleToggleDistrictStatus(d),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 2: PIN CODE MASTER TAB
  // ===========================================================================
  Widget _buildPincodeMasterSection(bool isNarrow) {
    final filtered = _getFilteredPincodes();
    final totalPages = (filtered.length / _pincodeRowsPerPage).ceil().clamp(1, 9999);
    if (_pincodeCurrentPage > totalPages) {
      _pincodeCurrentPage = totalPages;
    }
    final paginated = _getPaginatedPincodes(filtered);

    // List of district names for dropdown filter
    final districtOptions = ['All Districts', ..._controller.districts.map((d) => d.name).toList()];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter Toolbar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 750;

              final searchField = SizedBox(
                width: isVeryNarrow ? double.infinity : 260,
                height: 40,
                child: TextField(
                  controller: _pincodeSearchCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search PIN, post office, or district...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _pincodeSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _pincodeSearchCtrl.clear();
                              setState(() {
                                _pincodeSearchQuery = '';
                                _pincodeCurrentPage = 1;
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryColor)),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _pincodeSearchQuery = val.trim();
                      _pincodeCurrentPage = 1;
                    });
                  },
                ),
              );

              final districtDropdown = SizedBox(
                width: isVeryNarrow ? double.infinity : 200,
                child: CustomDropdownSearch(
                  label: 'Filter by District',
                  hint: 'Select district',
                  dropdownItems: districtOptions,
                  value: _pincodeDistrictFilter,
                  height: 40,
                  fillColor: const Color(0xFFF8FAFC),
                  borderColor: const Color(0xFFCBD5E1),
                  onChanged: (val) {
                    setState(() {
                      _pincodeDistrictFilter = val ?? 'All Districts';
                      _pincodeCurrentPage = 1;
                    });
                  },
                ),
              );

              final statusPills = Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPincodeFilterPill('All', 'All (${_controller.allPincodes.length})'),
                    _buildPincodeFilterPill('Active', 'Active (${_controller.allPincodes.where((p) => p.isOperational).length})'),
                    _buildPincodeFilterPill('Inactive', 'Inactive (${_controller.allPincodes.where((p) => !p.isOperational).length})'),
                  ],
                ),
              );

              if (isVeryNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    districtDropdown,
                    const SizedBox(height: 10),
                    statusPills,
                  ],
                );
              }

              return Row(
                children: [
                  searchField,
                  const SizedBox(width: 10),
                  districtDropdown,
                  const Spacer(),
                  statusPills,
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        // Listing Table or Cards
        if (_controller.isLoadingPincodes && _controller.allPincodes.isEmpty)
          _buildLoadingState('Loading PIN codes catalog...')
        else if (filtered.isEmpty)
          _buildEmptyState(
            icon: Icons.markunread_mailbox_outlined,
            title: 'No PIN Codes Found',
            subtitle: _pincodeSearchQuery.isNotEmpty || _pincodeDistrictFilter != 'All Districts'
                ? 'No PIN codes match the selected search or filter criteria.'
                : 'No PIN codes registered in the system yet.',
            action: Wrap(
              spacing: 8,
              children: [
                if (_pincodeDistrictFilter != 'All Districts' || _pincodeSearchQuery.isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Reset Filters'),
                    onPressed: () {
                      _pincodeSearchCtrl.clear();
                      setState(() {
                        _pincodeSearchQuery = '';
                        _pincodeDistrictFilter = 'All Districts';
                        _pincodeStatusFilter = 'All';
                        _pincodeCurrentPage = 1;
                      });
                    },
                  ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add PIN Code'),
                  onPressed: () => _showAddEditPincodeDialog(context),
                ),
              ],
            ),
          )
        else ...[
          if (isNarrow)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paginated.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) => _buildPincodeCard(paginated[idx]),
            )
          else
            _buildPincodesTable(paginated),

          const SizedBox(height: 14),
          _buildPaginationBar(
            totalCount: filtered.length,
            totalPages: totalPages,
            currentPage: _pincodeCurrentPage,
            rowsPerPage: _pincodeRowsPerPage,
            itemLabel: 'PIN codes',
            onPageChanged: (p) => setState(() => _pincodeCurrentPage = p),
            onRowsPerPageChanged: (r) => setState(() {
              _pincodeRowsPerPage = r;
              _pincodeCurrentPage = 1;
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildPincodeFilterPill(String filterValue, String label) {
    final isSelected = _pincodeStatusFilter == filterValue;
    return InkWell(
      onTap: () {
        setState(() {
          _pincodeStatusFilter = filterValue;
          _pincodeCurrentPage = 1;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

  Widget _buildPincodesTable(List<PincodeModel> pincodes) {
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
                  dataRowMaxHeight: 56,
                  horizontalMargin: 20,
                  columnSpacing: 24,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('PIN Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                    DataColumn(label: Text('Post Office / Area', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                    DataColumn(label: Text('Mapped District', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                    DataColumn(label: Text('State', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  ],
                  rows: pincodes.map((p) {
                    final isOp = p.isOperational;

                    return DataRow(
                      cells: [
                        // PIN Code
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.pin_drop_rounded, size: 14, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 4),
                                    Text(
                                      p.pincode,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Post Office Name
                        DataCell(
                          Text(
                            (p.postOfficeName != null && p.postOfficeName!.isNotEmpty)
                                ? p.postOfficeName!
                                : 'General / Main',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                          ),
                        ),

                        // Mapped District
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_city_rounded, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                p.districtName ?? '—',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),

                        // State
                        DataCell(
                          Text(p.districtState ?? 'Tamil Nadu', style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                        ),

                        // Status Badge
                        DataCell(_buildStatusBadge(isOp)),

                        // Actions
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0284C7)),
                                tooltip: 'View Details',
                                onPressed: () => _showPincodeDetailsDialog(p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                                tooltip: 'Edit PIN Code',
                                onPressed: () => _showAddEditPincodeDialog(context, existing: p),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                                tooltip: 'More Options',
                                onSelected: (val) {
                                  if (val == 'toggle') {
                                    _handleTogglePincodeStatus(p);
                                  } else if (val == 'delete') {
                                    _handleDeletePincode(p);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Row(
                                      children: [
                                        Icon(isOp ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                                            size: 16, color: isOp ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                                        const SizedBox(width: 8),
                                        Text(isOp ? 'Deactivate' : 'Activate', style: const TextStyle(fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                        SizedBox(width: 8),
                                        Text('Delete PIN Code', style: TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
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

  Widget _buildPincodeCard(PincodeModel p) {
    final isOp = p.isOperational;

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
                child: Text(p.pincode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.postOfficeName ?? 'General / Main Post Office',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusBadge(isOp),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_city_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'District: ${p.districtName ?? "—"} (${p.districtState ?? "Tamil Nadu"})',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0284C7)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'View Details',
                onPressed: () => _showPincodeDetailsDialog(p),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Edit PIN Code',
                onPressed: () => _showAddEditPincodeDialog(context, existing: p),
              ),
              IconButton(
                icon: Icon(isOp ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                    size: 18, color: isOp ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: isOp ? 'Deactivate' : 'Activate',
                onPressed: () => _handleTogglePincodeStatus(p),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── STATUS BADGE ────────────────────────────────────────────────────────────
  Widget _buildStatusBadge(bool isOp) {
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

  // ─── PAGINATION BAR ──────────────────────────────────────────────────────────
  Widget _buildPaginationBar({
    required int totalCount,
    required int totalPages,
    required int currentPage,
    required int rowsPerPage,
    required String itemLabel,
    required ValueChanged<int> onPageChanged,
    required ValueChanged<int> onRowsPerPageChanged,
  }) {
    final start = totalCount == 0 ? 0 : (currentPage - 1) * rowsPerPage + 1;
    final end = (currentPage * rowsPerPage).clamp(0, totalCount);

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
            'Showing $start to $end of $totalCount $itemLabel',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          );

          final pageSizeWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Per page:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(width: 6),
              DropdownButton<int>(
                value: rowsPerPage,
                isDense: true,
                underline: const SizedBox.shrink(),
                style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                items: _pageSizeOptions.map((sz) => DropdownMenuItem(value: sz, child: Text('$sz'))).toList(),
                onChanged: (val) {
                  if (val != null) onRowsPerPageChanged(val);
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
                color: const Color(0xFF475569),
                disabledColor: const Color(0xFFCBD5E1),
                tooltip: 'Previous Page',
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: const Color(0xFF475569),
                disabledColor: const Color(0xFFCBD5E1),
                tooltip: 'Next Page',
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
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

  Widget _buildLoadingState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            action,
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // DIALOGS & ACTIONS: SEED DATA
  // ===========================================================================
  Future<void> _handleSeedDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Seed Standard Tamil Nadu Data'),
          ],
        ),
        content: const Text(
          'This will populate or update all 38 standardized Tamil Nadu districts and verified India Post PIN codes into the catalog.\n\nExisting records will not be duplicated. Do you want to continue?',
          style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Seed Standard Data'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await _controller.seedDefaults();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? 'Seeding completed.'),
        backgroundColor: result['success'] == true ? const Color(0xFF16A34A) : AppTheme.dangerColor,
      ),
    );
  }

  // ===========================================================================
  // DIALOGS & ACTIONS: DISTRICT CRUD
  // ===========================================================================
  Future<void> _showAddEditDistrictDialog(BuildContext context, {DistrictModel? existing}) async {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: existing?.name ?? '');
    final stateController = TextEditingController(text: existing?.state ?? 'Tamil Nadu');
    final codeController = TextEditingController(text: existing?.code ?? '');
    String status = existing?.status ?? 'Active';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(isEdit ? Icons.edit_location_alt_rounded : Icons.add_location_alt_rounded,
                        color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit District' : 'Add New District',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // District Name
                        const Text('District Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'e.g. Namakkal, Salem, Erode',
                            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryColor)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'District name is required';
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        // State
                        const Text('State *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: stateController,
                          decoration: InputDecoration(
                            hintText: 'Tamil Nadu',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryColor)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'State is required';
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        // District Code (Optional)
                        const Text('District Code (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: codeController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(10),
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                          ],
                          decoration: InputDecoration(
                            hintText: 'e.g. NMK, SLM, ERD',
                            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryColor)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Status (CustomDropdownSearch)
                        CustomDropdownSearch(
                          label: 'Status *',
                          hint: 'Select status',
                          dropdownItems: const ['Active', 'Inactive'],
                          value: status,
                          height: 44,
                          fillColor: const Color(0xFFF8FAFC),
                          borderColor: const Color(0xFFCBD5E1),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => status = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    Navigator.of(ctx).pop();

                    Map<String, dynamic> res;
                    if (isEdit) {
                      res = await _controller.updateDistrict(
                        id: existing.id,
                        name: nameController.text.trim(),
                        state: stateController.text.trim(),
                        code: codeController.text.trim().isNotEmpty ? codeController.text.trim().toUpperCase() : null,
                        status: status,
                      );
                    } else {
                      res = await _controller.createDistrict(
                        name: nameController.text.trim(),
                        state: stateController.text.trim(),
                        code: codeController.text.trim().isNotEmpty ? codeController.text.trim().toUpperCase() : null,
                        status: status,
                      );
                    }

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? (isEdit ? 'District updated' : 'District created')),
                        backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : AppTheme.dangerColor,
                      ),
                    );
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Create District'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleToggleDistrictStatus(DistrictModel d) async {
    final nextStatus = d.isOperational ? 'Inactive' : 'Active';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${nextStatus == "Inactive" ? "Deactivate" : "Activate"} District'),
        content: Text(
          'Are you sure you want to mark "${d.name}" as $nextStatus?'
          '${nextStatus == "Inactive" ? "\n\nInactive districts will not appear in new patient registration lookups." : ""}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: nextStatus == 'Inactive' ? const Color(0xFFD97706) : const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(nextStatus == 'Inactive' ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await _controller.toggleDistrictStatus(d.id, d.status);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message'] ?? 'Status updated'),
        backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : AppTheme.dangerColor,
      ),
    );
  }

  Future<void> _handleDeleteDistrict(DistrictModel d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete District', style: TextStyle(color: Color(0xFFDC2626))),
        content: Text(
          'Are you sure you want to permanently delete "${d.name}"?'
          '\n\nThis will also remove any PIN codes directly mapped to this district. This action cannot be undone.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete District'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await _controller.deleteDistrict(d.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message'] ?? 'District deleted'),
        backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : AppTheme.dangerColor,
      ),
    );
  }

  void _showDistrictDetailsDialog(DistrictModel d) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_city_rounded, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                d.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
              ),
            ),
            _buildStatusBadge(d.isOperational),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('District ID', '${d.id}'),
                _buildDetailRow('State', d.state),
                _buildDetailRow('District Code', d.code ?? 'None configured'),
                _buildDetailRow('Linked PIN Codes', '${d.pincodeCount} PIN codes in catalog'),
                if (d.createdAt != null)
                  _buildDetailRow('Created At', DateFormat('dd MMM yyyy, hh:mm a').format(d.createdAt!)),
                if (d.updatedAt != null)
                  _buildDetailRow('Last Updated', DateFormat('dd MMM yyyy, hh:mm a').format(d.updatedAt!)),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.pin_drop_rounded, size: 16),
            label: const Text('View PIN Codes'),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _pincodeDistrictFilter = d.name;
                _tabController.animateTo(1);
              });
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DIALOGS & ACTIONS: PIN CODE CRUD
  // ===========================================================================
  Future<void> _showAddEditPincodeDialog(BuildContext context, {PincodeModel? existing}) async {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();

    // District options for selection
    final districtList = _controller.districts;
    if (districtList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No districts available. Please seed or add a district first.')),
      );
      return;
    }

    String selectedDistrictName = existing?.districtName ??
        (_pincodeDistrictFilter != 'All Districts' ? _pincodeDistrictFilter : districtList.first.name);

    final pincodeController = TextEditingController(text: existing?.pincode ?? '');
    final poController = TextEditingController(text: existing?.postOfficeName ?? '');
    String status = existing?.status ?? 'Active';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(isEdit ? Icons.edit_location_rounded : Icons.add_location_rounded,
                        color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit PIN Code' : 'Add New PIN Code',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // District Selection (CustomDropdownSearch)
                        CustomDropdownSearch(
                          label: 'District *',
                          hint: 'Select district',
                          dropdownItems: districtList.map((d) => d.name).toList(),
                          value: selectedDistrictName,
                          height: 44,
                          fillColor: const Color(0xFFF8FAFC),
                          borderColor: const Color(0xFFCBD5E1),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedDistrictName = val);
                            }
                          },
                        ),

                        const SizedBox(height: 14),

                        // PIN Code
                        const Text('6-Digit PIN Code *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: pincodeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: InputDecoration(
                            hintText: 'e.g. 637001',
                            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryColor)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'PIN code is required';
                            if (!RegExp(r'^\d{6}$').hasMatch(val.trim())) {
                              return 'PIN code must be exactly 6 digits';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        // Post Office Name
                        const Text('Post Office / Area Name (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: poController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'e.g. Namakkal H.O, Gandhipuram S.O',
                            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryColor)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Status (CustomDropdownSearch)
                        CustomDropdownSearch(
                          label: 'Status *',
                          hint: 'Select status',
                          dropdownItems: const ['Active', 'Inactive'],
                          value: status,
                          height: 44,
                          fillColor: const Color(0xFFF8FAFC),
                          borderColor: const Color(0xFFCBD5E1),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => status = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final targetDistrict = districtList.firstWhere(
                      (d) => d.name.toLowerCase() == selectedDistrictName.toLowerCase(),
                      orElse: () => districtList.first,
                    );

                    Navigator.of(ctx).pop();

                    Map<String, dynamic> res;
                    if (isEdit) {
                      res = await _controller.updatePincode(
                        id: existing.id,
                        districtId: targetDistrict.id,
                        pincode: pincodeController.text.trim(),
                        postOfficeName: poController.text.trim().isNotEmpty ? poController.text.trim() : null,
                        status: status,
                      );
                    } else {
                      res = await _controller.createPincode(
                        districtId: targetDistrict.id,
                        pincode: pincodeController.text.trim(),
                        postOfficeName: poController.text.trim().isNotEmpty ? poController.text.trim() : null,
                        status: status,
                      );
                    }

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? (isEdit ? 'PIN code updated' : 'PIN code created')),
                        backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : AppTheme.dangerColor,
                      ),
                    );
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Create PIN Code'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleTogglePincodeStatus(PincodeModel p) async {
    final nextStatus = p.isOperational ? 'Inactive' : 'Active';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${nextStatus == "Inactive" ? "Deactivate" : "Activate"} PIN Code'),
        content: Text(
          'Are you sure you want to mark PIN code "${p.pincode}" as $nextStatus?'
          '${nextStatus == "Inactive" ? "\n\nInactive PIN codes will not be suggested during patient address entry." : ""}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: nextStatus == 'Inactive' ? const Color(0xFFD97706) : const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(nextStatus == 'Inactive' ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await _controller.togglePincodeStatus(p.id, p.status);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message'] ?? 'Status updated'),
        backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : AppTheme.dangerColor,
      ),
    );
  }

  Future<void> _handleDeletePincode(PincodeModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete PIN Code', style: TextStyle(color: Color(0xFFDC2626))),
        content: Text(
          'Are you sure you want to delete PIN code "${p.pincode}" (${p.postOfficeName ?? p.districtName})?'
          '\n\nThis will remove the mapping from Regional Address Master. This action cannot be undone.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete PIN Code'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await _controller.deletePincode(p.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message'] ?? 'PIN code deleted'),
        backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : AppTheme.dangerColor,
      ),
    );
  }

  void _showPincodeDetailsDialog(PincodeModel p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.markunread_mailbox_rounded, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'PIN Code: ${p.pincode}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
              ),
            ),
            _buildStatusBadge(p.isOperational),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Record ID', '${p.id}'),
                _buildDetailRow('6-Digit PIN', p.pincode),
                _buildDetailRow('Post Office / Area', (p.postOfficeName != null && p.postOfficeName!.isNotEmpty) ? p.postOfficeName! : 'General / Main'),
                _buildDetailRow('Mapped District', p.districtName ?? 'District ID #${p.districtId}'),
                _buildDetailRow('State', p.districtState ?? 'Tamil Nadu'),
                _buildDetailRow('Display Label', p.displayLabel),
                if (p.createdAt != null)
                  _buildDetailRow('Created At', DateFormat('dd MMM yyyy, hh:mm a').format(p.createdAt!)),
                if (p.updatedAt != null)
                  _buildDetailRow('Last Updated', DateFormat('dd MMM yyyy, hh:mm a').format(p.updatedAt!)),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}

