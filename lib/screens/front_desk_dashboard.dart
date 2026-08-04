import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../core/routes/route_constants.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/nurse_widgets.dart' hide PatientModel;
import '../controllers/patient_controller.dart';
import '../models/patient_model.dart';
import 'new_patient_registration.dart';
import 'patients_view.dart';
import 'appointments_view.dart';
import 'doctors_view.dart';
import '../widgets/access_denied_widget.dart';
import '../controllers/appointment_controller.dart';
import '../models/appointment_model.dart';
import '../utils/logout_helper.dart';
import '../models/user_model.dart';
import '../controllers/nurse/nurse_controller.dart';
import '../widgets/custom_dropdown_search.dart';
import 'front_desk_admission_counter.dart';
import '../widgets/user_profile_dialog.dart';
import 'billing_management_view.dart';

class FrontDeskDashboardScreen extends StatefulWidget {
  final int initialIndex;
  final bool isRegisteringPatient;
  final bool forceBooking;
  final PatientModel? existingPatient;
  final PatientModel? viewPatient;
  final bool isEditingProfile;
  const FrontDeskDashboardScreen({
    Key? key,
    this.initialIndex = 0,
    this.isRegisteringPatient = false,
    this.forceBooking = false,
    this.existingPatient,
    this.viewPatient,
    this.isEditingProfile = false,
  }) : super(key: key);

  @override
  State<FrontDeskDashboardScreen> createState() => _FrontDeskDashboardScreenState();
}

class _FrontDeskDashboardScreenState extends State<FrontDeskDashboardScreen> {
  int _selectedIndex = 0;
  bool _isRegisteringPatient = false;
  PatientModel? _patientToComplete;
  PatientModel? _viewPatient;
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
    _selectedIndex = widget.initialIndex;
    _isRegisteringPatient = widget.isRegisteringPatient;
    _patientToComplete = widget.existingPatient;
    _viewPatient = widget.viewPatient;
    _forceBookingForm = widget.forceBooking;
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant FrontDeskDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex ||
        widget.isRegisteringPatient != oldWidget.isRegisteringPatient ||
        widget.forceBooking != oldWidget.forceBooking ||
        widget.existingPatient != oldWidget.existingPatient ||
        widget.viewPatient != oldWidget.viewPatient) {
      setState(() {
        _selectedIndex = widget.initialIndex;
        _isRegisteringPatient = widget.isRegisteringPatient;
        _patientToComplete = widget.existingPatient;
        _viewPatient = widget.viewPatient;
        _forceBookingForm = widget.forceBooking;
      });
    }
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

  void _changePage(
    int index, {
    bool isRegistering = false,
    bool forceBooking = false,
  }) {
    if (!mounted) return;
    switch (index) {
      case 0:
        context.go(AppRoutes.receptionDashboard);
        break;
      case 1:
        if (isRegistering) {
          context.go(AppRoutes.frontDeskNewPatient);
        } else {
          context.go(AppRoutes.frontDeskPatients);
        }
        break;
      case 2:
        if (forceBooking) {
          context.go(AppRoutes.frontDeskBookAppointment);
        } else {
          context.go(AppRoutes.frontDeskAppointments);
        }
        break;
      case 3:
        context.go(AppRoutes.frontDeskDoctors);
        break;
      case 4:
        context.go(AppRoutes.frontDeskAdmissionCounter);
        break;
      case 6:
        context.go(AppRoutes.frontDeskBilling);
        break;
      case 5:
        context.go(AppRoutes.frontDeskProfile);
        break;
      default:
        context.go(AppRoutes.receptionDashboard);
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
          onBookAppointment: (patientMap) {
            if (patientMap != null) {
              setState(() => _selectedPatientForBooking = PatientModel.fromJson(patientMap));
            }
            _changePage(2, forceBooking: true);
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

    return Scaffold(
      key: const ValueKey('front_desk_dashboard'),
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
              color: AppTheme.dangerColor,
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
                if (_selectedIndex != 0) _buildHeader(context, isMobile),
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
            context.go(AppRoutes.frontDeskPatients);
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
            initialSelectedPatient: _viewPatient,
            onRegisterPatient: () => _changePage(1, isRegistering: true),
            onCompleteProfile: (patient) {
              context.go(AppRoutes.frontDeskEditPatient, extra: patient);
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
        return const FrontDeskAdmissionCounterView();
      case 5:
        return FrontDeskProfileView(isEditing: widget.isEditingProfile);
      case 6:
        return const BillingManagementView();
      default:
        return _buildDashboardView(isMobile);
    }
  }

  Widget _buildDashboardView(bool isMobile) {
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
          child: SingleChildScrollView(
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
                        child: Column(children: [_buildUpcomingAppointments()]),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
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

              // Navigation Items (Scrollable Area)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      _buildSidebarItem(
                        4,
                        Icons.assignment_turned_in_outlined,
                        'Admission Counter',
                      ),
                      _buildSidebarItem(
                        6,
                        Icons.receipt_long_outlined,
                        'Billing & Invoices',
                      ),
                      _buildSidebarItem(
                        5,
                        Icons.person_outline,
                        'Profile',
                      ),
                    ],
                  ),
                ),
              ),

              // User Profile Area at Bottom
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
          child: InkWell(
            onTap: _showSearchOverlay,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 18,
                    color: AppTheme.textSecondaryColor,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Search anything...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
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

  Widget _buildGreeting() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                user != null ? 'Hello, ${user.rawFullname ?? ''}' : 'Dashboard',
                style: Theme.of(context).textTheme.displayLarge,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Welcome back! Here\'s your front desk overview',
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
              (a.appointmentDate == today ||
                  a.appointmentDate.startsWith(today)) &&
              a.status.toLowerCase() != 'cancelled',
        )
        .length;

    final int checkedInToday = _dbAppointments
        .where(
          (a) =>
              (a.appointmentDate == today ||
                  a.appointmentDate.startsWith(today)) &&
              a.status.toLowerCase() == 'checked in',
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
            'Registered registry',
            Icons.people_outline,
            Colors.blue,
            isMobile,
          ),
          _buildStatCard(
            'Today\'s Appointments',
            todaysApptsCount.toString(),
            'Scheduled today',
            Icons.calendar_today_outlined,
            Colors.indigo,
            isMobile,
          ),
          _buildStatCard(
            'Checked In',
            checkedInToday.toString(),
            'Arrived at clinic',
            Icons.check_circle_outline,
            Colors.green,
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
            'Registered registry',
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
            'Scheduled today',
            Icons.calendar_today_outlined,
            Colors.indigo,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Checked In Patients',
            checkedInToday.toString(),
            'Arrived at clinic',
            Icons.check_circle_outline,
            Colors.green,
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
                'Front Desk Notifications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAlertItem(
            AppTheme.infoBgColor,
            AppTheme.infoColor,
            'Check doctor slot schedules for updates before booking.',
            'Just now',
          ),
          const SizedBox(height: 12),
          _buildAlertItem(
            AppTheme.alertBgColor,
            AppTheme.alertTextColor,
            'Ensure all quick-registered patients complete profiles upon check-in.',
            '10 mins ago',
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
                onPressed: () => _changePage(1),
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
              return _buildPatientItem(
                p.name,
                '${p.age}y • ${p.gender}',
                'Registered',
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
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: CircleAvatar(
              backgroundColor: AppTheme.getAvatarColors(name)['bg'],
              child: Text(
                name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getAvatarColors(name)['text'],
                ),
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
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointments() {
    final String today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final upcoming = _dbAppointments
        .where(
          (a) =>
              (a.appointmentDate == today ||
                  a.appointmentDate.startsWith(today)) &&
              a.status.toLowerCase() != 'cancelled',
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Today\'s Queue',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => _changePage(2),
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
          else if (upcoming.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No appointments for today',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...upcoming.take(5).map((appt) {
              Color badgeColor;
              switch (appt.status.toLowerCase()) {
                case 'checked in':
                  badgeColor = Colors.green;
                  break;
                case 'completed':
                  badgeColor = Colors.blue;
                  break;
                case 'in consultation':
                  badgeColor = Colors.orange;
                  break;
                default:
                  badgeColor = Colors.amber.shade700;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appt.patientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Dr. ${appt.doctorName} • ${appt.appointmentTime}',
                            style: const TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        appt.status,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}

class FrontDeskProfileView extends StatefulWidget {
  final bool isEditing;
  const FrontDeskProfileView({Key? key, this.isEditing = false}) : super(key: key);

  @override
  State<FrontDeskProfileView> createState() => _FrontDeskProfileViewState();
}

class _FrontDeskProfileViewState extends State<FrontDeskProfileView> {
  bool _isEditingProfile = false;
  bool _isLoading = false;
  final NurseController _nurseController = NurseController();

  TextEditingController? __nameController;
  TextEditingController get _nameController => __nameController ??= TextEditingController();
  
  TextEditingController? __emailController;
  TextEditingController get _emailController => __emailController ??= TextEditingController();

  TextEditingController? __bioController;
  TextEditingController get _bioController => __bioController ??= TextEditingController();

  TextEditingController? __mobileController;
  TextEditingController get _mobileController => __mobileController ??= TextEditingController();

  TextEditingController? __shiftTypeController;
  TextEditingController get _shiftTypeController => __shiftTypeController ??= TextEditingController();

  TextEditingController? __slotStartController;
  TextEditingController get _slotStartController => __slotStartController ??= TextEditingController();

  TextEditingController? __slotEndController;
  TextEditingController get _slotEndController => __slotEndController ??= TextEditingController();

  List<String>? _availableDays;
  List<String>? _weeklyOffDays;
  List<String>? _specificLeaveDates;

  @override
  void initState() {
    super.initState();
    _isEditingProfile = widget.isEditing;
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant FrontDeskProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing != oldWidget.isEditing) {
      setState(() {
        _isEditingProfile = widget.isEditing;
      });
    }
  }

  void _initControllers() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _nameController.text = user?.rawFullname ?? '';
    _emailController.text = user?.email ?? '';
    _bioController.text = user?.bio ?? '';
    _mobileController.text = user?.mobile ?? '';

    _shiftTypeController.text = (user?.shiftType != null && user!.shiftType!.isNotEmpty)
          ? user.shiftType!
          : 'Day Shift';
    _slotStartController.text = user?.shiftStartTime ?? '';
    _slotEndController.text = user?.shiftEndTime ?? '';

    _availableDays = user?.workingDays != null ? List.from(user!.workingDays!) : [];
    final allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    _weeklyOffDays = allDays.where((d) => !_availableDays!.contains(d)).toList();
    
    _specificLeaveDates = user?.specificLeaveDates != null ? List.from(user!.specificLeaveDates!) : [];
  }

  @override
  void dispose() {
    __nameController?.dispose();
    __emailController?.dispose();
    __bioController?.dispose();
    __mobileController?.dispose();
    __shiftTypeController?.dispose();
    __slotStartController?.dispose();
    __slotEndController?.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    _weeklyOffDays = allDays
        .where((day) => !(_availableDays ?? []).contains(day))
        .toList();

    setState(() => _isLoading = true);
    try {
      final updatedUser = await _nurseController.updateProfile(
        fullname: _nameController.text,
        mobile: _mobileController.text,
        bio: _bioController.text,
        qualification: '',
        nursingRegistrationNumber: '',
        yearsOfExperience: '0',
        workingDays: _availableDays ?? [],
        shiftStartTime: _slotStartController.text,
        shiftEndTime: _slotEndController.text,
        shiftType: _shiftTypeController.text,
        registrationCertificate: '',
        weeklyOffDays: _weeklyOffDays ?? [],
        specificLeaveDates: _specificLeaveDates ?? [],
      );

      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).updateUser(updatedUser);
        setState(() {});
        GoRouter.of(context).go(AppRoutes.frontDeskProfile);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null && mounted) {
      controller.text = picked.format(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    if (_isEditingProfile) return _buildProfileEditView(isMobile);
    return _buildProfileDisplayView(isMobile);
  }

  Widget _buildProfileDisplayView(bool isMobile) {
    final user = Provider.of<AuthProvider>(context).user;
    const sectionSpacing = SizedBox(height: 24);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your personal details and duty schedule',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 12,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => GoRouter.of(context).go(AppRoutes.frontDeskProfileEdit),
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                      label: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
                      style: AppTheme.primaryButton.copyWith(
                        backgroundColor: MaterialStateProperty.all(AppTheme.logoRed),
                        minimumSize: MaterialStateProperty.all(const Size(double.infinity, 44)),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your personal details and duty schedule',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondaryColor,
                              ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => GoRouter.of(context).go(AppRoutes.frontDeskProfileEdit),
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                      label: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
                      style: AppTheme.primaryButton.copyWith(
                        backgroundColor: MaterialStateProperty.all(AppTheme.logoRed),
                        minimumSize: MaterialStateProperty.all(const Size(0, 48)),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            decoration: AppTheme.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 110, height: 110,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [AppTheme.primaryColor, Color(0xFF1E3A8A)]),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          user?.rawFullname?.isNotEmpty == true ? user!.rawFullname![0].toUpperCase() : 'F',
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.rawFullname ?? 'Front Desk', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
                          const SizedBox(height: 8),
                          Text(
                            user?.role ?? 'Front Desk',
                            style: const TextStyle(
                              color: Color(0xFFC53030),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 20),
                _buildDetailRow('Full Name', user?.rawFullname ?? '-', Icons.person_outline),
                _buildDetailRow('Staff ID', user?.staffUniqueId ?? '-', Icons.badge_outlined),
                _buildDetailRow('Email Address', user?.email ?? '-', Icons.alternate_email),
                _buildDetailRow('Mobile Number', user?.mobile ?? '-', Icons.phone_android_outlined),
                _buildDetailRow('Bio Summary', user?.bio ?? '-', Icons.description_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF0F5A8E)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF718096)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F5A8E)),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileEditView(bool isMobile) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    const sectionSpacing = SizedBox(height: 24);
    const fieldSpacing = SizedBox(height: 16);

    return StatefulBuilder(builder: (context, setLocalState) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => GoRouter.of(context).go(AppRoutes.frontDeskProfile),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, color: AppTheme.primaryColor, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Back to Profile',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Update Profile',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Modify your professional details and availability',
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            user?.rawFullname?.isNotEmpty == true
                                ? user!.rawFullname![0].toUpperCase()
                                : 'F',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.rawFullname ?? 'Front Desk',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          if (user?.staffUniqueId != null && user!.staffUniqueId!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              user!.staffUniqueId!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            user?.role ?? 'Front Desk',
                            style: const TextStyle(
                              color: Color(0xFFC53030),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (isMobile) ...[
                    _buildProfileTextField('Full Name', _nameController, Icons.person_outline, isReadOnly: true),
                    fieldSpacing,
                    _buildProfileTextField('Email Address', _emailController, Icons.email_outlined, isReadOnly: true),
                    fieldSpacing,
                    _buildProfileTextField('Mobile Number', _mobileController, Icons.phone_android_outlined, isReadOnly: true),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildProfileTextField('Full Name', _nameController, Icons.person_outline, isReadOnly: true),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileTextField('Email Address', _emailController, Icons.email_outlined, isReadOnly: true),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileTextField('Mobile Number', _mobileController, Icons.phone_android_outlined, isReadOnly: true),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bio Summary',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bioController,
                        maxLines: 3,
                        maxLength: 255,
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.normal,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Share a brief summary of your expertise...',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                          fillColor: AppTheme.backgroundColor,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isLoading ? null : () => GoRouter.of(context).go(AppRoutes.frontDeskProfile),
                  style: AppTheme.cancelButton,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: AppTheme.primaryButton.copyWith(
                    backgroundColor: MaterialStateProperty.all(AppTheme.successColor),
                    padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                    minimumSize: MaterialStateProperty.all(const Size(130, 48)),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildProfileTextField(String label, TextEditingController controller, IconData icon, {bool isReadOnly = false, bool isNumeric = false, int? maxLength, VoidCallback? onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: isReadOnly,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          maxLength: maxLength,
          inputFormatters: isNumeric
              ? [FilteringTextInputFormatter.digitsOnly]
              : (isReadOnly ? null : [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s./,()\-]'))]),
          mouseCursor: onTap != null 
              ? SystemMouseCursors.click 
              : (isReadOnly ? SystemMouseCursors.forbidden : null),
          onTap: onTap,
          style: TextStyle(
            color: (isReadOnly && onTap == null) 
                ? AppTheme.textSecondaryColor.withOpacity(0.7) 
                : AppTheme.textPrimaryColor,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: label,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon: Icon(icon, size: 20, color: AppTheme.iconColor),
            suffixIcon: (isReadOnly && onTap == null) ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey) : null,
            fillColor: isReadOnly ? const Color(0xFFF7FAFC) : Colors.white,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
          ),
        ),
      ],
    );
  }
}
