import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../core/routes/route_constants.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/nurse_widgets.dart' show LiveClock;
import '../controllers/lab_controller.dart';
import '../utils/logout_helper.dart';
import '../widgets/user_profile_dialog.dart';
import 'billing_management_view.dart';

class LabDashboardScreen extends StatefulWidget {
  final int initialIndex;
  const LabDashboardScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<LabDashboardScreen> createState() => _LabDashboardScreenState();
}

class _LabDashboardScreenState extends State<LabDashboardScreen> {
  int _selectedIndex = 0;
  final LabController _labController = LabController();
  
  // Dashboard & Requests state
  List<Map<String, dynamic>> _labRequests = [];
  Map<String, dynamic> _stats = {
    'pending_count': 0,
    'collected_count': 0,
    'completed_today_count': 0
  };
  bool _isLoadingRequests = false;
  bool _isLoadingStats = false;
  String? _requestsError;

  List<Map<String, dynamic>> _technicians = [];
  List<Map<String, dynamic>> _machines = [];
  bool _isLoadingResources = false;

  // Search & Filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'Pending', 'Sample Collected'

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant LabDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _selectedIndex = widget.initialIndex;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    await Future.wait([
      _fetchRequests(),
      _fetchStats(),
      _fetchResources(),
    ]);
  }

  Future<void> _fetchResources() async {
    if (mounted) {
      setState(() => _isLoadingResources = true);
    }
    try {
      final techs = await _labController.fetchTechnicians();
      final machs = await _labController.fetchMachines();
      if (mounted) {
        setState(() {
          _technicians = techs;
          _machines = machs;
          _isLoadingResources = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching resources: $e');
      if (mounted) {
        setState(() => _isLoadingResources = false);
      }
    }
  }

  Future<void> _fetchRequests() async {
    if (mounted) {
      setState(() {
        _isLoadingRequests = true;
        _requestsError = null;
      });
    }
    try {
      final reqs = await _labController.fetchLabRequests();
      if (mounted) {
        setState(() {
          _labRequests = reqs;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _requestsError = e.toString();
          _isLoadingRequests = false;
        });
      }
    }
  }

  Future<void> _fetchStats() async {
    if (mounted) {
      setState(() => _isLoadingStats = true);
    }
    try {
      final stats = await _labController.fetchLabStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching lab stats: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    try {
      await _labController.updateLabRequest(
        id: id,
        status: status,
        processedBy: user?.id,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test marked as $status successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _changePage(int index) {
    if (!mounted) return;
    switch (index) {
      case 0:
        context.go(AppRoutes.labDashboard);
        break;
      case 1:
        context.go(AppRoutes.labPending);
        break;
      case 2:
        context.go(AppRoutes.labCompleted);
        break;
      case 3:
        context.go(AppRoutes.labProfile);
        break;
      case 4:
        context.go(AppRoutes.labResources);
        break;
      case 5:
        context.go(AppRoutes.labBilling);
        break;
      default:
        context.go(AppRoutes.labDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: isMobile ? Drawer(child: _buildSidebar(context)) : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(context),
          Expanded(
            child: Column(
              children: [
                if (_selectedIndex != 0) _buildHeader(context, isMobile),
                Expanded(child: _buildMainContent(isMobile)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        return Container(
          width: 260,
          margin: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Logo Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Image.asset(
                  'assets/image/full_logo.png',
                  width: 110,
                  height: 90,
                ),
              ),

              // Navigation
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSidebarItem(0, Icons.dashboard_outlined, 'Dashboard'),
                      _buildSidebarItem(1, Icons.biotech_outlined, 'Pending Tests'),
                      _buildSidebarItem(2, Icons.fact_check_outlined, 'Completed Tests'),
                      _buildSidebarItem(4, Icons.settings_suggest_outlined, 'Resources'),
                      _buildSidebarItem(5, Icons.receipt_long_outlined, 'Lab Billing'),
                      _buildSidebarItem(3, Icons.person_outline, 'My Profile'),
                    ],
                  ),
                ),
              ),

              // Footer Profile
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppTheme.borderColor, width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: user == null
                    ? const SizedBox.shrink()
                    : Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => UserProfileDialog.show(context, user),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor,
                                    radius: 18,
                                    child: Text(
                                      user.fullname.isNotEmpty ? user.fullname[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.fullname,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: AppTheme.textPrimaryColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          user.role,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondaryColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.logout,
                              size: 18,
                              color: AppTheme.textSecondaryColor,
                            ),
                            onPressed: () =>
                                LogoutHelper.showLogoutConfirmation(
                                  context,
                                  auth,
                                ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _changePage(index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF4A5568),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF2D3748),
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      padding: EdgeInsets.only(
        left: isMobile ? 16 : 24,
        right: isMobile ? 16 : 24,
        top: 20,
        bottom: 0,
      ),
      child: _buildBannerTopBar(isMobile),
    );
  }

  Widget _buildBannerTopBar(bool isMobile) {
    return Row(
      children: [
        if (isMobile) ...[
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(
                Icons.menu,
                color: Color(0xFF4A5568),
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const SizedBox(width: 8),
        ],

        Expanded(
          child: Container(
            height: 40,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'SPMC Laboratory Portal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none_outlined,
              color: Color(0xFF4A5568),
              size: 22,
            ),
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFFE53E3E),
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 14,
                  minHeight: 14,
                ),
                child: const Text(
                  '3',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(width: 16),
        const Icon(Icons.settings_outlined, color: Color(0xFF4A5568), size: 22),
        const SizedBox(width: 16),
        const LiveClock(isDark: false),
      ],
    );
  }

  Widget _buildMainContent(bool isMobile) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardView(isMobile);
      case 1:
        return _buildRequestsView(isMobile, showPendingOnly: true);
      case 2:
        return _buildRequestsView(isMobile, showPendingOnly: false);
      case 3:
        return _buildProfileView(isMobile);
      case 4:
        return _buildResourcesView(isMobile);
      case 5:
        return const BillingManagementView();
      default:
        return _buildDashboardView(isMobile);
    }
  }

  Widget _buildDashboardView(bool isMobile) {
    final pendingCount = _stats['pending_count'] ?? 0;
    final remainingMins = _stats['remaining_working_minutes'] ?? 0;
    final canCompleteToday = _stats['completed_today_count'] ?? 0;
    final movedTomorrow = _stats['moved_tomorrow_count'] ?? 0;
    final waitingTechnician = _stats['waiting_technician_count'] ?? 0;
    final waitingMachine = _stats['waiting_machine_count'] ?? 0;

    final remainingTimeText = remainingMins > 0 ? _formatDuration(remainingMins as int) : 'Closed';
    final recentRequests = _labRequests.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed Top Bar
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
          color: Colors.transparent,
          child: _buildBannerTopBar(isMobile),
        ),
        // Scrollable Content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Back, Lab Team',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Process patient test requests and register observed details efficiently.',
                    style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // Stats Cards Row 1
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Pending Tests',
                          value: '$pendingCount',
                          icon: Icons.hourglass_empty_outlined,
                          color: Colors.orange,
                          bgColor: Colors.orange.shade50,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Remaining Work Time',
                          value: remainingTimeText,
                          icon: Icons.timer_outlined,
                          color: Colors.blue,
                          bgColor: Colors.blue.shade50,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Complete Today',
                          value: '$canCompleteToday',
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                          bgColor: Colors.green.shade50,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Stats Cards Row 2
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Moved to Tomorrow',
                          value: '$movedTomorrow',
                          icon: Icons.next_plan_outlined,
                          color: Colors.red,
                          bgColor: Colors.red.shade50,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Waiting for Technician',
                          value: '$waitingTechnician',
                          icon: Icons.person_off_outlined,
                          color: Colors.purple,
                          bgColor: Colors.purple.shade50,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Waiting for Machine',
                          value: '$waitingMachine',
                          icon: Icons.settings_suggest_outlined,
                          color: Colors.teal,
                          bgColor: Colors.teal.shade50,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Recent Orders List Table
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recent Lab Test Orders',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                            TextButton(
                              onPressed: () => _changePage(1),
                              child: const Text('View All Tests'),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        if (_isLoadingRequests)
                          const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
                        else if (_requestsError != null)
                          Center(child: Text('Error loading requests: $_requestsError', style: const TextStyle(color: Colors.red)))
                        else if (recentRequests.isEmpty)
                          const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No orders found')))
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: recentRequests.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final req = recentRequests[idx];
                              final formattedDate = _formatDate(req['created_at']);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            req['test_name'] ?? 'Lab Test',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                'Estimated Duration: ${req['target_tat_minutes'] != null ? _formatDuration(req['target_tat_minutes'] is int ? req['target_tat_minutes'] as int : int.tryParse(req['target_tat_minutes']?.toString() ?? '') ?? 0) : 'Not Set'}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.logoRed,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () => _showEditDurationDialog(req),
                                                child: const Icon(
                                                  Icons.edit,
                                                  size: 12,
                                                  color: AppTheme.logoRed,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Ordered by Dr. ${req['doctor_name']}',
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              _buildPriorityBadge(req['priority']),
                                              if (req['queue_position'] != null && req['status'] != 'Completed') ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                                                  child: Text('Pos #${req['queue_position']}', style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                              if (req['scheduled_start_override'] != null && req['status'] != 'Completed') ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                                  child: Text(
                                                    'Rescheduled: ${DateFormat('dd-MMM-yyyy').format(DateTime.parse(req['scheduled_start_override']).toLocal())}', 
                                                    style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.bold)
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            req['patient_name'] ?? 'Unknown',
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            req['patient_display_id'] ?? '',
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Ordered:',
                                            style: TextStyle(fontSize: 9, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            formattedDate,
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                                          ),
                                          if (req['status'] != 'Completed' && req['estimated_completion_at'] != null) ...[
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Est Completion:',
                                              style: TextStyle(fontSize: 9, color: AppTheme.secondaryColor, fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              _formatDate(req['estimated_completion_at']),
                                              style: const TextStyle(fontSize: 11, color: AppTheme.secondaryColor, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: _buildStatusBadge(req['status']),
                                    ),
                                    const SizedBox(width: 12),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: OutlinedButton(
                                        onPressed: () {
                                          if (req['status'] == 'Pending') {
                                            _updateStatus(req['id'], 'Sample Collected');
                                          } else if (req['status'] == 'Sample Collected') {
                                            _showResultsEntryDialog(req);
                                          } else {
                                            _selectedIndex = 2; // Move to Completed
                                            setState(() {});
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          req['status'] == 'Pending'
                                              ? 'Collect Sample'
                                              : req['status'] == 'Sample Collected'
                                                  ? 'Enter Results'
                                                  : 'View',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.1),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color bg;
    Color text;
    switch (status) {
      case 'Completed':
        bg = Colors.green.shade50;
        text = Colors.green;
        break;
      case 'Sample Collected':
        bg = Colors.blue.shade50;
        text = Colors.blue;
        break;
      default:
        bg = Colors.orange.shade50;
        text = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status ?? 'Pending',
        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildRequestsView(bool isMobile, {required bool showPendingOnly}) {
    // Apply search filter and status tabs
    final filtered = _labRequests.where((req) {
      final matchesSearch = (req['patient_name'] ?? '').toString().toLowerCase().contains(_searchQuery) ||
                            (req['patient_display_id'] ?? '').toString().toLowerCase().contains(_searchQuery) ||
                            (req['test_name'] ?? '').toString().toLowerCase().contains(_searchQuery);
      
      final reqStatus = req['status'] ?? 'Pending';
      if (showPendingOnly) {
        if (reqStatus == 'Completed') return false;
        if (_statusFilter != 'All' && reqStatus != _statusFilter) return false;
      } else {
        if (reqStatus != 'Completed') return false;
      }

      return matchesSearch;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchRequests,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showPendingOnly ? 'Pending Tests' : 'Completed Tests',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  showPendingOnly
                      ? 'Process and manage patient pending laboratory tests'
                      : 'History of completed laboratory tests and records',
                  style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                ),
              ],
            ),
          ),
          // Filter Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        hintText: 'Search by Patient Name, ID, or Test...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                        prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.textSecondaryColor),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                ),
                if (showPendingOnly) ...[
                  const SizedBox(width: 16),
                  _buildFilterTab('All'),
                  const SizedBox(width: 8),
                  _buildFilterTab('Pending'),
                  const SizedBox(width: 8),
                  _buildFilterTab('Sample Collected'),
                ],
              ],
            ),
          ),

          // Requests List
          Expanded(
            child: _isLoadingRequests
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty ? 'No requests found' : 'No matching results found',
                          style: const TextStyle(color: AppTheme.textSecondaryColor),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final req = filtered[idx];
                          return showPendingOnly
                              ? _buildPendingRequestCard(req, isMobile)
                              : _buildCompletedRequestCard(req, isMobile);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label) {
    final isActive = _statusFilter == label;
    return InkWell(
      onTap: () => setState(() => _statusFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.textSecondaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '';
    if (minutes < 60) {
      return '$minutes mins';
    }
    final double hours = minutes / 60.0;
    if (hours < 24) {
      if (minutes % 60 == 0) {
        final int h = minutes ~/ 60;
        return '$h ${h == 1 ? 'hr' : 'hrs'}';
      }
      return '${hours.toStringAsFixed(1)} hrs';
    }
    final double days = hours / 24.0;
    if (minutes % 1440 == 0) {
      final int wholeDays = minutes ~/ 1440;
      return '$wholeDays ${wholeDays == 1 ? 'day' : 'days'}';
    }
    return '${days.toStringAsFixed(1)} days';
  }

  Widget _buildPendingRequestCard(Map<String, dynamic> req, bool isMobile) {
    final orderedDate = _formatDate(req['created_at']);
    final isSampleCollected = req['status'] == 'Sample Collected';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req['test_name'] ?? 'Lab Test',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Estimated Result Duration: ${req['target_tat_minutes'] != null ? _formatDuration(req['target_tat_minutes'] is int ? req['target_tat_minutes'] as int : int.tryParse(req['target_tat_minutes']?.toString() ?? '') ?? 0) : 'Not Set'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.logoRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _showEditDurationDialog(req),
                          child: const Icon(
                            Icons.edit,
                            size: 14,
                            color: AppTheme.logoRed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(req['status']),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'Order Placement: $orderedDate',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
              ),
              if (req['queue_position'] != null)
                Text(
                  '• Queue Position: #${req['queue_position']}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                ),
              if (req['estimated_completion_at'] != null)
                Text(
                  '• Est Completion: ${_formatDate(req['estimated_completion_at'])}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.secondaryColor, fontWeight: FontWeight.bold),
                ),
              if (req['scheduled_start_override'] != null)
                Text(
                  '• Rescheduled: ${DateFormat('dd-MMM-yyyy').format(DateTime.parse(req['scheduled_start_override']).toLocal())}',
                  style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (req['technician_name'] != null)
                Text(
                  'Staff: ${req['technician_name']}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor, fontWeight: FontWeight.w600),
                ),
              if (req['machine_name'] != null)
                Text(
                  '• Machine: ${req['machine_name']}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor, fontWeight: FontWeight.w600),
                ),
              if (req['schedule_status'] != null && req['schedule_status'] != 'Scheduled')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: req['schedule_status'] == 'Waiting for Technician' ? Colors.purple.shade50 : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    req['schedule_status'],
                    style: TextStyle(
                      fontSize: 10,
                      color: req['schedule_status'] == 'Waiting for Technician' ? Colors.purple.shade800 : Colors.teal.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Requested by Dr. ${req['doctor_name']}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
              ),
              const SizedBox(width: 8),
              _buildPriorityBadge(req['priority']),
              if (req['delay_reason'] != null && req['delay_reason'].toString().isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning, size: 10, color: Colors.red),
                      const SizedBox(width: 4),
                      Text('Delayed: ${req['delay_reason']}', style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient profile
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PATIENT DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                    const SizedBox(height: 6),
                    Text(req['patient_name'] ?? 'Unknown', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '${req['patient_display_id']} • ${req['patient_gender']} • ${req['patient_age']} years',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                    ),
                  ],
                ),
              ),
              // Symptoms & Diagnosis
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CLINICAL INDICATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                    const SizedBox(height: 6),
                    Text('Diagnosis: ${req['diagnosis'] ?? 'N/A'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      'Symptoms: ${req['symptoms'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Priority: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  DropdownButton<String>(
                    value: req['priority'] ?? 'Normal',
                    underline: const SizedBox(),
                    items: ['Normal', 'Urgent', 'Emergency'].map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                      );
                    }).toList(),
                    onChanged: (newPriority) async {
                      if (newPriority != null) {
                        try {
                          await _labController.updateLabRequest(
                            id: req['id'],
                            status: req['status'],
                            priority: newPriority,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Priority updated to $newPriority'), backgroundColor: Colors.green),
                          );
                          _fetchData();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () => _showDelayDialog(req),
                    icon: const Icon(Icons.pause_circle_outline, size: 16, color: AppTheme.logoRed),
                    label: const Text('Delay / Log Issue', style: TextStyle(color: AppTheme.logoRed, fontSize: 12)),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () => _showRescheduleDialog(req),
                    icon: const Icon(Icons.calendar_today, size: 14, color: AppTheme.primaryColor),
                    label: const Text('Reschedule', style: TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
                  ),
                ],
              ),
              if (!isSampleCollected)
                ElevatedButton.icon(
                  onPressed: () => _updateStatus(req['id'], 'Sample Collected'),
                  icon: const Icon(Icons.biotech, size: 16, color: Colors.white),
                  label: const Text('Record Sample Collection', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _showResultsEntryDialog(req),
                  icon: const Icon(Icons.edit_note, size: 16, color: Colors.white),
                  label: const Text('Enter Lab Results', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.logoRed,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedRequestCard(Map<String, dynamic> req, bool isMobile) {
    final orderedDate = _formatDate(req['created_at']);
    final processedDate = _formatDate(req['updated_at']);

    // Parse results
    List resultsList = [];
    if (req['result_details'] != null) {
      if (req['result_details'] is String) {
        try {
          resultsList = jsonDecode(req['result_details']);
        } catch (_) {}
      } else if (req['result_details'] is List) {
        resultsList = req['result_details'];
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                req['test_name'] ?? 'Lab Test',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
              if (req['target_tat_minutes'] != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Estimated Result Duration: ${_formatDuration(req['target_tat_minutes'] is int ? req['target_tat_minutes'] as int : int.tryParse(req['target_tat_minutes']?.toString() ?? '') ?? 0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.logoRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          subtitle: Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Patient: ${req['patient_name']} (${req['patient_display_id']}) • Completed: $processedDate',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
              ),
              if (req['actual_tat_minutes'] != null)
                Text(
                  '• Actual TAT: ${req['actual_tat_minutes']} mins',
                  style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                ),
              if (req['completion_status'] != null)
                _buildCompletionStatusBadge(req['completion_status']),
            ],
          ),
          childrenPadding: const EdgeInsets.all(20),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1, color: AppTheme.borderColor),
            const SizedBox(height: 16),
            const Text(
              'TEST PARAMETER MEASUREMENTS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 8),
            if (resultsList.isEmpty)
              const Text('No parameters registered', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13))
            else
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1.5),
                },
                children: [
                  const TableRow(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.borderColor))),
                    children: [
                      Padding(padding: EdgeInsets.all(8.0), child: Text('Parameter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.all(8.0), child: Text('Observed Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.all(8.0), child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.all(8.0), child: Text('Reference Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                  ),
                  ...resultsList.map((res) {
                    return TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(8.0), child: Text(res['parameter'] ?? '', style: const TextStyle(fontSize: 13))),
                        Padding(
                          padding: const EdgeInsets.all(8.0), 
                          child: Text(
                            res['value'] ?? '', 
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)
                          )
                        ),
                        Padding(padding: const EdgeInsets.all(8.0), child: Text(res['unit'] ?? '', style: const TextStyle(fontSize: 13))),
                        Padding(padding: const EdgeInsets.all(8.0), child: Text(res['reference_range'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor))),
                      ],
                    );
                  }).toList(),
                ],
              ),
            const SizedBox(height: 20),
            if (req['remarks'] != null && req['remarks'].toString().isNotEmpty) ...[
              const Text('REMARKS / OBSERVATION NOTES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
              const SizedBox(height: 4),
              Text(req['remarks'], style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 20),
            ],
            if (req['attachment_url'] != null && req['attachment_url'].toString().isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.attach_file, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Reference Report file: ${req['attachment_url']}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileView(bool isMobile) {
    final user = Provider.of<AuthProvider>(context).user;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Profile',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      radius: 40,
                      child: Text(
                        user?.fullname.isNotEmpty == true ? user!.fullname[0].toUpperCase() : 'L',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullname ?? 'Lab Technician',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.role ?? 'Lab Technician',
                          style: const TextStyle(fontSize: 14, color: AppTheme.logoRed, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                _buildProfileRow('Staff Unique ID', user?.staffUniqueId ?? '-', Icons.badge_outlined),
                _buildProfileRow('Email Address', user?.email ?? '-', Icons.alternate_email),
                _buildProfileRow('Mobile Number', user?.mobile ?? '-', Icons.phone_android_outlined),
                _buildProfileRow('Status', user?.status ?? '-', Icons.check_circle_outline),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDurationDialog(Map<String, dynamic> req) {
    final currentMinutes = req['target_tat_minutes'] is int 
        ? req['target_tat_minutes'] as int 
        : int.tryParse(req['target_tat_minutes']?.toString() ?? '') ?? 0;
        
    final controller = TextEditingController(text: currentMinutes > 0 ? currentMinutes.toString() : '');
    final formKey = GlobalKey<FormState>();

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
                decoration: BoxDecoration(color: AppTheme.logoRed.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.timer_outlined, color: AppTheme.logoRed, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Edit Test Processing Duration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(req['test_name'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                  ],
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set the processing time (in minutes) for this test. The estimated completion time will be automatically recalculated based on working hours, lab queue, and resource availability.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter duration in minutes';
                    }
                    final minutes = int.tryParse(v.trim());
                    if (minutes == null || minutes <= 0) {
                      return 'Must be a valid positive number';
                    }
                    if (minutes > 99999) {
                      return 'Duration cannot exceed 99,999 minutes';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Duration (Minutes)',
                    hintText: 'e.g., 30, 60, 120',
                    border: OutlineInputBorder(),
                    isDense: true,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('QUICK PRESETS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _presetChip(ctx, controller, '15 mins', 15),
                    _presetChip(ctx, controller, '30 mins', 30),
                    _presetChip(ctx, controller, '45 mins', 45),
                    _presetChip(ctx, controller, '1 hr', 60),
                    _presetChip(ctx, controller, '2 hrs', 120),
                    _presetChip(ctx, controller, '4 hrs', 240),
                    _presetChip(ctx, controller, '24 hrs', 1440),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newMinutes = int.parse(controller.text.trim());
                Navigator.pop(ctx);
                
                try {
                  await _labController.updateLabRequest(
                    id: req['id'],
                    status: req['status'],
                    targetTatMinutes: newMinutes,
                    processingDurationMinutes: newMinutes,
                  );
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Estimated duration updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _fetchData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating duration: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.logoRed),
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _presetChip(BuildContext ctx, TextEditingController controller, String label, int value) {
    return InkWell(
      onTap: () {
        controller.text = value.toString();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor),
        ),
      ),
    );
  }

  void _showRescheduleDialog(Map<String, dynamic> req) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text('Manage Test Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                req['scheduled_start_override'] != null 
                  ? 'Currently overridden to start on: ${DateFormat('dd-MMM-yyyy').format(DateTime.parse(req['scheduled_start_override']).toLocal())}'
                  : 'Currently scheduled dynamically based on queue position.',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
              ),
              const SizedBox(height: 16),
              const Text('Do you want to override the start date for this test? Subsequent tests will slide accordingly.', style: TextStyle(fontSize: 13)),
            ],
          ),
          actions: [
            if (req['scheduled_start_override'] != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await _labController.updateLabRequest(
                      id: req['id'],
                      status: req['status'],
                      scheduledStartOverride: 'clear', // Clear override command
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Schedule override cleared!'), backgroundColor: Colors.green),
                    );
                    _fetchData();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error clearing override: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text('Clear Override', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppTheme.primaryColor,
                          onPrimary: Colors.white,
                          onSurface: AppTheme.textPrimaryColor,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (pickedDate != null && mounted) {
                  try {
                    final String formattedDate = pickedDate.toUtc().toIso8601String();
                    await _labController.updateLabRequest(
                      id: req['id'],
                      status: req['status'],
                      scheduledStartOverride: formattedDate,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Test rescheduled to ${DateFormat('dd-MMM-yyyy').format(pickedDate)}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _fetchData();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error rescheduling test: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: const Text('Choose Date', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showDelayDialog(Map<String, dynamic> req) {
    final controller = TextEditingController(text: req['delay_reason'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.logoRed, size: 28),
              SizedBox(width: 8),
              Text('Log Delay / Pause Reason', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record the reason why this test is paused or delayed (e.g. machine breakdown, queue overload). This will notify the prescribing doctor and adjust calculations.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  maxLines: 3,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter a delay reason';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Delay Reason',
                    hintText: 'Describe the issue...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final reason = controller.text.trim();
                Navigator.pop(ctx);

                try {
                  await _labController.updateLabRequest(
                    id: req['id'],
                    status: req['status'],
                    delayReason: reason,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delay reason updated successfully!'), backgroundColor: Colors.green),
                  );
                  _fetchData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error logging delay: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.logoRed),
              child: const Text('Save Delay', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPriorityBadge(String? priority) {
    final cleanPriority = priority ?? 'Normal';
    Color color;
    Color bgColor;

    switch (cleanPriority) {
      case 'Emergency':
        color = Colors.red.shade900;
        bgColor = Colors.red.shade50;
        break;
      case 'Urgent':
        color = Colors.orange.shade900;
        bgColor = Colors.orange.shade50;
        break;
      default:
        color = Colors.green.shade900;
        bgColor = Colors.green.shade50;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        cleanPriority,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildCompletionStatusBadge(String? status) {
    final cleanStatus = status ?? 'On Time';
    Color color;
    Color bgColor;

    switch (cleanStatus) {
      case 'Delayed':
        color = Colors.red.shade900;
        bgColor = Colors.red.shade50;
        break;
      case 'Early':
        color = Colors.blue.shade900;
        bgColor = Colors.blue.shade50;
        break;
      default:
        color = Colors.green.shade900;
        bgColor = Colors.green.shade50;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        cleanStatus,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  void _showResultsEntryDialog(Map<String, dynamic> req) {
    final testName = req['test_name'] ?? '';
    final List<Map<String, String>> initialFields = [];

    // Check if result_details already exists in database
    List resultsList = [];
    if (req['result_details'] != null) {
      if (req['result_details'] is String) {
        try {
          resultsList = jsonDecode(req['result_details']);
        } catch (_) {}
      } else if (req['result_details'] is List) {
        resultsList = req['result_details'];
      }
    }

    if (resultsList.isNotEmpty) {
      for (final item in resultsList) {
        initialFields.add({
          'parameter': (item['parameter'] ?? '').toString(),
          'value': (item['value'] ?? '').toString(),
          'unit': (item['unit'] ?? '').toString(),
          'reference_range': (item['reference_range'] ?? '').toString(),
        });
      }
    } else {
      // Pre-populate fields based on test type
      if (testName.toString().contains('Complete Blood Count') || testName.toString().contains('CBC')) {
        initialFields.addAll([
          {'parameter': 'Haemoglobin', 'value': '', 'unit': 'g/dL', 'reference_range': '13.0 - 17.0 (M), 12.0 - 16.0 (F)'},
          {'parameter': 'WBC Count', 'value': '', 'unit': 'cells/uL', 'reference_range': '4000 - 11000'},
          {'parameter': 'RBC Count', 'value': '', 'unit': 'million/uL', 'reference_range': '4.0 - 5.5'},
          {'parameter': 'Platelets', 'value': '', 'unit': 'cells/uL', 'reference_range': '150000 - 450000'},
          {'parameter': 'PCV / Hematocrit', 'value': '', 'unit': '%', 'reference_range': '36 - 50'},
        ]);
      } else if (testName.toString().contains('Lipid')) {
        initialFields.addAll([
          {'parameter': 'Total Cholesterol', 'value': '', 'unit': 'mg/dL', 'reference_range': '< 200'},
          {'parameter': 'Triglycerides', 'value': '', 'unit': 'mg/dL', 'reference_range': '< 150'},
          {'parameter': 'HDL Cholesterol', 'value': '', 'unit': 'mg/dL', 'reference_range': '> 40'},
          {'parameter': 'LDL Cholesterol', 'value': '', 'unit': 'mg/dL', 'reference_range': '< 100'},
        ]);
      } else if (testName.toString().contains('Thyroid') || testName.toString().contains('TSH')) {
        initialFields.addAll([
          {'parameter': 'TSH (Thyroid Stimulating Hormone)', 'value': '', 'unit': 'uIU/mL', 'reference_range': '0.45 - 4.5'},
          {'parameter': 'Free T4', 'value': '', 'unit': 'ng/dL', 'reference_range': '0.8 - 1.8'},
          {'parameter': 'Free T3', 'value': '', 'unit': 'pg/mL', 'reference_range': '2.3 - 4.2'},
        ]);
      } else if (testName.toString().contains('Urinalysis') || testName.toString().contains('Urine')) {
        initialFields.addAll([
          {'parameter': 'Color', 'value': '', 'unit': '', 'reference_range': 'Pale Yellow'},
          {'parameter': 'Appearance', 'value': '', 'unit': '', 'reference_range': 'Clear'},
          {'parameter': 'pH', 'value': '', 'unit': '', 'reference_range': '4.5 - 8.0'},
          {'parameter': 'Specific Gravity', 'value': '', 'unit': '', 'reference_range': '1.005 - 1.030'},
          {'parameter': 'Protein', 'value': '', 'unit': '', 'reference_range': 'Negative'},
          {'parameter': 'Glucose', 'value': '', 'unit': '', 'reference_range': 'Negative'},
        ]);
      } else if (testName.toString().toLowerCase().contains('x-ray') ||
          testName.toString().toLowerCase().contains('xray') ||
          testName.toString().toLowerCase().contains('ultrasound') ||
          testName.toString().toLowerCase().contains('mri') ||
          testName.toString().toLowerCase().contains('scan') ||
          testName.toString().toLowerCase().contains('image') ||
          testName.toString().toLowerCase().contains('usg')) {
        initialFields.addAll([
          {'parameter': 'Radiology Finding', 'value': '', 'unit': '', 'reference_range': 'Normal'},
          {'parameter': 'Impression', 'value': '', 'unit': '', 'reference_range': 'Normal'},
        ]);
      } else {
        // Default dynamic single field
        initialFields.add({'parameter': 'Observation', 'value': '', 'unit': '', 'reference_range': 'Normal'});
      }
    }

    final isXrayOrImage = testName.toString().toLowerCase().contains('x-ray') ||
        testName.toString().toLowerCase().contains('xray') ||
        testName.toString().toLowerCase().contains('ultrasound') ||
        testName.toString().toLowerCase().contains('mri') ||
        testName.toString().toLowerCase().contains('scan') ||
        testName.toString().toLowerCase().contains('image') ||
        testName.toString().toLowerCase().contains('usg');

    final remarksController = TextEditingController(text: req['remarks'] ?? '');
    final attachmentController = TextEditingController(
      text: (req['attachment_url'] != null && req['attachment_url'].toString().isNotEmpty)
          ? req['attachment_url']
          : 'report_${req['patient_display_id'] ?? 'SPMC'}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}.${isXrayOrImage ? 'png' : 'pdf'}'
    );
    final formKey = GlobalKey<FormState>();
    final machineName = _getMachineName(testName);
    int machineFetchCount = 0;
    bool isMachineFetching = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.biotech_outlined, color: AppTheme.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enter Test Results', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${req['test_name']} • Patient: ${req['patient_name']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 650,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TEST VALUES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                            if (isMachineFetching)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Connecting to $machineName...',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              )
                            else
                              TextButton.icon(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  setDialogState(() {
                                    isMachineFetching = true;
                                  });
                                  await Future.delayed(const Duration(seconds: 1));
                                  _simulateMachineFetch(initialFields);
                                  if (isXrayOrImage) {
                                    if (testName.toString().toLowerCase().contains('ultrasound') ||
                                        testName.toString().toLowerCase().contains('usg')) {
                                      attachmentController.text = 'ultrasound.png';
                                    } else {
                                      attachmentController.text = 'chest_xray.png';
                                    }
                                  }
                                  setDialogState(() {
                                    machineFetchCount++;
                                    isMachineFetching = false;
                                  });
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Imported results from $machineName analyzer successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.settings_input_component, size: 14),
                                label: const Text(
                                  'Fetch from Machine',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          key: ValueKey('list_$machineFetchCount'),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: initialFields.length,
                          itemBuilder: (context, fIdx) {
                            final field = initialFields[fIdx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      initialValue: field['parameter'],
                                      onChanged: (v) {
                                        field['parameter'] = v;
                                        setDialogState(() {});
                                      },
                                      maxLength: 50,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        labelText: 'Parameter',
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(),
                                        counterText: '',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: field['value'],
                                      onChanged: (v) => field['value'] = v,
                                      maxLength: _getMaxLength(field['parameter'] ?? ''),
                                      keyboardType: _isNumericField(field['parameter'] ?? '')
                                          ? const TextInputType.numberWithOptions(decimal: true)
                                          : TextInputType.text,
                                      inputFormatters: _isNumericField(field['parameter'] ?? '')
                                          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                                          : null,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          final param = (field['parameter'] ?? '').trim();
                                          if (param.isEmpty || param.toLowerCase() == 'new parameter') {
                                            return 'Please enter observed value';
                                          }
                                          return 'Please enter $param';
                                        }
                                        if (_isNumericField(field['parameter'] ?? '')) {
                                          final numValue = double.tryParse(v.trim());
                                          if (numValue == null) {
                                            return 'Must be numeric';
                                          }
                                        }
                                        return null;
                                      },
                                      style: const TextStyle(fontSize: 13),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        labelText: 'Observed',
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(),
                                        counterText: '',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      initialValue: field['unit'],
                                      onChanged: (v) => field['unit'] = v,
                                      maxLength: 20,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        labelText: 'Unit',
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(),
                                        counterText: '',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: field['reference_range'],
                                      onChanged: (v) => field['reference_range'] = v,
                                      maxLength: 50,
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        labelText: 'Normal Range',
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(),
                                        counterText: '',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                    onPressed: () {
                                      initialFields.removeAt(fIdx);
                                      setDialogState(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            initialFields.add({'parameter': 'New Parameter', 'value': '', 'unit': '', 'reference_range': ''});
                            setDialogState(() {});
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Test Parameter Row'),
                        ),
                        const SizedBox(height: 24),
                        const Text('REMARKS & FILE REFERENCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                        const SizedBox(height: 12),
                         TextFormField(
                          controller: remarksController,
                          maxLines: 2,
                          maxLength: 250,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'Observation Remarks',
                            filled: true,
                            fillColor: AppTheme.backgroundColor,
                            border: const OutlineInputBorder(borderSide: BorderSide.none),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: attachmentController,
                          maxLength: 100,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'Attach Report Document (File Name)',
                            filled: true,
                            fillColor: AppTheme.backgroundColor,
                            border: const OutlineInputBorder(borderSide: BorderSide.none),
                            prefixIcon: const Icon(Icons.attach_file, size: 16),
                            counterText: '',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: AppTheme.cancelButton,
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.logoRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    minimumSize: const Size(130, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final navigator = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    final user = Provider.of<AuthProvider>(context, listen: false).user;
                    
                    try {
                      await _labController.updateLabRequest(
                        id: req['id'],
                        status: 'Completed',
                        resultDetails: initialFields,
                        remarks: remarksController.text.trim(),
                        attachmentUrl: attachmentController.text.trim(),
                        processedBy: user?.id,
                      );
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Lab results saved and completed successfully'), backgroundColor: Colors.green),
                      );
                      _fetchData();
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error saving results: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('Submit Lab Report', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _isNumericField(String parameterName) {
    final name = parameterName.toLowerCase().trim();
    if (name.isEmpty) return true;
    const textParams = [
      'color', 
      'appearance', 
      'protein', 
      'glucose', 
      'finding', 
      'impression', 
      'remark', 
      'result', 
      'status',
      'culture',
      'organism',
      'growth',
      'epithelial',
      'pus cells',
      'rbcs'
    ];
    for (var param in textParams) {
      if (name.contains(param)) {
        return false;
      }
    }
    return true;
  }

  int _getMaxLength(String parameterName) {
    final name = parameterName.toLowerCase().trim();
    if (!_isNumericField(name)) {
      return 250;
    }
    if (name.contains('platelet')) {
      return 6;
    }
    return 5;
  }

  String _formatDate(String? dbDateStr) {
    if (dbDateStr == null || dbDateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dbDateStr).toLocal();
      return DateFormat('dd-MMM-yyyy hh:mm a').format(dt);
    } catch (_) {
      return dbDateStr;
    }
  }

  String _getMachineName(String testName) {
    final lower = testName.toLowerCase();
    if (lower.contains('complete blood count') || lower.contains('cbc')) {
      return 'Mindray BC-5000 Hematology';
    } else if (lower.contains('lipid') || lower.contains('thyroid') || lower.contains('tsh') || lower.contains('metabolic')) {
      return 'Cobas c311 Biochemistry';
    } else if (lower.contains('urinalysis') || lower.contains('urine')) {
      return 'Sysmex UC-3500 Urine';
    } else if (lower.contains('x-ray') || lower.contains('xray') || lower.contains('ultrasound') || lower.contains('mri') || lower.contains('scan') || lower.contains('image') || lower.contains('usg')) {
      return 'GE PACS DICOM Imaging';
    }
    return 'Lab Analyzer';
  }

  void _simulateMachineFetch(List<Map<String, String>> fields) {
    for (final field in fields) {
      final param = (field['parameter'] ?? '').toLowerCase();
      if (param.contains('haemoglobin') || param.contains('hemoglobin')) {
        field['value'] = '14.5';
      } else if (param.contains('wbc')) {
        field['value'] = '6800';
      } else if (param.contains('rbc')) {
        field['value'] = '4.75';
      } else if (param.contains('platelets')) {
        field['value'] = '275000';
      } else if (param.contains('pcv') || param.contains('hematocrit')) {
        field['value'] = '41.8';
      } else if (param.contains('total cholesterol')) {
        field['value'] = '188';
      } else if (param.contains('triglycerides')) {
        field['value'] = '125';
      } else if (param.contains('hdl')) {
        field['value'] = '48';
      } else if (param.contains('ldl')) {
        field['value'] = '98';
      } else if (param.contains('tsh')) {
        field['value'] = '2.34';
      } else if (param.contains('free t4')) {
        field['value'] = '1.18';
      } else if (param.contains('free t3')) {
        field['value'] = '2.95';
      } else if (param.contains('color')) {
        field['value'] = 'Pale Yellow';
      } else if (param.contains('appearance')) {
        field['value'] = 'Clear';
      } else if (param.contains('ph')) {
        field['value'] = '6.0';
      } else if (param.contains('specific gravity')) {
        field['value'] = '1.012';
      } else if (param.contains('protein')) {
        field['value'] = 'Negative';
      } else if (param.contains('glucose')) {
        field['value'] = 'Negative';
      } else if (param.contains('finding')) {
        field['value'] = 'Lungs clear. No focal consolidation, effusion or pneumothorax.';
      } else if (param.contains('impression')) {
        field['value'] = 'No active cardiopulmonary disease.';
      } else if (param.contains('observation')) {
        field['value'] = 'Normal';
      } else {
        field['value'] = 'Normal';
      }
    }
  }

  Widget _buildResourcesView(bool isMobile) {
    if (_isLoadingResources) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lab Resources Management', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 4),
          const Text('Manage shifts, test assignments, technician leaves, and machine operating status.', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
          const SizedBox(height: 24),
          
          if (!isMobile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTechniciansListCard()),
                const SizedBox(width: 24),
                Expanded(child: _buildMachinesListCard()),
              ],
            )
          else ...[
            _buildTechniciansListCard(),
            const SizedBox(height: 24),
            _buildMachinesListCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildTechniciansListCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.people_outline, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text('Technicians Shift Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const Divider(height: 24, color: AppTheme.borderColor),
          if (_technicians.isEmpty)
            const Center(child: Text('No technician data loaded.'))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _technicians.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 20, color: AppTheme.borderColor),
              itemBuilder: (ctx, idx) {
                final tech = _technicians[idx];
                final List testTypes = tech['assigned_test_types'] is String 
                    ? json.decode(tech['assigned_test_types']) 
                    : (tech['assigned_test_types'] ?? []);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tech['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text('ID: ${tech['employee_id']} • Shift: ${tech['shift_start']}-${tech['shift_end']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                            ],
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: _getTechStatusColor(tech['status']).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _getTechStatusColor(tech['status']).withOpacity(0.3), width: 0.5),
                            ),
                            child: DropdownButton<String>(
                              value: tech['status'] ?? 'Available',
                              icon: Icon(Icons.arrow_drop_down, size: 16, color: _getTechStatusColor(tech['status'])),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getTechStatusColor(tech['status'])),
                              onChanged: (newStatus) async {
                                if (newStatus != null) {
                                  try {
                                    await _labController.updateTechnicianStatus(id: tech['id'], status: newStatus);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${tech['name']} status updated to $newStatus'), backgroundColor: Colors.green),
                                    );
                                    _fetchData();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                              items: ['Available', 'Busy', 'On Leave', 'Sick Leave', 'Training'].map((st) {
                                return DropdownMenuItem<String>(
                                  value: st,
                                  child: Text(st),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: testTypes.map<Widget>((tt) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(tt.toString(), style: const TextStyle(fontSize: 10, color: AppTheme.textPrimaryColor)),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Color _getTechStatusColor(String? status) {
    switch (status) {
      case 'Available':
        return Colors.green;
      case 'Busy':
        return Colors.orange;
      case 'On Leave':
      case 'Sick Leave':
        return Colors.red;
      case 'Training':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildMachinesListCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_outlined, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text('Analyzer Equipment Operating Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const Divider(height: 24, color: AppTheme.borderColor),
          if (_machines.isEmpty)
            const Center(child: Text('No machine data loaded.'))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _machines.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 20, color: AppTheme.borderColor),
              itemBuilder: (ctx, idx) {
                final mach = _machines[idx];
                final List supported = mach['supported_test_types'] is String 
                    ? json.decode(mach['supported_test_types']) 
                    : (mach['supported_test_types'] ?? []);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(mach['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text('Type: ${mach['machine_type']} • Capacity: ${mach['daily_capacity'] ?? 'Unlimited'}/day', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                            ],
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: _getMachineStatusColor(mach['status']).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _getMachineStatusColor(mach['status']).withOpacity(0.3), width: 0.5),
                            ),
                            child: DropdownButton<String>(
                              value: mach['status'] ?? 'Active',
                              icon: Icon(Icons.arrow_drop_down, size: 16, color: _getMachineStatusColor(mach['status'])),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getMachineStatusColor(mach['status'])),
                              onChanged: (newStatus) async {
                                if (newStatus != null) {
                                  try {
                                    await _labController.updateMachineStatus(id: mach['id'], status: newStatus);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${mach['name']} status updated to $newStatus'), backgroundColor: Colors.green),
                                    );
                                    _fetchData();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                              items: ['Active', 'Busy', 'Maintenance', 'Breakdown', 'Calibration'].map((st) {
                                return DropdownMenuItem<String>(
                                  value: st,
                                  child: Text(st),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: supported.map<Widget>((tt) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(tt.toString(), style: const TextStyle(fontSize: 10, color: AppTheme.textPrimaryColor)),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Color _getMachineStatusColor(String? status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Busy':
        return Colors.orange;
      case 'Maintenance':
        return Colors.blue;
      case 'Breakdown':
        return Colors.red;
      case 'Calibration':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
