import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../controllers/auth_provider.dart';
import '../widgets/nurse_widgets.dart';
import 'login_page.dart';
import 'new_patient_registration.dart';

class NurseDashboardScreen extends StatefulWidget {
  const NurseDashboardScreen({Key? key}) : super(key: key);

  @override
  State<NurseDashboardScreen> createState() => _NurseDashboardScreenState();
}

class _NurseDashboardScreenState extends State<NurseDashboardScreen> {
  int _selectedIndex = 0;
  bool _isRegisteringPatient = false;
  final FocusNode _mainFocusNode = FocusNode();
  List<dynamic> _dbPatients = [];
  bool _isLoadingPatients = false;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    setState(() => _isLoadingPatients = true);
    try {
      final String baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:3000';
      final response = await http.get(Uri.parse('$baseUrl/api/patients'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          if (decoded is List) {
            _dbPatients = List<dynamic>.from(decoded);
          } else {
            _dbPatients = [];
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching patients: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPatients = false);
      }
    }
  }

  @override
  void dispose() {
    _mainFocusNode.dispose();
    super.dispose();
  }

  void _showSearchOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Search',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return SearchOverlay(
          patients: _dbPatients,
          onNewPatient: () {
            setState(() {
              _selectedIndex = 1;
              _isRegisteringPatient = true;
            });
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim1),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return Focus(
      focusNode: _mainFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.slash) {
          _showSearchOverlay();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        drawer: isMobile ? Drawer(child: _buildSidebar(context)) : null,
        floatingActionButton: CustomSpeedDial(
          children: [
            SpeedDialChild(
              label: 'New Patient',
              icon: Icons.person_add_alt_1_outlined,
              color: const Color(0xFF7FB547),
              onTap: () => setState(() {
                _selectedIndex = 1;
                _isRegisteringPatient = true;
              }),
            ),
            SpeedDialChild(
              label: 'Book Appointment',
              icon: Icons.calendar_month_outlined,
              color: const Color(0xFF0D5D9A),
              onTap: () {},
            ),
          ],
        ),
        body: Row(
          children: [
            // Sidebar (only on desktop)
            if (!isMobile) _buildSidebar(context),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  _buildHeader(context, isMobile),
                  Expanded(child: _buildMainContent(isMobile)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isMobile) {
    if (_isRegisteringPatient) {
      return NewPatientRegistrationView(
        key: UniqueKey(),
        onBack: () {
          setState(() => _isRegisteringPatient = false);
          _fetchPatients();
        },
      );
    }
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardView(isMobile);
      case 1:
        return _buildPatientsView(isMobile);
      default:
        return _buildDashboardView(isMobile);
    }
  }

  Widget _buildDashboardView(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreeting(),
          const SizedBox(height: 24),
          _buildStatsRow(isMobile),
          const SizedBox(height: 24),
          if (isMobile) ...[
            _buildAlertsSection(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildRecentPatients(),
            const SizedBox(height: 24),
            _buildUpcomingAppointments(),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildAlertsSection(),
                      const SizedBox(height: 24),
                      _buildRecentPatients(),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      _buildUpcomingAppointments(),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.only(
              left: 24,
              top: 0,
              bottom: 0,
              right: 24,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    // color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'image/full_logo.png',
                    width: 100,
                    height: 89,
                  ),
                ),
              ],
            ),
          ),

          // Navigation Items (Scrollable Area)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  _buildSidebarItem(0, Icons.dashboard_outlined, 'Dashboard'),
                  _buildSidebarItem(1, Icons.people_outline, 'Patients'),
                  _buildSidebarItem(
                    2,
                    Icons.calendar_today_outlined,
                    'Appointments',
                  ),
                  _buildSidebarItem(
                    3,
                    Icons.medical_services_outlined,
                    'Doctors',
                  ),
                  _buildSidebarItem(4, Icons.home_outlined, 'Home Care'),
                  _buildSidebarItem(5, Icons.inventory_2_outlined, 'Inventory'),
                  _buildSidebarItem(6, Icons.bar_chart_outlined, 'Reports'),
                  _buildSidebarItem(
                    7,
                    Icons.psychology_outlined,
                    'AI Insights',
                  ),
                ],
              ),
            ),
          ),

          // Bottom Area (Fixed)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bottom Quick Actions Area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSmallAction('Quick Search', '/'),
                      _buildSmallAction('New Patient', 'Alt+N'),
                      _buildSmallAction('Book Appl.', 'Alt+B'),
                    ],
                  ),
                ),
              ),

              // User Profile Area
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    final user = auth.user;
                    if (user == null) return const SizedBox.shrink();
                    return Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppTheme.primaryColor,
                          radius: 18,
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.fullname,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user.role,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.logout,
                            size: 18,
                            color: AppTheme.textSecondaryColor,
                          ),
                          onPressed: () {
                            auth.logout();
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() {
        _selectedIndex = index;
        _isRegisteringPatient = false;
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondaryColor,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallAction(String label, String shortcut) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Text(
              shortcut,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      height: isMobile ? 80 : 90,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      child: Row(
        children: [
          if (isMobile) ...[
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(
                  Icons.menu,
                  color: AppTheme.textSecondaryColor,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Search Bar (Flexible on mobile)
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextFormField(
                decoration: InputDecoration(
                  hintText: isMobile ? 'Search...' : 'Quick search...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixText: isMobile ? null : '/',
                  suffixStyle: const TextStyle(color: AppTheme.iconColor),
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                readOnly: true,
                onTap: _showSearchOverlay,
              ),
            ),
          ),

          if (!isMobile) ...[
            const SizedBox(width: 24),
            const Spacer(),
            const Icon(
              Icons.notifications_none_outlined,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(width: 16),
            const Icon(Icons.help_outline, color: AppTheme.textSecondaryColor),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size(80, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Share', style: TextStyle(fontSize: 14)),
            ),
          ],
          SizedBox(width: isMobile ? 12 : 24),

          // Date & Time
          const LiveClock(),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user != null ? 'Hello, ${user.fullname}' : 'Dashboard',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Welcome back! Here\'s your hospital overview',
          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    if (isMobile) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildStatCard(
            'Total Patients',
            '1,248',
            '+12%',
            Icons.people_outline,
            Colors.blue,
            isMobile,
          ),
          _buildStatCard(
            'Today\'s Appointments',
            '32',
            '+5',
            Icons.calendar_today_outlined,
            Colors.indigo,
            isMobile,
          ),
          _buildStatCard(
            'Active Home Care',
            '48',
            '+8%',
            Icons.monitor_heart_outlined,
            Colors.green,
            isMobile,
          ),
          _buildStatCard(
            'Patient Visits',
            '156',
            '+18%',
            Icons.trending_up,
            Colors.cyan,
            isMobile,
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Patients',
            '1,248',
            '+12%',
            Icons.people_outline,
            Colors.blue,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Today\'s Appointments',
            '32',
            '+5',
            Icons.calendar_today_outlined,
            Colors.indigo,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Active Home Care',
            '48',
            '+8%',
            Icons.monitor_heart_outlined,
            Colors.green,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Patient Visits',
            '156',
            '+18%',
            Icons.trending_up,
            Colors.cyan,
            isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String change,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    return StatCard(
      title: title,
      value: value,
      subLabel: change,
      icon: icon,
      color: color,
      isMobile: isMobile,
    );
  }

  Widget _buildAlertsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.error_outline,
                color: AppTheme.alertTextColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Alerts & Notifications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAlertItem(
            AppTheme.alertBgColor,
            AppTheme.alertTextColor,
            'Low inventory: Rice stock running low (5kg remaining)',
            '10 mins ago',
          ),
          const SizedBox(height: 12),
          _buildAlertItem(
            AppTheme.infoBgColor,
            AppTheme.infoColor,
            '3 patients awaiting lab results',
            '30 mins ago',
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Color bg, Color textColor, String text, String time) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, Color(0xFF0D4D7A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          _buildActionButton(
            Icons.person_add_outlined,
            'Register New Patient',
            () {
              setState(() {
                _selectedIndex = 1;
                _isRegisteringPatient = true;
              });
            },
          ),
          _buildActionButton(
            Icons.calendar_month_outlined,
            'Book Appointment',
            () {},
          ),
          _buildActionButton(
            Icons.medical_services_outlined,
            'Check Inventory',
            () {},
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return QuickActionButton(icon: icon, label: label, onTap: onTap);
  }

  Widget _buildRecentPatients() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Patients',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              TextButton(onPressed: () {}, child: const Text('View All')),
            ],
          ),
          const SizedBox(height: 16),
          _buildPatientItem(
            'John Smith',
            '45y • Male',
            '10:30 AM',
            'Checked In',
            Colors.green,
          ),
          _buildPatientItem(
            'Sarah Johnson',
            '32y • Female',
            '9:15 AM',
            'Waiting',
            Colors.orange,
          ),
          _buildPatientItem(
            'Robert Brown',
            '58y • Male',
            'Yesterday',
            'Completed',
            Colors.grey,
          ),
          _buildPatientItem(
            'Emily Davis',
            '28y • Female',
            '2 days ago',
            'Completed',
            Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildPatientItem(
    String name,
    String info,
    String time,
    String status,
    Color statusColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.backgroundColor,
            child: Text(
              name.substring(0, 1),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  info,
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointments() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Appointments',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              TextButton(onPressed: () {}, child: const Text('View All')),
            ],
          ),
          const SizedBox(height: 16),
          _buildAppointmentItem(
            'Michael Wilson',
            'Dr. Amanda Lee',
            '11:00 AM',
            'Cardiology',
          ),
          _buildAppointmentItem(
            'Jessica Taylor',
            'Dr. Robert Chen',
            '11:30 AM',
            'General Medicine',
          ),
          _buildAppointmentItem(
            'David Martinez',
            'Dr. Sarah Kumar',
            '12:00 PM',
            'Orthopedics',
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentItem(
    String name,
    String doctor,
    String time,
    String dept,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            doctor,
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              dept,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderColor),
        ],
      ),
    );
  }

  Widget _buildPatientsView(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPatientsHeader(isMobile),
          const SizedBox(height: 24),
          _buildPatientsSearch(isMobile),
          const SizedBox(height: 32),
          const Text(
            'Recent Patients',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildRecentPatientsRow(isMobile),
          const SizedBox(height: 32),
          _buildPatientsTable(isMobile),
        ],
      ),
    );
  }

  Widget _buildPatientsHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patients',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage patient records and information',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
        if (!isMobile)
          ElevatedButton.icon(
            onPressed: () => setState(() => _isRegisteringPatient = true),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('New Patient'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 48), // Explicit width instead of infinity
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPatientsSearch(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppTheme.textSecondaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search patients...',
                      hintStyle: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildFilterButton('Gender')),
              const SizedBox(width: 8),
              Expanded(child: _buildFilterButton('Department')),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppTheme.textSecondaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name, phone number, or patient ID...',
                      hintStyle: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () => setState(() => _isRegisteringPatient = true),
          icon: const Icon(Icons.flash_on, size: 18),
          label: const Text(
            'Quick Register',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D5D9A),
            foregroundColor: Colors.white,
            minimumSize: const Size(160, 52),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
        const SizedBox(width: 12),
        _buildFilterButton('Gender'),
        const SizedBox(width: 8),
        _buildFilterButton('Department'),
      ],
    );
  }

  Widget _buildRecentPatientsRow(bool isMobile) {
    if (_isLoadingPatients) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_dbPatients.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Text('No recent patients found.'),
      );
    }

    final recentPatients = _dbPatients.take(3).toList();
    List<Widget> cards = [];
    
    for (int i = 0; i < recentPatients.length; i++) {
        final patient = recentPatients[i];
        String name = patient['name']?.toString() ?? 'Unknown';
        String age = patient['age']?.toString() ?? '-';
        String gender = patient['gender'] ?? '-';
        
        String initials = '?';
        if (name.trim().isNotEmpty) {
          final parts = name.trim().split(' ').where((p) => p.isNotEmpty).take(2).toList();
          if (parts.isNotEmpty) {
            initials = parts.map((p) => p[0].toUpperCase()).join('');
          }
        }
        
        cards.add(_buildPatientInfoCard(
          name, 
          '${age}y • $gender', 
          initials, 
          [] // Removed hardcoded tags
        ));
        
        if (i < recentPatients.length - 1) {
            cards.add(const SizedBox(width: 16));
        }
    }

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: cards),
      );
    }
    return Row(
      children: cards
          .map((c) => c is SizedBox ? c : Flexible(child: c))
          .toList(),
    );
  }

  Widget _buildPatientInfoCard(
    String name,
    String info,
    String initials,
    List<String> tags,
  ) {
    return PatientInfoCard(
      name: name,
      info: info,
      initials: initials,
      tags: tags,
      onView: () {},
      onBook: () {},
    );
  }

  Widget _buildPatientsTable(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFEDF2F7),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: _buildTableHeaderText('Name')),
                Expanded(child: _buildTableHeaderText('Age')),
                if (!isMobile) Expanded(child: _buildTableHeaderText('Gender')),
                if (!isMobile)
                  Expanded(flex: 2, child: _buildTableHeaderText('Contact')),
                if (!isMobile)
                  Expanded(flex: 2, child: _buildTableHeaderText('Last Visit')),
                Expanded(child: _buildTableHeaderText('Status')),
                Expanded(flex: 2, child: _buildTableHeaderText('Actions')),
              ],
            ),
          ),
          // Table Rows
          if (_isLoadingPatients)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_dbPatients.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('No patients found')),
            )
          else
            ..._dbPatients.map((patient) {
              List<String> tags = [];

              String name = patient['name']?.toString() ?? 'Unknown';
              String initials = '?';
              if (name.trim().isNotEmpty) {
                final parts = name.trim().split(' ').where((p) => p.isNotEmpty).take(2).toList();
                if (parts.isNotEmpty) {
                  initials = parts.map((p) => p[0].toUpperCase()).join('');
                }
              }
                  
              String createdAt = patient['created_at'] != null  
                  ? DateFormat('MMM dd, yyyy').format(DateTime.parse(patient['created_at']))
                  : 'Unknown';

              return Column(
                children: [
                  _buildPatientTableRow(
                    name,
                    patient['age']?.toString() ?? '-',
                    patient['gender'] ?? '-',
                    patient['phone'] ?? '-',
                    createdAt,
                    patient['status'] ?? 'Active',
                    initials,
                    tags,
                    isMobile,
                  ),
                  const Divider(height: 1),
                ],
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildTableHeaderText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: Color(0xFF4A5568),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildPatientTableRow(
    String name,
    String age,
    String gender,
    String contact,
    String lastVisit,
    String status,
    String initials,
    List<String> tags,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(
                    0xFF0D5D9A,
                  ), // Dark blue from image
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      if (tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            children: tags
                                .map((t) => HealthTag(label: t))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              age,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
            ),
          ),
          if (!isMobile)
            Expanded(
              child: Text(
                gender,
                style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
              ),
            ),
          if (!isMobile)
            Expanded(
              flex: 2,
              child: Text(
                contact,
                style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
              ),
            ),
          if (!isMobile)
            Expanded(
              flex: 2,
              child: Text(
                lastVisit,
                style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
              ),
            ),
          Expanded(child: StatusChip(status: status)),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                _buildActionLabel(
                  Icons.visibility_outlined,
                  'View',
                  const Color(0xFF3182CE),
                ),
                const SizedBox(width: 12),
                _buildActionLabel(
                  Icons.calendar_month_outlined,
                  'Book',
                  const Color(0xFF38A169),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionLabel(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {},
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: AppTheme.textSecondaryColor,
          ),
        ],
      ),
    );
  }
}
