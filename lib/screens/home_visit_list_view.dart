import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../models/home_visit_model.dart';
import '../models/patient_model.dart';
import '../controllers/home_visit_controller.dart';
import '../controllers/patient_controller.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/custom_dropdown_search.dart';

class HomeVisitListView extends StatefulWidget {
  final Function(int visitId)? onExecuteVisit;
  final Function(int visitId)? onViewSummary;
  final bool showScheduleButton;
  final bool showExecuteButton;
  final bool showHeader;

  const HomeVisitListView({
    super.key,
    this.onExecuteVisit,
    this.onViewSummary,
    this.showScheduleButton = true,
    this.showExecuteButton = true,
    this.showHeader = false,
  });

  @override
  State<HomeVisitListView> createState() => _HomeVisitListViewState();
}

class _HomeVisitListViewState extends State<HomeVisitListView> {
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _dateFilterType = 'All Dates';
  DateTime? _selectedCustomDate;
  int _currentPage = 1;
  int _itemsPerPage = 10;
  List<PatientModel> _patientsList = [];
  bool _isLoadingPatients = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HomeVisitController>(context, listen: false).fetchVisits();
      _fetchPatients();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPatients() async {
    setState(() => _isLoadingPatients = true);
    try {
      final list = await PatientController().fetchPatients();
      if (mounted) {
        setState(() {
          _patientsList = list;
          _isLoadingPatients = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPatients = false);
    }
  }

  String _normalizeDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    final clean = dateStr.trim().split('T')[0].split(' ')[0];
    final parts = clean.split('-');
    if (parts.length == 3) {
      if (parts[0].length == 4) return clean;
      return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
    }
    return dateStr;
  }

  Widget _buildSummaryCards(List<HomeVisitModel> allVisits) {
    final totalCount = allVisits.length;
    final scheduledCount = allVisits.where((v) => v.status.toLowerCase() == 'scheduled').length;
    final inProgressCount = allVisits.where((v) => v.status.toLowerCase() == 'in-progress').length;
    final completedCount = allVisits.where((v) => v.status.toLowerCase() == 'completed' || v.status.toLowerCase() == 'verified').length;

    Widget buildStatCard(String title, int count, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  buildStatCard('Total Visits', totalCount, Icons.home_work_outlined, AppTheme.primaryColor),
                  const SizedBox(width: 10),
                  buildStatCard('Scheduled', scheduledCount, Icons.calendar_today_outlined, Colors.orange),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  buildStatCard('In-Progress', inProgressCount, Icons.hourglass_top_outlined, Colors.blue),
                  const SizedBox(width: 10),
                  buildStatCard('Completed', completedCount, Icons.check_circle_outline, Colors.green),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            buildStatCard('Total Visits', totalCount, Icons.home_work_outlined, AppTheme.primaryColor),
            const SizedBox(width: 12),
            buildStatCard('Scheduled', scheduledCount, Icons.calendar_today_outlined, Colors.orange),
            const SizedBox(width: 12),
            buildStatCard('In-Progress', inProgressCount, Icons.hourglass_top_outlined, Colors.blue),
            const SizedBox(width: 12),
            buildStatCard('Completed', completedCount, Icons.check_circle_outline, Colors.green),
          ],
        );
      },
    );
  }

  Widget _buildSearchAndDateFilterBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final searchField = SizedBox(
          width: isMobile ? double.infinity : 340,
          height: 42,
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _currentPage = 1;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search patient, nurse, visit #...',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
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
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
          ),
        );

        final dateFilters = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All Dates', style: TextStyle(fontSize: 12)),
                selected: _dateFilterType == 'All Dates',
                selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: _dateFilterType == 'All Dates' ? AppTheme.primaryColor : Colors.black87,
                  fontWeight: _dateFilterType == 'All Dates' ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _dateFilterType = 'All Dates';
                      _selectedCustomDate = null;
                      _currentPage = 1;
                    });
                  }
                },
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Today', style: TextStyle(fontSize: 12)),
                selected: _dateFilterType == 'Today',
                selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: _dateFilterType == 'Today' ? AppTheme.primaryColor : Colors.black87,
                  fontWeight: _dateFilterType == 'Today' ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _dateFilterType = 'Today';
                      _selectedCustomDate = null;
                      _currentPage = 1;
                    });
                  }
                },
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Tomorrow', style: TextStyle(fontSize: 12)),
                selected: _dateFilterType == 'Tomorrow',
                selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: _dateFilterType == 'Tomorrow' ? AppTheme.primaryColor : Colors.black87,
                  fontWeight: _dateFilterType == 'Tomorrow' ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _dateFilterType = 'Tomorrow';
                      _selectedCustomDate = null;
                      _currentPage = 1;
                    });
                  }
                },
              ),
              const SizedBox(width: 6),
              ActionChip(
                avatar: Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: _dateFilterType == 'Custom' ? AppTheme.primaryColor : Colors.grey,
                ),
                label: Text(
                  _selectedCustomDate != null
                      ? DateFormat('dd-MM-yyyy').format(_selectedCustomDate!)
                      : 'Pick Date',
                  style: TextStyle(
                    fontSize: 12,
                    color: _dateFilterType == 'Custom' ? AppTheme.primaryColor : Colors.black87,
                    fontWeight: _dateFilterType == 'Custom' ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                backgroundColor: _dateFilterType == 'Custom'
                    ? AppTheme.primaryColor.withOpacity(0.15)
                    : Colors.white,
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedCustomDate ?? DateTime.now(),
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      _dateFilterType = 'Custom';
                      _selectedCustomDate = picked;
                      _currentPage = 1;
                    });
                  }
                },
              ),
              if (_dateFilterType != 'All Dates') ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.cancel, size: 18, color: Colors.grey),
                  tooltip: 'Reset date filter',
                  onPressed: () {
                    setState(() {
                      _dateFilterType = 'All Dates';
                      _selectedCustomDate = null;
                      _currentPage = 1;
                    });
                  },
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                tooltip: 'Refresh visits',
                onPressed: () {
                  Provider.of<HomeVisitController>(context, listen: false).fetchVisits();
                  _fetchPatients();
                },
              ),
            ],
          ),
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              searchField,
              const SizedBox(height: 10),
              dateFilters,
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            searchField,
            dateFilters,
          ],
        );
      },
    );
  }

  Widget _buildPaginationBar(int totalVisits, int totalPages, int startIndex, int endIndex) {
    if (totalVisits == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          if (isMobile) {
            return Column(
              children: [
                Text(
                  'Showing ${startIndex + 1} to $endIndex of $totalVisits visits',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                    ),
                    Text('Page $_currentPage of $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                    ),
                  ],
                ),
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${startIndex + 1} to $endIndex of $totalVisits visits',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  const Text('Rows per page: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  DropdownButton<int>(
                    value: _itemsPerPage,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor, fontWeight: FontWeight.bold),
                    items: [5, 10, 20, 50].map((int val) {
                      return DropdownMenuItem<int>(
                        value: val,
                        child: Text('$val'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _itemsPerPage = val;
                          _currentPage = 1;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                  ),
                  Text('Page $_currentPage of $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeVisitController>(
      builder: (context, controller, child) {
        List<HomeVisitModel> visits = controller.visits;

        // 0. Filter by assigned Nurse if user is a Nurse
        final authUser = Provider.of<AuthProvider>(context, listen: false).user;
        if (authUser != null && authUser.role == 'Nurse') {
          visits = visits.where((v) {
            final isNurseIdMatch = v.nurseId != null && v.nurseId == authUser.id;
            final isNurseNameMatch = v.nurseName != null &&
                v.nurseName!.toLowerCase().contains(authUser.fullname.toLowerCase());
            final isStartNurseNameMatch = v.startNurseName != null &&
                v.startNurseName!.toLowerCase().contains(authUser.fullname.toLowerCase());
            return isNurseIdMatch || isNurseNameMatch || isStartNurseNameMatch;
          }).toList();
        }

        final List<HomeVisitModel> allVisits = List.from(visits);

        // 1. Search Query Filter
        if (_searchQuery.trim().isNotEmpty) {
          final query = _searchQuery.toLowerCase().trim();
          visits = visits.where((v) {
            final pName = (v.patientName ?? '').toLowerCase();
            final pId = (v.patientDisplayId ?? '').toLowerCase();
            final vNum = v.visitNumber.toLowerCase();
            final nName = (v.nurseName ?? '').toLowerCase();
            final addr = (v.visitAddress ?? '').toLowerCase();
            return pName.contains(query) || pId.contains(query) || vNum.contains(query) || nName.contains(query) || addr.contains(query);
          }).toList();
        }

        // 2. Status Filter
        if (_selectedStatusFilter != 'All') {
          if (_selectedStatusFilter == 'Completed') {
            visits = visits
                .where((v) => v.status.toLowerCase() == 'completed' || v.status.toLowerCase() == 'verified')
                .toList();
          } else {
            visits = visits
                .where((v) => v.status.toLowerCase() == _selectedStatusFilter.toLowerCase())
                .toList();
          }
        }

        // 3. Date Filter
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        final tomorrowStr = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));

        if (_dateFilterType == 'Today') {
          visits = visits.where((v) => _normalizeDate(v.scheduledDate) == todayStr).toList();
        } else if (_dateFilterType == 'Tomorrow') {
          visits = visits.where((v) => _normalizeDate(v.scheduledDate) == tomorrowStr).toList();
        } else if (_dateFilterType == 'Custom' && _selectedCustomDate != null) {
          final customStr = DateFormat('yyyy-MM-dd').format(_selectedCustomDate!);
          visits = visits.where((v) => _normalizeDate(v.scheduledDate) == customStr).toList();
        }

        // 4. Pagination
        final int totalVisits = visits.length;
        final int totalPages = totalVisits == 0 ? 1 : (totalVisits / _itemsPerPage).ceil();
        final int validCurrentPage = _currentPage > totalPages ? totalPages : (_currentPage < 1 ? 1 : _currentPage);
        final int startIndex = totalVisits == 0 ? 0 : (validCurrentPage - 1) * _itemsPerPage;
        final int endIndex = (startIndex + _itemsPerPage) > totalVisits ? totalVisits : (startIndex + _itemsPerPage);

        final List<HomeVisitModel> paginatedVisits = totalVisits == 0
            ? []
            : visits.sublist(startIndex, endIndex);

        return Container(
          color: AppTheme.backgroundColor,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header — responsive (only if widget.showHeader is true)
              if (widget.showHeader) ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.home_work_outlined, color: AppTheme.primaryColor, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Home Visit Care & Services',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimaryColor,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    Text(
                                      'Manage patient home care & billing',
                                      style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Inter'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                                tooltip: 'Refresh visits',
                                onPressed: () {
                                  Provider.of<HomeVisitController>(context, listen: false).fetchVisits();
                                  _fetchPatients();
                                },
                              ),
                              if (widget.showScheduleButton) ...[
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 36,
                                  child: ElevatedButton.icon(
                                    style: AppTheme.dangerButton,
                                    icon: const Icon(Icons.add, color: Colors.white, size: 15),
                                    label: const Text(
                                      'Schedule Home Visit',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                    ),
                                    onPressed: () => _showScheduleVisitDialog(context),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.home_work_outlined, color: AppTheme.primaryColor, size: 28),
                              ),
                              const SizedBox(width: 14),
                              const Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Home Visit Care & Services',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimaryColor,
                                        fontFamily: 'Inter',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Manage patient home care, vitals, dressing & attender billing',
                                      style: TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Inter'),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                              tooltip: 'Refresh visits',
                              onPressed: () {
                                Provider.of<HomeVisitController>(context, listen: false).fetchVisits();
                                _fetchPatients();
                              },
                            ),
                            if (widget.showScheduleButton) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 36,
                                child: ElevatedButton.icon(
                                  style: AppTheme.dangerButton,
                                  icon: const Icon(Icons.add, color: Colors.white, size: 15),
                                  label: const Text(
                                    'Schedule Home Visit',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                  ),
                                  onPressed: () => _showScheduleVisitDialog(context),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Summary Stat Cards
              _buildSummaryCards(allVisits),
              const SizedBox(height: 20),

              // Search & Date Filter Bar
              _buildSearchAndDateFilterBar(),
              const SizedBox(height: 16),

              // Filter Chips Row (Status)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Scheduled', 'In-Progress', 'Completed', 'Cancelled'].map((status) {
                    final isSelected = _selectedStatusFilter == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(status, style: TextStyle(color: isSelected ? Colors.white : AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryColor,
                        backgroundColor: Colors.white,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedStatusFilter = status;
                              _currentPage = 1;
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Content Body
              Expanded(
                child: controller.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                    : controller.errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: AppTheme.dangerColor),
                                const SizedBox(height: 12),
                                Text(
                                  controller.errorMessage!,
                                  style: const TextStyle(fontSize: 14, color: AppTheme.dangerColor),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: AppTheme.primaryButton,
                                  onPressed: () {
                                    Provider.of<HomeVisitController>(context, listen: false).fetchVisits();
                                    _fetchPatients();
                                  },
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Retry Loading Visits'),
                                ),
                              ],
                            ),
                          )
                        : paginatedVisits.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(40),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.home_work, size: 48, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text(
                                      'No home visits found matching search or filter.',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: paginatedVisits.length,
                                itemBuilder: (context, idx) {
                                  final visit = paginatedVisits[idx];
                                  return _buildVisitCard(context, visit);
                                },
                              ),
              ),

              // Pagination Controls
              _buildPaginationBar(totalVisits, totalPages, startIndex, endIndex),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisitCard(BuildContext context, HomeVisitModel visit) {
    final bool canExecute = _isExecuteButtonEnabled(visit);

    String effectiveStatus = visit.status == 'Verified' ? 'Completed' : visit.status;
    if (canExecute && (visit.status == 'Verified' || visit.status == 'Completed')) {
      effectiveStatus = 'Scheduled';
    }

    final now = DateTime.now();
    final todayFormatted = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
    final String displayDate = (effectiveStatus == 'Scheduled' && canExecute) ? todayFormatted : visit.formattedScheduledDate;

    Color badgeBg = const Color(0xFFDBEAFE);
    Color badgeText = const Color(0xFF1E40AF);

    if (effectiveStatus == 'In-Progress') {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFF92400E);
    } else if (effectiveStatus == 'Verified' || effectiveStatus == 'Completed') {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF166534);
    } else if (effectiveStatus == 'Cancelled') {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFF991B1B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 560;

          // Reusable execute button builder
          Widget buildExecuteBtn({bool expanded = false}) => Builder(
            builder: (context) {
              final bool canExecute = _isExecuteButtonEnabled(visit);
              final bool isInProgress = visit.status.toLowerCase() == 'in-progress' || effectiveStatus.toLowerCase() == 'in-progress';
              final String btnText = isInProgress ? 'Resume Visit' : 'Execute Visit';
              final IconData btnIcon = isInProgress ? Icons.play_arrow_outlined : (canExecute ? Icons.medical_services_outlined : Icons.lock_clock_outlined);

              final btn = ElevatedButton.icon(
                style: canExecute
                    ? AppTheme.dangerButton
                    : ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCBD5E1),
                        foregroundColor: const Color(0xFF64748B),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                icon: Icon(btnIcon, size: 15),
                label: Text(
                  btnText,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: canExecute ? Colors.white : const Color(0xFF64748B)),
                ),
                onPressed: canExecute
                    ? () => _onExecuteVisitPressed(context, visit)
                    : () {
                        final String displayTime = (visit.scheduledTime == null || visit.scheduledTime == "10:00 AM") ? "9:00 AM" : visit.scheduledTime!;
                        final String msg = (visit.status == 'Verified' || visit.status == 'Completed')
                            ? 'This visit has already been ${visit.status.toLowerCase()}.'
                            : 'Duty time has not started yet. Execute Visit unlocks at 8:50 AM (10 mins before $displayTime).';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg), backgroundColor: AppTheme.primaryColor),
                        );
                      },
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 36, child: expanded ? SizedBox(width: double.infinity, child: btn) : btn),
                  if (!canExecute && visit.status != 'Verified' && visit.status != 'Completed')
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Unlocks 10m before ${(visit.scheduledTime == null || visit.scheduledTime == "10:00 AM") ? "9:00 AM" : visit.scheduledTime}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              );
            },
          );

          // Wide-mode buttons (compact, natural size)
          final wideButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (visit.status != 'Cancelled') ...[
                IconButton(
                  icon: const Icon(Icons.do_not_disturb_on_outlined, color: AppTheme.dangerColor, size: 22),
                  tooltip: 'Stop / Discontinue Care',
                  onPressed: () => _showDiscontinueDialog(context, visit),
                ),
                const SizedBox(width: 4),
              ],
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  style: AppTheme.primaryButton,
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const Text('View Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () {
                    if (widget.onViewSummary != null) {
                      widget.onViewSummary!(visit.id);
                    } else {
                      context.go('/nurse/home-visits/summary/${visit.id}');
                    }
                  },
                ),
              ),
              if (visit.status != 'Cancelled' && widget.showExecuteButton) ...[
                const SizedBox(width: 8),
                buildExecuteBtn(),
              ],
            ],
          );

          final String pIdStr = (visit.patientDisplayId != null && visit.patientDisplayId!.trim().isNotEmpty)
              ? visit.patientDisplayId!
              : 'ID: ${visit.patientId}';

          // Patient info widget (shared)
          Widget buildPatientInfo(double maxW) => Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                child: const Icon(Icons.person, color: AppTheme.primaryColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${visit.patientName ?? "Patient"} ($pIdStr)',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),
                          child: Text(effectiveStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeText)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Visit #: ${visit.visitNumber} • Date: $displayDate (${(visit.scheduledTime == null || visit.scheduledTime == "10:00 AM") ? "9:00 AM" : visit.scheduledTime})',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (visit.nurseName != null && visit.nurseName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_pin_outlined, size: 14, color: AppTheme.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'Nurse: ${visit.nurseName}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ],
                    if (visit.visitAddress != null && visit.visitAddress!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              visit.visitAddress!,
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          if (isNarrow) {
            final bool canExecute = _isExecuteButtonEnabled(visit);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildPatientInfo(constraints.maxWidth),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (visit.status != 'Cancelled') ...[
                      IconButton(
                        icon: const Icon(Icons.do_not_disturb_on_outlined, color: AppTheme.dangerColor, size: 20),
                        tooltip: 'Stop / Discontinue Care',
                        onPressed: () => _showDiscontinueDialog(context, visit),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        style: AppTheme.primaryButton.copyWith(
                          minimumSize: WidgetStateProperty.all(const Size(0, 40)),
                          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8)),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 14),
                        label: const Text('View Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                        onPressed: () {
                          if (widget.onViewSummary != null) {
                            widget.onViewSummary!(visit.id);
                          } else {
                            context.go('/nurse/home-visits/summary/${visit.id}');
                          }
                        },
                      ),
                    ),
                    if (visit.status != 'Cancelled' && widget.showExecuteButton) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: (canExecute ? AppTheme.dangerButton : ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCBD5E1),
                            foregroundColor: const Color(0xFF64748B),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          )).copyWith(
                            minimumSize: WidgetStateProperty.all(const Size(0, 40)),
                            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8)),
                          ),
                          icon: Icon(visit.status.toLowerCase() == 'in-progress' || effectiveStatus.toLowerCase() == 'in-progress' ? Icons.play_arrow_outlined : (canExecute ? Icons.medical_services_outlined : Icons.lock_clock_outlined), size: 14),
                          label: Text(
                            (visit.status.toLowerCase() == 'in-progress' || effectiveStatus.toLowerCase() == 'in-progress') ? 'Resume Visit' : 'Execute Visit',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: canExecute ? Colors.white : const Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: canExecute
                              ? () => _onExecuteVisitPressed(context, visit)
                              : () {
                                  final String displayTime = (visit.scheduledTime == null || visit.scheduledTime == "10:00 AM") ? "9:00 AM" : visit.scheduledTime!;
                                  final String msg = (visit.status == 'Verified' || visit.status == 'Completed')
                                      ? 'This visit has already been ${visit.status.toLowerCase()}.'
                                      : 'Duty time has not started yet. Unlocks at 8:50 AM (10 mins before $displayTime).';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(msg), backgroundColor: AppTheme.primaryColor),
                                  );
                                },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: buildPatientInfo(constraints.maxWidth)),
              const SizedBox(width: 12),
              wideButtons,
            ],
          );
        },
      ),
    );
  }

  void _showDiscontinueDialog(BuildContext context, HomeVisitModel visit) {
    String selectedReason = 'Patient Cured / Fully Recovered';
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.do_not_disturb_on_outlined, color: AppTheme.dangerColor, size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Stop / Discontinue Home Visit Care',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to stop/discontinue home visit care for ${visit.patientName ?? "Patient #${visit.patientId}"}?',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              const Text('Select Discontinuation Reason:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              CustomDropdownSearch(
                label: '',
                hint: 'Select Reason',
                dropdownMap: const {
                  'Patient Cured / Fully Recovered': 'Patient Cured / Fully Recovered',
                  'Patient / Attender Requested Discontinuation': 'Patient / Attender Requested Discontinuation',
                  'Admitted to Hospital / IPD Care': 'Admitted to Hospital / IPD Care',
                  'Doctor Advice / Care Plan Ended': 'Doctor Advice / Care Plan Ended',
                  'Other Reason': 'Other Reason',
                },
                value: selectedReason,
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedReason = val);
                  }
                },
              ),
              const SizedBox(height: 14),
              const Text('Additional Notes / Remarks (Optional):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: AppTheme.standardInputDecoration(hintText: 'Enter reason notes (e.g. Cured and recovered)...'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: AppTheme.dangerButton,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Stop Care'),
              onPressed: () async {
                final homeVisitCtrl = Provider.of<HomeVisitController>(context, listen: false);
                final success = await homeVisitCtrl.cancelVisit(visit.id, selectedReason, notesCtrl.text);
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Home visit care for ${visit.patientName ?? "Patient"} stopped/discontinued successfully.'),
                      backgroundColor: AppTheme.secondaryColor,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleVisitDialog(BuildContext context) {
    final homeVisitCtrl = Provider.of<HomeVisitController>(context, listen: false);

    final scheduledPatientIds = homeVisitCtrl.visits
        .where((v) => v.status != 'Cancelled')
        .map((v) => v.patientId)
        .toSet();

    final availablePatients = _patientsList
        .where((p) => p.id != null && !scheduledPatientIds.contains(p.id))
        .toList();

    PatientModel? selectedPatient;
    final addressCtrl = TextEditingController(text: '');
    final now = DateTime.now();
    final formattedNow = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
    final dateCtrl = TextEditingController(text: formattedNow);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.home_work, color: AppTheme.primaryColor),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Schedule New Home Visit',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Patient (Name & ID):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              if (_isLoadingPatients)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Loading patients list...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              else if (availablePatients.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'All patients already have active home visits scheduled.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
              else
                CustomDropdownSearch(
                  label: '',
                  hint: 'Select Patient (Name & ID)',
                  dropdownMap: {
                    for (var p in availablePatients)
                      p.id.toString(): '${p.name} (${(p.patientId != null && p.patientId!.isNotEmpty) ? p.patientId! : "ID: ${p.id}"})'
                  },
                  value: selectedPatient?.id.toString(),
                  onChanged: (val) {
                    if (val != null) {
                      final pId = int.tryParse(val);
                      final found = availablePatients.firstWhere(
                        (p) => p.id == pId,
                        orElse: () => availablePatients.first,
                      );
                      setDialogState(() {
                        selectedPatient = found;
                        addressCtrl.text = found.fullAddress.isNotEmpty ? found.fullAddress : found.address;
                      });
                    }
                  },
                ),
              const SizedBox(height: 6),
              // Single small gray line for Visit Address directly below patient field
              Padding(
                padding: const EdgeInsets.only(left: 2.0),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Colors.grey, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        selectedPatient != null
                            ? 'Visit Address: ${addressCtrl.text.isNotEmpty ? addressCtrl.text : "No address recorded"}'
                            : 'Visit Address: Select a patient to view address',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Scheduled Date:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: dateCtrl,
                readOnly: true,
                decoration: AppTheme.standardInputDecoration(
                  suffixIcon: const Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryColor),
                ),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      dateCtrl.text = "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: AppTheme.dangerButton,
              onPressed: () async {
                final targetPatient = selectedPatient ?? (_patientsList.isNotEmpty ? _patientsList.first : null);
                if (targetPatient == null || targetPatient.id == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a valid patient to schedule a home visit.'),
                      backgroundColor: AppTheme.dangerColor,
                    ),
                  );
                  return;
                }

                String apiDateStr = dateCtrl.text;
                final dateParts = dateCtrl.text.split('-');
                if (dateParts.length == 3 && dateParts[2].length == 4) {
                  apiDateStr = "${dateParts[2]}-${dateParts[1]}-${dateParts[0]}";
                }

                final homeVisitCtrl = Provider.of<HomeVisitController>(context, listen: false);

                // Prevent scheduling duplicate visit for same patient on same date
                final bool existingSameDay = homeVisitCtrl.visits.any(
                  (v) => v.patientId == targetPatient.id && v.scheduledDate == apiDateStr && v.status != 'Cancelled',
                );

                if (existingSameDay) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('⚠️ A home visit is already scheduled for ${targetPatient.name} on ${dateCtrl.text}. Only 1 visit per patient per day is allowed.'),
                      backgroundColor: AppTheme.dangerColor,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                  return;
                }
                final newVisit = await homeVisitCtrl.createVisit({
                  'patient_id': targetPatient.id,
                  'scheduled_date': apiDateStr,
                  'scheduled_time': '9:00 AM',
                  'visit_address': addressCtrl.text,
                  'carried_items': [],
                });

                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                if (newVisit != null) {
                  await homeVisitCtrl.fetchVisits();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Home visit ${newVisit.visitNumber} scheduled successfully!'),
                        backgroundColor: AppTheme.secondaryColor,
                      ),
                    );
                  }
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(homeVisitCtrl.errorMessage ?? 'Failed to schedule home visit.'),
                      backgroundColor: AppTheme.dangerColor,
                    ),
                  );
                }
              },
              child: const Text('Schedule Visit'),
            ),
          ],
        ),
      ),
    );
  }


  bool _isExecuteButtonEnabled(HomeVisitModel visit) {
    if (visit.status == 'Verified' || visit.status == 'Completed') {
      return false;
    }
    try {
      final now = DateTime.now();
      DateTime unlockTime = DateTime(now.year, now.month, now.day, 7, 0);

      if (visit.scheduledDate.isNotEmpty) {
        final dateParts = visit.scheduledDate.split('-');
        if (dateParts.length == 3) {
          int y, m, d;
          if (dateParts[0].length == 4) {
            y = int.parse(dateParts[0]);
            m = int.parse(dateParts[1]);
            d = int.parse(dateParts[2]);
          } else {
            d = int.parse(dateParts[0]);
            m = int.parse(dateParts[1]);
            y = int.parse(dateParts[2]);
          }
          unlockTime = DateTime(y, m, d, 7, 0);
        }
      }

      return now.isAfter(unlockTime) || now.isAtSameMomentAs(unlockTime);
    } catch (e) {
      return true;
    }
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryColor,
        ),
      ),
    );
  }

  void _onExecuteVisitPressed(BuildContext context, HomeVisitModel visit) {
    if (visit.startTime != null && visit.startTime!.trim().isNotEmpty) {
      _navigateToExecuteScreen(context, visit.id);
    } else {
      _showStartHomeVisitDialog(context, visit);
    }
  }

  void _navigateToExecuteScreen(BuildContext context, int visitId) {
    if (widget.onExecuteVisit != null) {
      widget.onExecuteVisit!(visitId);
    } else {
      context.go('/nurse/home-visits/execute/$visitId');
    }
  }

  void _showStartHomeVisitDialog(BuildContext context, HomeVisitModel visit) {
    final formKey = GlobalKey<FormState>();
    final now = DateTime.now();
    final defaultTime = DateFormat('hh:mm a').format(now);

    final authUser = Provider.of<AuthProvider>(context, listen: false).user;
    final String rawNurseName = (visit.startNurseName != null && visit.startNurseName!.isNotEmpty)
        ? visit.startNurseName!
        : ((visit.nurseName != null && visit.nurseName!.isNotEmpty)
            ? visit.nurseName!
            : (authUser?.fullname ?? 'Nurse'));
    final String nurseStaffId = (authUser != null && authUser.staffUniqueId != null && authUser.staffUniqueId!.isNotEmpty)
        ? authUser.staffUniqueId!
        : '';
    final String nurseDisplayWithId = nurseStaffId.isNotEmpty
        ? '$rawNurseName ($nurseStaffId)'
        : rawNurseName;

    final String rawPatientName = visit.patientName ?? 'Patient';
    final String patientDisplayId = (visit.patientDisplayId != null && visit.patientDisplayId!.trim().isNotEmpty)
        ? visit.patientDisplayId!
        : 'ID: ${visit.patientId}';
    final String patientDisplayWithId = '$rawPatientName ($patientDisplayId)';

    final nurseCtrl = TextEditingController(text: rawNurseName);
    final timeCtrl = TextEditingController(text: defaultTime);
    bool isSubmitting = false;

    final bool isInProgress = visit.status.toLowerCase() == 'in-progress';
    final String dialogTitle = isInProgress ? 'Resume Home Visit Session' : 'Start Home Visit Session';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.play_circle_fill_outlined, color: AppTheme.primaryColor, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dialogTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isInProgress
                          ? 'Confirm visit resume time before managing patient vitals & care.'
                          : 'Record visit start time before accessing patient vitals.',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Patient & Nurse Info Box (Read-Only Styled Card)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Patient Details (Small text)
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 15, color: AppTheme.primaryColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Patient: $patientDisplayWithId',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Executing Nurse Details (Non-editable, distinct blue badge style)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.badge_outlined, size: 15, color: Color(0xFF1D4ED8)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Executing Nurse: $nurseDisplayWithId',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.lock_outline, size: 13, color: Color(0xFF93C5FD)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ONLY EDITABLE FIELD: Visit Start Time
                    _buildLabel(isInProgress ? 'Visit Resume Time' : 'Visit Start Time'),
                    TextFormField(
                      controller: timeCtrl,
                      readOnly: true,
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
                          setDialogState(() {
                            timeCtrl.text = DateFormat('hh:mm a').format(dt);
                          });
                        }
                      },
                      decoration: AppTheme.standardInputDecoration(
                        hintText: 'Select Start Time',
                        prefixIcon: Icons.access_time,
                        suffixIcon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Start time is required' : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            SizedBox(
              height: 44,
              child: OutlinedButton(
                style: AppTheme.cancelButton,
                onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
            ),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                style: AppTheme.primaryButton,
                icon: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_forward, size: 16),
                label: Text(isSubmitting ? 'Saving...' : (isInProgress ? 'Submit & Resume Visit' : 'Submit & Start Visit')),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (formKey.currentState?.validate() == true) {
                          setDialogState(() => isSubmitting = true);
                          try {
                            final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3001/api';
                            final payload = {
                              'start_time': timeCtrl.text.trim(),
                              'nurse_name': nurseCtrl.text.trim(),
                            };
                            var res = await ApiService.put('$baseUrl/home-visits/${visit.id}/start', payload);
                            var body = ApiService.decodeJsonResponse(res);
                            if (body['success'] != true) {
                              res = await ApiService.post('$baseUrl/home-visits/${visit.id}/start', payload);
                              body = ApiService.decodeJsonResponse(res);
                            }
                            if (body['success'] != true) {
                              res = await ApiService.post('$baseUrl/home-visits/${visit.id}/vitals', {
                                'is_start_only': true,
                                'start_time': timeCtrl.text.trim(),
                                'nurse_name': nurseCtrl.text.trim(),
                                'bypass_schedule': true,
                              });
                              body = ApiService.decodeJsonResponse(res);
                            }
                            if (body['success'] == true) {
                              if (mounted) {
                                Provider.of<HomeVisitController>(context, listen: false).fetchVisits();
                                Navigator.of(dialogCtx).pop();
                                _navigateToExecuteScreen(context, visit.id);
                              }
                            } else {
                              setDialogState(() => isSubmitting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(body['message'] ?? 'Failed to record start time'),
                                    backgroundColor: AppTheme.dangerColor,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error starting visit: $e'),
                                  backgroundColor: AppTheme.dangerColor,
                                ),
                              );
                            }
                          }
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
