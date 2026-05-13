import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/nurse_widgets.dart' hide PatientModel;
import '../controllers/patient_controller.dart';
import '../models/patient_model.dart';
import 'login_page.dart';
import 'new_patient_registration.dart';
import 'patients_view.dart';
import 'appointments_view.dart';
import 'doctors_view.dart';
import 'nurse_profile_view.dart';
import '../widgets/access_denied_widget.dart';
import '../controllers/appointment_controller.dart';
import '../models/appointment_model.dart';
import '../utils/logout_helper.dart';
import '../models/user_model.dart';

class NurseDashboardScreen extends StatefulWidget {
  const NurseDashboardScreen({Key? key}) : super(key: key);

  @override
  State<NurseDashboardScreen> createState() => _NurseDashboardScreenState();
}

class _NurseDashboardScreenState extends State<NurseDashboardScreen> {
  int _selectedIndex = 0;
  bool _isRegisteringPatient = false;
  PatientModel? _patientToComplete;
  bool _forceBookingForm = false;
  PatientModel? _selectedPatientForBooking;
  UserModel? _selectedDoctorForBooking;
  final FocusNode _mainFocusNode = FocusNode();
  List<PatientModel> _dbPatients = [];
  String? _patientError;
  final PatientController _patientController = PatientController();
  final AppointmentController _appointmentController = AppointmentController();
  bool _isLoadingPatients = false;
  List<AppointmentModel> _dbAppointments = [];
  bool _isLoadingAppointments = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([_fetchPatients(), _fetchAppointments()]);
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoadingAppointments = true);
    try {
      final appointments = await _appointmentController.fetchAppointments();
      if (mounted) setState(() => _dbAppointments = appointments);
    } catch (e) {
      debugPrint('Error fetching appointments: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAppointments = false);
    }
  }

  Future<void> _fetchPatients() async {
    setState(() {
      _isLoadingPatients = true;
      _patientError = null;
    });
    try {
      final patients = await _patientController.fetchPatients();
      if (mounted) setState(() => _dbPatients = patients);
    } catch (e) {
      if (mounted) setState(() => _patientError = e.toString());
      debugPrint('Error fetching patients: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPatients = false);
    }
  }

  @override
  void dispose() {
    _mainFocusNode.dispose();
    super.dispose();
  }

  void _changePage(int index, {bool isRegistering = false, bool forceBooking = false}) {
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
      _isRegisteringPatient = isRegistering;
      _forceBookingForm = forceBooking;
    });
    
    // Refresh data if switching to dashboard
    if (index == 0) {
      _fetchData();
    }
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
          patients: _dbPatients.map((p) => p.toJson()).toList(),
          onNewPatient: () => _changePage(1, isRegistering: true),
          onBookAppointment: () => _changePage(2, forceBooking: true),
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

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: isMobile ? Drawer(child: _buildSidebar(context)) : null,
      floatingActionButton: CustomSpeedDial(
        children: [
          if (Provider.of<AuthProvider>(
                context,
                listen: false,
              ).user?.hasPermission('add_patient') ??
              false)
            SpeedDialChild(
              label: 'New Patient',
              icon: Icons.person_add_alt_1_outlined,
              color: const Color(0xFF7FB547),
              onTap: () => _changePage(1, isRegistering: true),
            ),
          if (Provider.of<AuthProvider>(
                context,
                listen: false,
              ).user?.hasPermission('book_appointment') ??
              false)
            SpeedDialChild(
              label: 'Book Appointment',
              icon: Icons.calendar_month_outlined,
              color: const Color(0xFF0D5D9A),
              onTap: () => _changePage(2, forceBooking: true),
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
    );
  }

  Widget _buildMainContent(bool isMobile) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;

    if (_isRegisteringPatient) {
      if (user?.hasPermission('add_patient') ?? false) {
        return NewPatientRegistrationView(
          key: UniqueKey(),
          existingPatient: _patientToComplete,
          onBack: () {
            setState(() {
              _isRegisteringPatient = false;
              _patientToComplete = null;
            });
            _fetchPatients();
          },
        );
      }
      return const AccessDeniedWidget();
    }
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardView(isMobile);
      case 1:
        if (user?.hasPermission('view_patients') ?? false) {
          return PatientsView(
            patients: _dbPatients,
            isLoading: _isLoadingPatients,
            error: _patientError,
            onRegisterPatient: () => _changePage(1, isRegistering: true),
            onCompleteProfile: (patient) {
              setState(() => _patientToComplete = patient);
              _changePage(1, isRegistering: true);
            },
            onBookAppointment: (patient) {
              setState(() => _selectedPatientForBooking = patient);
              _changePage(2, forceBooking: true);
            },
            onRefresh: _fetchPatients,
          );
        }
        return const AccessDeniedWidget();
      case 2:
        if (user?.hasPermission('book_appointment') ?? false) {
          final showForm = _forceBookingForm;
          final initialPatient = _selectedPatientForBooking;
          final initialDoctor = _selectedDoctorForBooking;
          _forceBookingForm = false; // Reset for next time
          _selectedPatientForBooking = null; // Clear for next time
          _selectedDoctorForBooking = null; // Clear for next time
          return AppointmentsView(
            key: showForm ? UniqueKey() : null,
            startWithBookingForm: showForm,
            initialPatient: initialPatient,
            initialDoctor: initialDoctor,
          );
        }
        return const AccessDeniedWidget();
      case 3:
        return DoctorsView(
          onBookAppointment: (doctor) {
            setState(() => _selectedDoctorForBooking = doctor);
            _changePage(2, forceBooking: true);
          },
        );
      case 4:
        return const NurseProfileView();
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
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
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
                        'assets/image/full_logo.png',
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
                      _buildSidebarItem(
                        0,
                        Icons.dashboard_outlined,
                        'Dashboard',
                      ),
                      if (user?.hasPermission('view_patients') ?? false)
                        _buildSidebarItem(1, Icons.people_outline, 'Patients'),
                      if (user?.hasPermission('book_appointment') ?? false)
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
                      _buildSidebarItem(4, Icons.person_outline, 'Profile'),
                      // _buildSidebarItem(4, Icons.home_outlined, 'Home Care'),
                      // _buildSidebarItem(5, Icons.inventory_2_outlined, 'Inventory'),
                      // _buildSidebarItem(6, Icons.bar_chart_outlined, 'Reports'),
                      // _buildSidebarItem(
                      //   7,
                      //   Icons.psychology_outlined,
                      //   'AI Insights',
                      // ),
                    ],
                  ),
                ),
              ),

              // Bottom Area (Fixed)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // User Profile Area
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: user == null
                        ? const SizedBox.shrink()
                        : Row(
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

          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: TextFormField(
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: isMobile ? 'Search...' : 'Quick search...',
                  hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondaryColor),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  fillColor: Colors.transparent,
                  filled: true,
                  contentPadding: const EdgeInsets.only(top: 2),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
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
              style: AppTheme.primaryButton.copyWith(
                minimumSize: MaterialStateProperty.all(const Size(80, 40)),
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
        Row(
          children: [
            Expanded(
              child: Text(
                user != null ? 'Hello, ${user.fullname}' : 'Dashboard',
                style: Theme.of(context).textTheme.displayLarge,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
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
    final int totalPatients = _dbPatients.length;
    final String today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final int todaysApptsCount = _dbAppointments
        .where(
          (a) =>
              (a.appointmentDate == today || a.appointmentDate.startsWith(today)) &&
              a.status.toLowerCase() != 'cancelled',
        )
        .length;

    if (isMobile) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildStatCard(
            'Total Patients',
            totalPatients.toString(),
            '',
            Icons.people_outline,
            Colors.blue,
            isMobile,
          ),
          _buildStatCard(
            'Today\'s Appointments',
            todaysApptsCount.toString(),
            '',
            Icons.calendar_today_outlined,
            Colors.indigo,
            isMobile,
          ),
          _buildStatCard(
            'Active Home Care',
            '48',
            '',
            Icons.monitor_heart_outlined,
            Colors.green,
            isMobile,
          ),
          _buildStatCard(
            'Patient Visits',
            '156',
            '',
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
            totalPatients.toString(),
            '',
            Icons.people_outline,
            Colors.blue,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Today\'s Appointments',
            todaysApptsCount.toString(),
            '',
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
            '',
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
            '',
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
              const Expanded(
                child: Text(
                  'Recent Patients',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 1),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingPatients)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_dbPatients.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No patients found',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._dbPatients.take(4).map((p) {
              final parts = p.name.trim().split(' ');
              final initials = parts.isNotEmpty
                  ? parts[0][0].toUpperCase()
                  : '?';
              return _buildPatientItem(
                p.name,
                '${p.age}y • ${p.gender}',
                'Registered', // Database model doesn't have registration time yet easily available in this format, using a status
                p.isQuickRegister ? 'Quick' : 'Standard',
                p.isQuickRegister ? Colors.purple : Colors.blue,
              );
            }).toList(),
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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  info,
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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
              const Expanded(
                child: Text(
                  'Upcoming Appointments',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 2),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingAppointments)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_dbAppointments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No appointments found',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            () {
              final String today = DateFormat(
                'dd/MM/yyyy',
              ).format(DateTime.now());
              final List<AppointmentModel> todaysAppts = _dbAppointments
                  .where(
                    (a) =>
                        a.appointmentDate == today ||
                        a.appointmentDate.startsWith(today),
                  )
                  .toList();

              // Sort by time
              todaysAppts.sort(
                (a, b) => a.appointmentTime.compareTo(b.appointmentTime),
              );

              // Take last three
              final displayAppts = todaysAppts.length > 3
                  ? todaysAppts.sublist(todaysAppts.length - 3)
                  : todaysAppts;

              if (displayAppts.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No appointments for today',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              return Column(
                children: displayAppts.map((a) {
                  return _buildAppointmentItem(
                    a.patientName,
                    a.doctorName,
                    a.appointmentTime,
                    a.department,
                  );
                }).toList(),
              );
            }(),
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
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
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
}
