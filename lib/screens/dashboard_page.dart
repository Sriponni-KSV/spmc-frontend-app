import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../core/routes/route_constants.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../controllers/auth_controller.dart';
import '../controllers/doctor/doctor_controller.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../widgets/nurse_widgets.dart' hide PatientModel;
import '../controllers/appointment_controller.dart';
import '../models/appointment_model.dart';
import 'new_consultation.dart';
import '../utils/date_formatter.dart';
import '../utils/logout_helper.dart';
import '../widgets/user_profile_dialog.dart';
import 'doctor_ipd_management.dart';
import 'ot_management.dart';
import 'ot_dictation_dashboard.dart';
import '../controllers/ot_controller.dart';
import '../controllers/lab_controller.dart';
import '../controllers/notification_controller.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  final int initialIndex;
  final bool isEditingProfile;
  final AppointmentModel? activeAppointment;
  const DashboardScreen({
    Key? key,
    this.initialIndex = 0,
    this.isEditingProfile = false,
    this.activeAppointment,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final AppointmentController _appointmentController = AppointmentController();
  List<AppointmentModel> _doctorAppointments = [];
  List<Map<String, dynamic>> _consultations = [];
  bool _isLoading = true;
  bool _isLoadingConsultations = false;
  DateTime? _selectedDate = DateTime.now();
  String _appointmentsSearchQuery = '';
  final TextEditingController _appointmentsSearchCtrl = TextEditingController();
  int _appointmentsCurrentPage = 0;
  final int _appointmentsItemsPerPage = 10;
  final FocusNode _mainFocusNode = FocusNode();
  AppointmentModel? _activeAppointment;
  bool _isEditingProfile = false;
  String? _selectedPatientName;
  String _selectedConsultationYearFilter = 'All';
  String _consultationSearchQuery = '';
  late TextEditingController _consultationSearchController;
  List<Map<String, dynamic>> _labReports = [];
  bool _isLoadingLabReports = false;
  String _labSearchQuery = '';
  String _labStatusFilter = 'All';
  bool _showOverduePanel = false;
  late TextEditingController _labSearchController;
  Set<int>? __expandedTestIds;
  Set<int> get _expandedTestIds => __expandedTestIds ??= {};
  final Set<String> _expandedLabGroupKeys = {};
  DoctorController get _doctorController => DoctorController();
  final OtController _otController = OtController();
  List<OtCase> _anaesthetistOtCases = [];
  OtCase? _otInitialSelectedCase;
  int? _otInitialTab;

  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  AutovalidateMode _profileAutovalidateMode = AutovalidateMode.disabled;
  String? _scheduleError;

  final FocusNode _qualFocusNode = FocusNode();
  final FocusNode _licenseFocusNode = FocusNode();
  final FocusNode _expFocusNode = FocusNode();
  final FocusNode _areasOfExpertiseFocusNode = FocusNode();
  final FocusNode _patientsFocusNode = FocusNode();
  final FocusNode _bioFocusNode = FocusNode();
  final FocusNode _clinicNameFocusNode = FocusNode();
  final FocusNode _clinicLocationFocusNode = FocusNode();
  final FocusNode _consultationFeeFocusNode = FocusNode();
  final FocusNode _slotDurationFocusNode = FocusNode();

  // Profile Controllers — Basic
  late TextEditingController _nameController;
  late TextEditingController _specController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _licenseController;
  late TextEditingController _qualController;
  late TextEditingController _expController;
  late TextEditingController _patientsController;
  late TextEditingController _bioController;
  // Professional Core
  late TextEditingController _areasOfExpertiseController;
  // Availability
  List<String>? _availableDays;
  late TextEditingController _slotStartController;
  late TextEditingController _slotEndController;
  late TextEditingController _slotDurationController;
  late TextEditingController _leaveBlockDatesController;
  List<String>? _weeklyOffDays;
  List<String>? _specificLeaveDates;
  // Clinic / Hospital
  late TextEditingController _clinicNameController;
  late TextEditingController _clinicLocationController;
  late TextEditingController _consultationFeeController;

  List<Map<String, dynamic>> _notifications = [];
  Timer? _notificationsTimer;

  Future<void> _fetchNotifications() async {
    try {
      final list = await NotificationController().fetchNotifications();
      if (mounted) {
        setState(() {
          _notifications = list;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _isEditingProfile = widget.isEditingProfile;
    _activeAppointment = widget.activeAppointment;

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final hasTimings = user?.role != 'Doctor' || (
        user?.doctorProfile?.slotStartTime != null &&
        user!.doctorProfile!.slotStartTime!.isNotEmpty &&
        user.doctorProfile?.slotEndTime != null &&
        user.doctorProfile!.slotEndTime!.isNotEmpty &&
        user.doctorProfile?.slotDuration != null &&
        user.doctorProfile!.slotDuration!.isNotEmpty &&
        user.doctorProfile?.availableDays != null &&
        user.doctorProfile!.availableDays!.isNotEmpty
    );
    if (!hasTimings && widget.initialIndex == 0) {
      _selectedIndex = 2;
      _isEditingProfile = true;
    }

    _initControllers();
    _fetchDoctorData();
    _fetchLabReports();
    _fetchNotifications();
    _notificationsTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      _fetchNotifications();
    });
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex ||
        widget.isEditingProfile != oldWidget.isEditingProfile ||
        widget.activeAppointment != oldWidget.activeAppointment) {
      setState(() {
        _selectedIndex = widget.initialIndex;
        _isEditingProfile = widget.isEditingProfile;
        _activeAppointment = widget.activeAppointment;
      });
    }
  }

  void _initControllers() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _nameController = TextEditingController(text: user?.rawFullname ?? '');
    _specController = TextEditingController(text: user?.specialization ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _mobileController = TextEditingController(text: user?.mobile ?? '');
    _licenseController = TextEditingController(
      text: user?.medicalLicense ?? '',
    );
    _qualController = TextEditingController(text: user?.qualification ?? '');
    _expController = TextEditingController(text: user?.experience ?? '');
    _patientsController = TextEditingController(
      text: user?.numberPatientsAttended?.toString() ?? '0',
    );
    _bioController = TextEditingController(text: user?.bio ?? '');

    _areasOfExpertiseController = TextEditingController(
      text: user?.areasOfExpertise ?? '',
    );

    _availableDays = user?.availableDays != null
        ? List.from(user!.availableDays!)
        : [];

    _slotStartController = TextEditingController(
      text: user?.slotStartTime ?? '',
    );
    _slotEndController = TextEditingController(text: user?.slotEndTime ?? '');
    _slotDurationController = TextEditingController(
      text: user?.slotDuration ?? '',
    );
    _leaveBlockDatesController = TextEditingController();

    _weeklyOffDays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ].where((day) => !_availableDays!.contains(day)).toList();

    _specificLeaveDates = [];
    if (user?.specificLeaveDates != null)
      _specificLeaveDates!.addAll(user!.specificLeaveDates!);

    _clinicNameController = TextEditingController(text: user?.clinicName ?? '');
    _clinicLocationController = TextEditingController(
      text: user?.clinicLocation ?? '',
    );
    _consultationFeeController = TextEditingController(
      text: user?.consultationFee ?? '',
    );
    _consultationSearchController = TextEditingController();
    _labSearchController = TextEditingController();
    _appointmentsSearchCtrl.addListener(() {
      setState(() {
        _appointmentsSearchQuery = _appointmentsSearchCtrl.text;
      });
    });
    _selectedDate = DateTime.now();
  }

  int? _parseDuration(String text) {
    final RegExp regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }
    return null;
  }

  @override
  void dispose() {
    _notificationsTimer?.cancel();
    _mainFocusNode.dispose();
    _qualFocusNode.dispose();
    _licenseFocusNode.dispose();
    _expFocusNode.dispose();
    _areasOfExpertiseFocusNode.dispose();
    _patientsFocusNode.dispose();
    _bioFocusNode.dispose();
    _clinicNameFocusNode.dispose();
    _clinicLocationFocusNode.dispose();
    _consultationFeeFocusNode.dispose();
    _slotDurationFocusNode.dispose();
    _nameController.dispose();
    _specController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _licenseController.dispose();
    _qualController.dispose();
    _expController.dispose();
    _patientsController.dispose();
    _bioController.dispose();
    _areasOfExpertiseController.dispose();
    _slotStartController.dispose();
    _slotEndController.dispose();
    _slotDurationController.dispose();
    _leaveBlockDatesController.dispose();
    _clinicNameController.dispose();
    _clinicLocationController.dispose();
    _consultationFeeController.dispose();
    _consultationSearchController.dispose();
    _labSearchController.dispose();
    _appointmentsSearchCtrl.dispose();
    super.dispose();
  }

  String _formatNotificationDate(String? dbDateStr) {
    if (dbDateStr == null || dbDateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dbDateStr).toLocal();
      return DateFormat('dd-MMM-yyyy hh:mm a').format(dt);
    } catch (_) {
      return dbDateStr;
    }
  }

  void _showNotificationsOverlay() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setOverlayState) {
             final unread = (_notifications ?? []).where((n) => n['is_read'] == false).toList();
            final read = (_notifications ?? []).where((n) => n['is_read'] == true).toList();

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
                  if (unread.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        for (final n in unread) {
                          await NotificationController().markAsRead(n['id']);
                        }
                        await _fetchNotifications();
                        setOverlayState(() {});
                        setState(() {});
                      },
                      child: const Text('Mark all as read', style: TextStyle(fontSize: 12, color: AppTheme.logoRed)),
                    )
                ],
              ),
              content: SizedBox(
                width: 450,
                height: 380,
                child: (_notifications ?? []).isEmpty
                    ? const Center(
                        child: Text(
                          'No notifications yet',
                          style: TextStyle(color: AppTheme.textSecondaryColor),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          if (unread.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('New Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.logoRed)),
                            ),
                            ...unread.map((n) => _buildNotificationTile(n, setOverlayState)),
                          ],
                          if (read.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('Earlier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondaryColor)),
                            ),
                            ...read.map((n) => _buildNotificationTile(n, setOverlayState)),
                          ],
                        ],
                      ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: AppTheme.cancelButton,
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> n, StateSetter setOverlayState) {
    final bool isUnread = n['is_read'] == false;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isUnread ? AppTheme.primaryColor.withOpacity(0.05) : Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isUnread ? AppTheme.primaryColor.withOpacity(0.2) : Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isUnread ? AppTheme.logoRed.withOpacity(0.1) : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isUnread ? Icons.notifications_active : Icons.notifications_none,
            color: isUnread ? AppTheme.logoRed : AppTheme.textSecondaryColor,
            size: 20,
          ),
        ),
        title: Text(
          n['title'] ?? 'Notification',
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
            color: AppTheme.primaryColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              n['message'] ?? '',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
            ),
            const SizedBox(height: 6),
            Text(
              _formatNotificationDate(n['created_at']),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: isUnread
            ? IconButton(
                icon: const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.primaryColor),
                onPressed: () async {
                  await NotificationController().markAsRead(n['id']);
                  await _fetchNotifications();
                  setOverlayState(() {});
                  setState(() {});
                },
              )
            : null,
        onTap: () {
          Navigator.pop(context); // Close dialog
          if (isUnread) {
            NotificationController().markAsRead(n['id']).then((_) => _fetchNotifications());
          }
          setState(() {
            _selectedIndex = 6; // Redirect to Lab Reports tab
          });
        },
      ),
    );
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
          patients: _doctorAppointments
              .map((e) => {'name': e.patientName, 'phone': '', 'age': '24'})
              .toList(),
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

  bool _isDoctorMatch(AppointmentModel appt, UserModel? user) {
    if (user == null) return false;
    if (appt.doctorDisplayId != null &&
        appt.doctorDisplayId!.isNotEmpty &&
        user.staffUniqueId != null &&
        user.staffUniqueId!.isNotEmpty) {
      return appt.doctorDisplayId == user.staffUniqueId;
    }
    String clean(String s) {
      s = s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (s.startsWith('dr.')) s = s.substring(3).trim();
      if (s.startsWith('dr ')) s = s.substring(2).trim();
      if (s.contains(' - ')) s = s.split(' - ')[0].trim();
      return s;
    }

    final cDoc = clean(appt.doctorName);
    final cUser = clean(user.rawFullname ?? user.fullname);
    if (cDoc.isEmpty || cUser.isEmpty) return false;
    return cDoc == cUser;
  }

  bool _isSameDay(String apptDateStr, DateTime date) {
    try {
      final cleanAppt = apptDateStr.replaceAll('-', '/').trim();
      final target = DateFormat('dd/MM/yyyy').format(date);
      if (cleanAppt == target || cleanAppt.startsWith(target)) return true;

      // Fallback parse
      final parts = cleanAppt.split('/');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          // yyyy/MM/dd
          final parsedDate = DateTime.tryParse(cleanAppt.replaceAll('/', '-'));
          if (parsedDate != null) {
            return parsedDate.day == date.day &&
                parsedDate.month == date.month &&
                parsedDate.year == date.year;
          }
        } else {
          // dd/MM/yyyy
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2].split(' ')[0]);
          if (day != null && month != null && year != null) {
            return day == date.day && month == date.month && year == date.year;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _fetchDoctorData() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (user.role == 'Anaesthetist') {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        final cases = await _otController.fetchOtCases();
        if (mounted) {
          setState(() {
            _anaesthetistOtCases = cases;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error fetching OT cases for Anaesthetist: $e');
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    if (!user.hasPermission('book_appointment')) {
      debugPrint('[_fetchDoctorData] Bypassing fetch: user lacks book_appointment permission');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final allAppointments = await _appointmentController.fetchAppointments();

      if (mounted) {
        setState(() {
          _doctorAppointments = allAppointments.where((appt) {
            return _isDoctorMatch(appt, user);
          }).toList();
          _isLoading = false;
        });
      }

      // Also fetch consultations
      _fetchConsultations();
    } catch (e) {
      debugPrint('Error fetching doctor data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startConsultation(AppointmentModel appointment) async {
    if (appointment.id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to start consultation for this appointment.'),
          ),
        );
      }
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Start Consultation'),
          content: Text('Do you want to start consultation for ${appointment.patientName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);
      await _appointmentController.updateStatus(
        appointment.id!,
        'In Consultation',
      );
      await _fetchDoctorData();
      if (!mounted) return;
      
      final updatedAppt = appointment.copyWith(
        status: 'In Consultation',
      );
      context.go(AppRoutes.doctorDashboardConsultation, extra: updatedAppt);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting consultation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resumeConsultation(AppointmentModel appointment) {
    if (!mounted) return;
    context.go(AppRoutes.doctorDashboardConsultation, extra: appointment);
  }

  Future<void> _fetchConsultations() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null || user.role == 'Anaesthetist' || (user.role != 'Admin' && user.role != 'Doctor')) {
      debugPrint('[_fetchConsultations] Bypassing fetch: user is null, Anaesthetist, or not Admin/Doctor');
      if (mounted) {
        setState(() => _isLoadingConsultations = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isLoadingConsultations = true);
    try {
      final consultations = await _appointmentController.fetchConsultations();
      if (mounted) {
        setState(() {
          _consultations = consultations;
          _isLoadingConsultations = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching consultations: $e');
      if (mounted) setState(() => _isLoadingConsultations = false);
    }
  }

  final List<String> _monthNames = [
    '', // 1-indexed
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  Map<String, Map<int, Map<int, List<Map<String, dynamic>>>>> _getGroupedConsultationsByPatient() {
    final Map<String, Map<int, Map<int, List<Map<String, dynamic>>>>> grouped = {};
    for (var c in _consultations) {
      final String patientName = c['patient_name'] ?? 'Unknown Patient';
      final date = _getConsultationDateTime(c);
      final year = date.year;
      final month = date.month;

      grouped.putIfAbsent(patientName, () => {});
      grouped[patientName]!.putIfAbsent(year, () => {});
      grouped[patientName]![year]!.putIfAbsent(month, () => []);
      grouped[patientName]![year]![month]!.add(c);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    final user = Provider.of<AuthProvider>(context).user;

    return Focus(
      focusNode: _mainFocusNode,
      autofocus: true,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        drawer: isMobile ? Drawer(child: _buildSidebar(isMobile)) : null,
        floatingActionButton: null,
        body: Row(
          children: [
            if (!isMobile) _buildSidebar(isMobile),
            Expanded(
              child: Column(
                children: [
                  if (_selectedIndex != 0) _buildHeader(isMobile, user?.rawFullname ?? 'Doctor'),
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
    if (_activeAppointment != null) {
      // Find existing consultation for this appointment if any
      final existingConsul = _consultations.firstWhere(
        (c) => c['appointment_id'] == _activeAppointment!.id,
        orElse: () => {},
      );

      return NewConsultationView(
        appointment: _activeAppointment!,
        initialConsultation: existingConsul.isNotEmpty ? existingConsul : null,
        onBack: () {
          setState(() => _activeAppointment = null);
          if (_selectedIndex == 0) {
            context.go(AppRoutes.doctorDashboard);
          } else {
            context.go(AppRoutes.doctorPatients);
          }
          _fetchConsultations(); // Refresh after potentially saving/updating
          _fetchDoctorData(); // Refresh appointment list status
          _fetchLabReports(); // Refresh lab reports list to show newly ordered tests instantly
        },
      );
    }

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final isAnaesthetist = user?.role == 'Anaesthetist';

    switch (_selectedIndex) {
      case 0:
        return isAnaesthetist
            ? _buildAnaesthetistDashboardView(isMobile)
            : _buildDashboardView(isMobile);
      case 1:
        return _buildConsultationsView(isMobile);
      case 2:
        return _buildProfileView(isMobile);
      case 3:
        return DoctorIPDManagementScreen(isMobile: isMobile);
      case 4:
        return OTManagementScreen(
          isMobile: isMobile,
          initialSelectedCase: _otInitialSelectedCase,
          initialTab: _otInitialTab,
        );
      case 5:
        if (isAnaesthetist) {
          return _buildAnaesthetistDashboardView(isMobile);
        }
        return OtDictationDashboardView(isMobile: isMobile);
      case 6:
        return _buildLabReportsView(isMobile);
      default:
        return isAnaesthetist
            ? _buildAnaesthetistDashboardView(isMobile)
            : _buildDashboardView(isMobile);
    }
  }

  Future<void> _fetchAndViewConsultation(AppointmentModel appt) async {
    setState(() => _isLoading = true);
    try {
      final consultations = await _appointmentController
          .fetchConsultationsByPatient(appt.patientId);
      final consul = consultations.firstWhere(
        (c) => c['appointment_id'] == appt.id,
        orElse: () => {},
      );

      if (consul.isNotEmpty) {
        if (mounted) _showConsultationDetail(consul);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Consultation details not found')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching consultation: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLabReports() async {
    if (mounted) {
      setState(() {
        _isLoadingLabReports = true;
      });
    }
    try {
      final List<Map<String, dynamic>> requests = await LabController().fetchLabRequests();
      if (mounted) {
        setState(() {
          _labReports = requests;
          _isLoadingLabReports = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading lab reports: $e');
      if (mounted) {
        setState(() {
          _isLoadingLabReports = false;
        });
      }
    }
  }

  Widget _buildConsultationsView(bool isMobile) {
    if (_isLoadingConsultations) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_consultations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history_edu_outlined,
                size: 64,
                color: Colors.grey.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'No consultations found',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            ],
          ),
        ),
      );
    }

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final grouped = _getGroupedConsultationsByPatient();
    final sortedPatients = (user == null || user.role == 'Admin')
        ? (grouped.keys.toList()..sort())
        : (grouped.keys.where((pName) {
            final patientConsuls = _consultations
                .where((c) => (c['patient_name'] ?? 'Unknown Patient') == pName)
                .toList();
            return patientConsuls.any((c) => c['doctor_name'] == user.fullname);
          }).toList()..sort());

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Consultations',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'History of all consultations performed by you.',
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
          ),
          const SizedBox(height: 24),
          if (sortedPatients.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_edu_outlined,
                      size: 64,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No consultations performed by you yet',
                      style: TextStyle(color: AppTheme.textSecondaryColor),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedPatients.length,
              itemBuilder: (context, pIndex) {
              final patientName = sortedPatients[pIndex];
              final yearsMap = grouped[patientName]!;

              int totalConsultations = 0;
              for (var year in yearsMap.keys) {
                for (var month in yearsMap[year]!.keys) {
                  totalConsultations += yearsMap[year]![month]!.length;
                }
              }

              // Selected Patient details inline
              final patientConsuls = _consultations
                  .where((c) => (c['patient_name'] ?? 'Unknown Patient') == patientName)
                  .toList();

              final Set<int> uniqueYears = {};
              for (var c in patientConsuls) {
                final dt = _getConsultationDateTime(c);
                uniqueYears.add(dt.year);
              }
              final sortedYears = uniqueYears.toList()..sort((a, b) => b.compareTo(a));

              // If this patient is expanded, calculate filtered consultations
              List<Map<String, dynamic>> filtered = [];
              if (_selectedPatientName == patientName) {
                filtered = patientConsuls.where((c) {
                  final dt = _getConsultationDateTime(c);
                  final yr = dt.year;
                  if (_selectedConsultationYearFilter != 'All' &&
                      yr.toString() != _selectedConsultationYearFilter) {
                    return false;
                  }
                  if (_consultationSearchQuery.isNotEmpty) {
                    final q = _consultationSearchQuery.toLowerCase();
                    final symptoms = (c['symptoms'] ?? '').toString().toLowerCase();
                    final history = (c['history'] ?? '').toString().toLowerCase();
                    final diagnosis = (c['diagnosis'] ?? '').toString().toLowerCase();
                    final dept = (c['department'] ?? '').toString().toLowerCase();
                    final doc = (c['doctor_name'] ?? '').toString().toLowerCase();
                    final date = _formatConsultationDateText(c).toLowerCase();
                    final time = _formatConsultationTimeText(c).toLowerCase();
                    if (!symptoms.contains(q) &&
                        !history.contains(q) &&
                        !diagnosis.contains(q) &&
                        !dept.contains(q) &&
                        !doc.contains(q) &&
                        !date.contains(q) &&
                        !time.contains(q)) {
                      return false;
                    }
                  }
                  return true;
                }).toList();
              }

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: AppTheme.borderColor.withOpacity(0.5),
                  ),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    key: Key('patient_${patientName}_${_selectedPatientName == patientName}'),
                    initiallyExpanded: _selectedPatientName == patientName,
                    onExpansionChanged: (isExpanded) {
                      setState(() {
                        if (isExpanded) {
                          _selectedPatientName = patientName;
                          _selectedConsultationYearFilter = 'All';
                          _consultationSearchQuery = '';
                          _consultationSearchController.clear();
                        } else if (_selectedPatientName == patientName) {
                          _selectedPatientName = null;
                        }
                      });
                    },
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      child: Text(
                        patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    title: Text(
                      patientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    subtitle: Text(
                      '$totalConsultations consultation${totalConsultations > 1 ? "s" : ""}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.all(16.0),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1, color: AppTheme.borderColor),
                      const SizedBox(height: 16),
                      if (isMobile)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildFilterSidebar(patientConsuls, sortedYears),
                            const SizedBox(height: 20),
                            _buildSearchAndDetailsPanel(filtered, patientConsuls),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 220,
                              child: _buildFilterSidebar(patientConsuls, sortedYears),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildSearchAndDetailsPanel(filtered, patientConsuls),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSidebar(
    List<Map<String, dynamic>> patientConsuls,
    List<int> sortedYears,
  ) {
    final allCount = patientConsuls.length;
    final Map<int, int> yearCounts = {};
    for (var yr in sortedYears) {
      yearCounts[yr] = patientConsuls.where((c) {
        final dt = _getConsultationDateTime(c);
        return dt.year == yr;
      }).length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'FILTER',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondaryColor,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildSidebarFilterItem(
          label: 'All',
          count: allCount,
          isActive: _selectedConsultationYearFilter == 'All',
          onTap: () {
            setState(() {
              _selectedConsultationYearFilter = 'All';
            });
          },
        ),
        ...sortedYears.map((yr) {
          final count = yearCounts[yr] ?? 0;
          final label = yr.toString();
          return _buildSidebarFilterItem(
            label: label,
            count: count,
            isActive: _selectedConsultationYearFilter == label,
            onTap: () {
              setState(() {
                _selectedConsultationYearFilter = label;
              });
            },
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSidebarFilterItem({
    required String label,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFFF5F5) : Colors.transparent,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        border: isActive
            ? const Border(
                left: BorderSide(
                  color: AppTheme.primaryColor,
                  width: 4,
                ),
              )
            : null,
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppTheme.primaryColor : const Color(0xFF2D3748),
            fontSize: 14,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primaryColor : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!isActive) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                size: 14,
                color: AppTheme.textSecondaryColor,
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSearchAndDetailsPanel(
    List<Map<String, dynamic>> filtered,
    List<Map<String, dynamic>> patientConsuls,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Row(
          children: [
            const SizedBox(width: 16),
            const Text(
              'Date',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 200),
            const Text(
              'Consultation Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Text(
                _consultationSearchQuery.isEmpty
                    ? 'No consultations recorded for this filter'
                    : 'No matching consultations found',
                style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final c = filtered[index];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    backgroundColor: const Color(0xFFF7FAFC),
                    collapsedBackgroundColor: const Color(0xFFF7FAFC),
                    iconColor: AppTheme.primaryColor,
                    collapsedIconColor: AppTheme.primaryColor,
                    title: Text(
                      '${_formatConsultationDateText(c)} / ${_formatConsultationTimeText(c)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                        fontSize: 13,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildConsultationDetailsGrid(c, index, patientConsuls),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildConsultationDetailsGrid(
    Map<String, dynamic> c,
    int index,
    List<Map<String, dynamic>> patientConsuls,
  ) {
    final doctor = c['doctor_name'] ?? 'General Practitioner';
    final dept = c['department'] ?? 'General Medicine';

    List medsList = [];
    if (c['medications'] != null) {
      if (c['medications'] is String) {
        try {
          medsList = jsonDecode(c['medications']);
        } catch (_) {}
      } else if (c['medications'] is List) {
        medsList = c['medications'];
      }
    }

    List labsList = [];
    if (c['lab_tests'] != null) {
      if (c['lab_tests'] is String) {
        try {
          labsList = jsonDecode(c['lab_tests']);
        } catch (_) {}
      } else if (c['lab_tests'] is List) {
        labsList = c['lab_tests'];
      }
    }

    final ref = c['referral'];
    Map? refMap;
    if (ref is Map) {
      refMap = ref;
    } else if (ref is String && ref.isNotEmpty) {
      try {
        final decoded = jsonDecode(ref);
        if (decoded is Map) refMap = decoded;
      } catch (_) {}
    }

    List? docsList;
    final docs = c['documents'];
    if (docs is List) {
      docsList = docs;
    } else if (docs is String && docs.isNotEmpty) {
      try {
        final decoded = jsonDecode(docs);
        if (decoded is List) docsList = decoded;
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGridRow(
          'Doctor',
          doctor,
          customValueWidget: Row(
            children: [
              Text(
                doctor,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '($dept)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              _buildEditPencilButton(c),
            ],
          ),
          isHeader: true,
        ),
        const SizedBox(height: 12),
        if (c['symptoms'] != null && c['symptoms'].toString().isNotEmpty) ...[
          _buildGridRow(
            'Problem',
            c['symptoms'].toString(),
          ),
          const SizedBox(height: 12),
        ],
        if (c['leading_questions'] != null && c['leading_questions'].toString().isNotEmpty) ...[
          _buildGridRow(
            'Leading Questions',
            c['leading_questions'].toString(),
          ),
          const SizedBox(height: 12),
        ],
        if (c['history'] != null && c['history'].toString().isNotEmpty) ...[
          _buildGridRow(
            'History',
            c['history'].toString(),
          ),
          const SizedBox(height: 12),
        ],
        if (c['examination'] != null && c['examination'].toString().isNotEmpty) ...[
          _buildGridRow(
            'Examination',
            c['examination'].toString(),
          ),
          const SizedBox(height: 12),
        ],
        if (c['family_history'] != null && c['family_history'].toString().isNotEmpty) ...[
          _buildGridRow(
            'Family History',
            c['family_history'].toString(),
          ),
          const SizedBox(height: 12),
        ],
        if (c['social'] != null && c['social'].toString().isNotEmpty) ...[
          _buildGridRow(
            'Social History',
            c['social'].toString(),
          ),
          const SizedBox(height: 12),
        ],
        if (c['allergy'] != null && c['allergy'].toString().isNotEmpty) ...[
          _buildGridRow(
            'Allergies',
            c['allergy'].toString(),
          ),
          const SizedBox(height: 12),
        ],
        if (c['procedure'] != null && c['procedure'].toString().isNotEmpty) ...[
          _buildGridRow(
            'Procedure',
            c['procedure'].toString(),
          ),
          const SizedBox(height: 12),
        ],
        if (c['diagnosis'] != null && c['diagnosis'].toString().isNotEmpty) ...[
          _buildGridRow(
            'Diagnosis',
            c['diagnosis'].toString(),
          ),
          const SizedBox(height: 12),
        ],
        if (c['plan'] != null && c['plan'].toString().isNotEmpty) ...[
          _buildGridRow(
            'Plan',
            c['plan'].toString(),
          ),
          const SizedBox(height: 12),
        ],
        if (medsList.isNotEmpty) ...[
          _buildGridRow(
            'Medications',
            medsList.map((m) => '${m['name']} - ${m['dosage']} (${m['frequency']})').join('\n'),
          ),
          const SizedBox(height: 12),
        ],
        if (labsList.isNotEmpty) ...[
          _buildGridRow(
            'Lab Tests',
            null,
            customValueWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labsList.join(', '),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                if (c['lab_results'] != null && (c['lab_results'] as List).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...(c['lab_results'] as List).map<Widget>((labReq) {
                    final status = labReq['status'] ?? 'Pending';
                    final testName = labReq['test_name'] ?? 'Test';
                    
                    List params = [];
                    if (labReq['result_details'] != null) {
                      if (labReq['result_details'] is String) {
                        try {
                          params = jsonDecode(labReq['result_details']);
                        } catch (_) {}
                      } else if (labReq['result_details'] is List) {
                        params = labReq['result_details'];
                      }
                    }
                    
                    final isCompleted = status == 'Completed';
                    
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                testName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isCompleted ? Colors.green.shade50 : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isCompleted ? Colors.green : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isCompleted && params.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 8),
                            const SizedBox(height: 4),
                            ...params.map<Widget>((p) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        p['parameter'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        '${p['value'] ?? ''} ${p['unit'] ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Ref: ${p['reference_range'] ?? 'Normal'}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                          if (isCompleted && labReq['remarks'] != null && labReq['remarks'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Remarks: ${labReq['remarks']}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                          if (isCompleted && labReq['attachment_url'] != null && labReq['attachment_url'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.attach_file, size: 12, color: Colors.red),
                                const SizedBox(width: 4),
                                Text(
                                  'Report: ${labReq['attachment_url']}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (refMap != null &&
            ((refMap['referred_doctor']?.toString().isNotEmpty ?? false) ||
             (refMap['referred_department']?.toString().isNotEmpty ?? false) ||
             (refMap['referral_notes']?.toString().isNotEmpty ?? false))) ...[
          _buildGridRow(
            'Referral',
            'To Doctor: ${refMap['referred_doctor'] ?? 'N/A'} • Dept: ${refMap['referred_department'] ?? 'N/A'}${refMap['referral_notes'] != null && refMap['referral_notes'].toString().isNotEmpty ? "\nNotes: " + refMap['referral_notes'] : ""}',
          ),
          const SizedBox(height: 12),
        ],
        if (docsList != null && docsList.isNotEmpty) ...[
          _buildGridRow(
            'Documents',
            docsList.map((d) {
              if (d is Map) {
                return '${d['title']} (${d['file_name']})';
              }
              return '';
            }).where((str) => str.isNotEmpty).join('\n'),
          ),
          const SizedBox(height: 12),
        ],
        if (c['comment'] != null && c['comment'].toString().isNotEmpty) ...[
          _buildGridRow(
            'Comments',
            c['comment'].toString(),
          ),
          const SizedBox(height: 12),
        ],
        if (c['notes'] != null && c['notes'].toString().isNotEmpty) ...[
          _buildGridRow(
            'Notes',
            c['notes'].toString(),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildGridRow(
    String label,
    String? value, {
    Widget? customValueWidget,
    bool isHeader = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isHeader ? const Color(0xFF2D3748) : AppTheme.primaryColor,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: customValueWidget ??
              Text(
                value ?? '',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                  color: const Color(0xFF2D3748),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildEditPencilButton(Map<String, dynamic> c) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: const Color(0xFF718096),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () {
            final appt = AppointmentModel(
              id: c['appointment_id'] is int
                  ? c['appointment_id']
                  : int.tryParse(c['appointment_id']?.toString() ?? ''),
              patientId: c['patient_id'] is int
                  ? c['patient_id']
                  : int.tryParse(c['patient_id']?.toString() ?? '') ?? 0,
              patientName: c['patient_name'] ?? _selectedPatientName ?? '',
              department: c['department'] ?? 'General',
              doctorName: c['doctor_name'] ?? '',
              appointmentDate: DateFormatter.toUi(c['appointment_date']),
              appointmentTime: c['appointment_time'] ?? '',
              patientPhone: c['patient_phone']?.toString(),
              patientGender: c['patient_gender']?.toString(),
              bloodPressureSystolic: c['blood_pressure_systolic'] is int
                  ? c['blood_pressure_systolic']
                  : int.tryParse(c['blood_pressure_systolic']?.toString() ?? ''),
              bloodPressureDiastolic: c['blood_pressure_diastolic'] is int
                  ? c['blood_pressure_diastolic']
                  : int.tryParse(c['blood_pressure_diastolic']?.toString() ?? ''),
              sugarLevel: c['sugar_level'] != null
                  ? double.tryParse(c['sugar_level'].toString())
                  : null,
              temperature: c['temperature'] != null
                  ? double.tryParse(c['temperature'].toString())
                  : null,
              reasonForVisit: c['reason_for_visit'] ?? c['symptoms'] ?? '',
              status: c['status'] ?? 'Completed',
              appointmentType: c['appointment_type'] ?? 'Routine',
            );

            context.go(AppRoutes.doctorConsultationsEdit, extra: appt);
          },
          child: const Padding(
            padding: EdgeInsets.all(6.0),
            child: Icon(
              Icons.edit,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  String _formatConsultationDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Date N/A';
    try {
      DateTime? dt;
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          dt = DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
        }
      } else {
        dt = DateTime.tryParse(dateStr);
      }
      if (dt == null) {
        final dbDate = DateFormatter.toDb(dateStr);
        dt = DateTime.tryParse(dbDate);
      }
      if (dt != null) {
        return DateFormat('dd-MMM-yyyy').format(dt);
      }
    } catch (_) {}
    return dateStr;
  }

  DateTime _getConsultationDateTime(Map<String, dynamic> c) {
    if (c['created_at'] != null && c['created_at'].toString().isNotEmpty) {
      try {
        return DateTime.parse(c['created_at'].toString()).toLocal();
      } catch (_) {}
    }
    return DateFormatter.toDateTime(c['appointment_date']) ?? DateTime.now();
  }

  String _formatConsultationDateText(Map<String, dynamic> c) {
    if (c['created_at'] != null && c['created_at'].toString().isNotEmpty) {
      try {
        final dt = DateTime.parse(c['created_at'].toString()).toLocal();
        return DateFormat('dd-MMM-yyyy').format(dt);
      } catch (_) {}
    }
    return _formatConsultationDate(c['appointment_date']);
  }

  String _formatConsultationTimeText(Map<String, dynamic> c) {
    if (c['created_at'] != null && c['created_at'].toString().isNotEmpty) {
      try {
        final dt = DateTime.parse(c['created_at'].toString()).toLocal();
        return DateFormat('hh:mm a').format(dt);
      } catch (_) {}
    }
    return c['appointment_time'] ?? '—';
  }

  void _showConsultationDetail(Map<String, dynamic> consultation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Consultation: ${consultation['patient_name']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                'Symptoms',
                consultation['symptoms'] ?? 'None recorded',
                Icons.sick_outlined,
              ),
              _buildDetailRow(
                'Leading Questions',
                consultation['leading_questions'] ?? 'None recorded',
                Icons.question_answer_outlined,
              ),
              _buildDetailRow(
                'Diagnosis',
                consultation['diagnosis'] ?? 'None recorded',
                Icons.biotech_outlined,
              ),
              _buildDetailRow(
                'Plan',
                consultation['plan'] ?? 'None recorded',
                Icons.assignment_outlined,
              ),
              _buildDetailRow(
                'Notes',
                consultation['notes'] ?? 'None recorded',
                Icons.note_alt_outlined,
              ),
              const SizedBox(height: 16),
              const Text(
                'Medications:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (consultation['medications'] != null)
                ...(consultation['medications'] as List)
                    .map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${m['name']} - ${m['dosage']} (${m['frequency']})',
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList()
              else
                const Text('No medications prescribed'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              color: const Color(0xFFF0F7FF), // Very light blue tint
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF718096), // Muted grey-blue
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748), // Darker primary text
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.role == 'Doctor') {
      final isScheduleValid = _availableDays != null && _availableDays!.isNotEmpty;
      final isFormValid = _profileFormKey.currentState?.validate() ?? false;
      
      if (!isFormValid || !isScheduleValid) {
        setState(() {
          _profileAutovalidateMode = AutovalidateMode.onUserInteraction;
          if (!isScheduleValid) {
            _scheduleError = 'Please select at least one available day';
          }
        });
        
        // Focus the first invalid field
        if (_qualController.text.trim().isEmpty) {
          _qualFocusNode.requestFocus();
        } else if (_licenseController.text.trim().isEmpty) {
          _licenseFocusNode.requestFocus();
        } else if (_expController.text.trim().isEmpty) {
          _expFocusNode.requestFocus();
        } else if (_areasOfExpertiseController.text.trim().isEmpty) {
          _areasOfExpertiseFocusNode.requestFocus();
        } else if (_patientsController.text.trim().isEmpty) {
          _patientsFocusNode.requestFocus();
        } else if (_bioController.text.trim().isEmpty) {
          _bioFocusNode.requestFocus();
        } else if (_slotDurationController.text.trim().isEmpty || 
                   _parseDuration(_slotDurationController.text) == null || 
                   _parseDuration(_slotDurationController.text)! < 15 || 
                   _parseDuration(_slotDurationController.text)! > 59) {
          _slotDurationFocusNode.requestFocus();
        } else if (_clinicNameController.text.trim().isEmpty) {
          _clinicNameFocusNode.requestFocus();
        } else if (_clinicLocationController.text.trim().isEmpty) {
          _clinicLocationFocusNode.requestFocus();
        } else if (_consultationFeeController.text.trim().isEmpty) {
          _consultationFeeFocusNode.requestFocus();
        }
        
        return;
      }
    }

    final bioText = _bioController.text.trim();
    if (bioText.isNotEmpty) {
      if (!RegExp(r'[a-zA-Z]').hasMatch(bioText)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bio / Professional Summary must contain letters and cannot consist only of special characters or numbers.'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
        return;
      }
      if (!RegExp(r'^[a-zA-Z0-9\s.,\-]+$').hasMatch(bioText)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Special characters are not allowed in Bio / Professional Summary.'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
        return;
      }
      if (bioText.length > 255) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bio / Professional Summary cannot exceed 255 characters.'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
        return;
      }
    }

    // Auto-calculate weekly off days: any day not selected as available is automatically a weekly off day
    final allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    _weeklyOffDays = allDays
        .where((day) => !(_availableDays ?? []).contains(day))
        .toList();

    setState(() => _isLoading = true);
    try {
      final updatedUser = await _doctorController.updateProfile(
        fullname: _nameController.text,
        mobile: _mobileController.text,
        medicalLicense: _licenseController.text,
        qualification: _qualController.text,
        experience: _expController.text,
        bio: _bioController.text,
        patientsAttended: _patientsController.text,
        availableDays: _availableDays ?? [],
        slotStartTime: _slotStartController.text,
        slotEndTime: _slotEndController.text,
        slotDuration: _slotDurationController.text,
        weeklyOffDays: _weeklyOffDays ?? [],
        specificLeaveDates: _specificLeaveDates ?? [],
        clinicName: _clinicNameController.text,
        clinicLocation: _clinicLocationController.text,
        consultationFee: _consultationFeeController.text,
        areasOfExpertise: _areasOfExpertiseController.text,
      );

      if (mounted) {
        Provider.of<AuthProvider>(
          context,
          listen: false,
        ).updateUser(updatedUser);
        setState(() {});
        GoRouter.of(context).go(AppRoutes.doctorProfile);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profile updated successfully!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildProfileView(bool isMobile) {
    if (_isEditingProfile) {
      return _buildProfileEditView(isMobile);
    } else {
      return _buildProfileDisplayView(isMobile);
    }
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
                      'My Profile',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Overview of your medical practice and settings',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 12,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => GoRouter.of(context).go(AppRoutes.doctorProfileEdit),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Edit Profile',
                        style: TextStyle(color: Colors.white),
                      ),
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
                          'My Profile',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Overview of your medical practice and settings',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondaryColor,
                              ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => GoRouter.of(context).go(AppRoutes.doctorProfileEdit),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Edit Profile',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: AppTheme.primaryButton.copyWith(
                        backgroundColor: MaterialStateProperty.all(AppTheme.logoRed),
                        minimumSize: MaterialStateProperty.all(const Size(0, 48)),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 32),

          // ── Primary Information Card (Name, Email, Bio) ────────────────
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
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryColor, Color(0xFF1E3A8A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          user?.rawFullname?.isNotEmpty == true
                              ? user!.rawFullname![0].toUpperCase()
                              : 'D',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.rawFullname ?? 'Doctor',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (user?.specialization != null)
                            Text(
                              user!.specialization!,
                              style: const TextStyle(
                                color: Color(0xFF718096),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            user?.role ?? 'Doctor',
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
                if (user?.bio != null && user!.bio!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 24),
                  const SizedBox(height: 20),
                  _buildDetailRow(
                    'Full Name',
                    user?.rawFullname ?? '-',
                    Icons.person_outline,
                  ),
                  _buildDetailRow(
                    'Staff ID',
                    user?.staffUniqueId ?? '-',
                    Icons.badge_outlined,
                  ),
                  _buildDetailRow(
                    'Email Address',
                    user?.email ?? '-',
                    Icons.alternate_email,
                  ),
                  _buildDetailRow(
                    'Mobile Number',
                    user?.mobile ?? '-',
                    Icons.phone_android_outlined,
                  ),
                  _buildDetailRow(
                    'Bio Summary',
                    user?.bio ?? '-',
                    Icons.description_outlined,
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 20),
                  _buildDetailRow(
                    'Full Name',
                    user?.rawFullname ?? '-',
                    Icons.person_outline,
                  ),
                  _buildDetailRow(
                    'Staff ID',
                    user?.staffUniqueId ?? '-',
                    Icons.badge_outlined,
                  ),
                  _buildDetailRow(
                    'Email Address',
                    user?.email ?? '-',
                    Icons.alternate_email,
                  ),
                  _buildDetailRow(
                    'Mobile Number',
                    user?.mobile ?? '-',
                    Icons.phone_android_outlined,
                  ),
                ],
              ],
            ),
          ),
          sectionSpacing,

          // ── Details Grid ────────────────────────────────
          if (isMobile) ...[
            _buildInfoCard('Professional Info', [
              _buildDetailRow(
                'Specialization',
                user?.specialization ?? '-',
                Icons.medical_services_outlined,
              ),
              _buildDetailRow(
                'Qualification',
                user?.qualification ?? '-',
                Icons.school_outlined,
              ),
              _buildDetailRow(
                'Medical License',
                user?.medicalLicense ?? '-',
                Icons.badge_outlined,
              ),
              _buildDetailRow(
                'Experience',
                user?.experience == null || user?.experience == '0'
                    ? '-'
                    : '${user!.experience} years',
                Icons.work_history_outlined,
              ),
            ]),
            if (user?.role != 'Anaesthetist') ...[
              sectionSpacing,
              _buildInfoCard('Availability', [
                _buildDetailRow(
                  'Available Days',
                  (user?.availableDays == null || user!.availableDays!.isEmpty)
                      ? '-'
                      : user!.availableDays!.join(', '),
                  Icons.calendar_month_outlined,
                ),
                _buildDetailRow(
                  'Consultation Hours',
                  '${user?.slotStartTime ?? "-"} to ${user?.slotEndTime ?? "-"}',
                  Icons.access_time_rounded,
                ),
                _buildDetailRow(
                  'Slot Duration',
                  user?.slotDuration ?? '-',
                  Icons.timer_outlined,
                ),
                _buildDetailRow(
                  'Weekly Off',
                  (user?.weeklyOffDays ?? []).isEmpty
                      ? '-'
                      : user!.weeklyOffDays!.join(', '),
                  Icons.event_busy_outlined,
                ),
              ]),
              sectionSpacing,
              _buildInfoCard('Clinic Details', [
                _buildDetailRow(
                  'Clinic Name',
                  user?.clinicName ?? '-',
                  Icons.business_outlined,
                ),
                _buildDetailRow(
                  'Location',
                  user?.clinicLocation ?? '-',
                  Icons.location_on_outlined,
                ),
                _buildDetailRow(
                  'Consultation Fee',
                  user?.consultationFee == null || user?.consultationFee == '0'
                      ? '-'
                      : '₹${user!.consultationFee}',
                  Icons.payments_outlined,
                ),
              ]),
            ],
          ] else ...[
            if (user?.role == 'Anaesthetist')
              _buildInfoCard('Professional Info', [
                _buildDetailRow(
                  'Specialization',
                  user?.specialization ?? '-',
                  Icons.medical_services_outlined,
                ),
                _buildDetailRow(
                  'Qualification',
                  user?.qualification ?? '-',
                  Icons.school_outlined,
                ),
                _buildDetailRow(
                  'Medical License',
                  user?.medicalLicense ?? '-',
                  Icons.badge_outlined,
                ),
                _buildDetailRow(
                  'Experience',
                  user?.experience == null || user?.experience == '0'
                      ? '-'
                      : '${user!.experience} years',
                  Icons.work_history_outlined,
                ),
              ])
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildInfoCard('Professional Info', [
                      _buildDetailRow(
                        'Specialization',
                        user?.specialization ?? '-',
                        Icons.medical_services_outlined,
                      ),
                      _buildDetailRow(
                        'Qualification',
                        user?.qualification ?? '-',
                        Icons.school_outlined,
                      ),
                      _buildDetailRow(
                        'Medical License',
                        user?.medicalLicense ?? '-',
                        Icons.badge_outlined,
                      ),
                      _buildDetailRow(
                        'Experience',
                        user?.experience == null || user?.experience == '0'
                            ? '-'
                            : '${user!.experience} years',
                        Icons.work_history_outlined,
                      ),
                    ]),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildInfoCard('Availability', [
                      _buildDetailRow(
                        'Available Days',
                        (user?.availableDays == null ||
                                user!.availableDays!.isEmpty)
                            ? '-'
                            : user!.availableDays!.join(', '),
                        Icons.calendar_month_outlined,
                      ),
                      _buildDetailRow(
                        'Consultation Hours',
                        '${user?.slotStartTime ?? "-"} to ${user?.slotEndTime ?? "-"}',
                        Icons.access_time_rounded,
                      ),
                      _buildDetailRow(
                        'Slot Duration',
                        user?.slotDuration ?? '-',
                        Icons.timer_outlined,
                      ),
                      _buildDetailRow(
                        'Weekly Off',
                        (user?.weeklyOffDays ?? []).isEmpty
                            ? '-'
                            : user!.weeklyOffDays!.join(', '),
                        Icons.event_busy_outlined,
                      ),
                      _buildDetailRow(
                        'Specific Leave Dates',
                        (user?.specificLeaveDates == null ||
                                user!.specificLeaveDates!.isEmpty)
                            ? '-'
                            : user!.specificLeaveDates!.join(', '),
                        Icons.calendar_today_outlined,
                      ),
                    ]),
                  ),
                ],
              ),
              sectionSpacing,
              _buildInfoCard('Clinic Details', [
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailRow(
                        'Clinic Name',
                        user?.clinicName ?? '-',
                        Icons.business_outlined,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailRow(
                        'Location',
                        user?.clinicLocation ?? '-',
                        Icons.location_on_outlined,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailRow(
                        'Consultation Fee',
                        user?.consultationFee == null ||
                                user?.consultationFee == '0'
                            ? '-'
                            : '₹${user!.consultationFee}',
                        Icons.payments_outlined,
                      ),
                    ),
                  ],
                ),
              ]),
            ],
          ],
          const SizedBox(height: 48),
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F5A8E),
            ),
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
    final hasTimings = user?.role != 'Doctor' || (
        user?.doctorProfile?.slotStartTime != null &&
        user!.doctorProfile!.slotStartTime!.isNotEmpty &&
        user.doctorProfile?.slotEndTime != null &&
        user.doctorProfile!.slotEndTime!.isNotEmpty &&
        user.doctorProfile?.slotDuration != null &&
        user.doctorProfile!.slotDuration!.isNotEmpty &&
        user.doctorProfile?.availableDays != null &&
        user.doctorProfile!.availableDays!.isNotEmpty
    );
    const sectionSpacing = SizedBox(height: 24);
    const fieldSpacing = SizedBox(height: 16);

    Widget sectionCard(
      String number,
      String title,
      Color accentColor,
      List<Widget> fields,
    ) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: accentColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 24),
            ...fields,
          ],
        ),
      );
    }

    final allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return StatefulBuilder(
      builder: (context, setLocalState) {
        _availableDays ??= [];
        _weeklyOffDays ??= [];
        _specificLeaveDates ??= [];
        return Form(
          key: _profileFormKey,
          autovalidateMode: _profileAutovalidateMode,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              if (hasTimings || user?.role != 'Doctor') ...[
                InkWell(
                  onTap: () => GoRouter.of(context).go(AppRoutes.doctorProfile),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back,
                          color: AppTheme.primaryColor,
                          size: 16,
                        ),
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
              ],
              if (!hasTimings && user?.role == 'Doctor') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    border: Border.all(color: const Color(0xFFFEB2B2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFC53030)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Please configure your consultation start time, end time, and slot duration. These settings are required so nurses can book appointments for you.',
                          style: TextStyle(
                            color: Color(0xFF9B2C2C),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const Text(
                'Update Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Modify your professional details and availability',
                style: const TextStyle(color: Colors.black, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // ── Basic Info Container ────────────────────────
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
                                  : 'D',
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
                              user?.rawFullname ?? 'Doctor',
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
                            if (user?.specialization?.isNotEmpty == true) ...[
                              const SizedBox(height: 2),
                              Text(
                                user!.specialization!,
                                style: const TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              (user?.role != null && user!.role.isNotEmpty)
                                  ? user.role
                                  : 'Doctor',
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
                    const SizedBox(height: 24),
                    if (isMobile) ...[
                      _buildProfileTextField(
                        'Full Name',
                        _nameController,
                        Icons.person_outline,
                        isReadOnly: true,
                        isRequired: false,
                      ),
                      fieldSpacing,
                      _buildProfileTextField(
                        'Email Address',
                        _emailController,
                        Icons.email_outlined,
                        isReadOnly: true,
                        isRequired: false,
                      ),
                      fieldSpacing,
                      _buildProfileTextField(
                        'Mobile Number',
                        _mobileController,
                        Icons.phone_android_outlined,
                        isNumeric: true,
                        maxLength: 10,
                        isReadOnly: true,
                        isRequired: false,
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Bio / Professional Summary',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                TextSpan(
                                  text: ' *',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _bioController,
                            focusNode: _bioFocusNode,
                            maxLines: 3,
                            maxLength: 255,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,\-]')),
                            ],
                            style: const TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontWeight: FontWeight.normal,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your bio / professional summary';
                              }
                              if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
                                return 'Bio must contain letters and cannot consist only of special characters or numbers';
                              }
                              if (!RegExp(r'^[a-zA-Z0-9\s.,\-]+$').hasMatch(value)) {
                                return 'Special characters are not allowed';
                              }
                              if (value.trim().length > 255) {
                                return 'Bio cannot exceed 255 characters';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              counterText: '',
                              hintText:
                                  'Share a brief summary of your expertise...',
                              hintStyle: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
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
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: _buildProfileTextField(
                              'Full Name',
                              _nameController,
                              Icons.person_outline,
                              isReadOnly: true,
                              isRequired: false,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildProfileTextField(
                              'Email Address',
                              _emailController,
                              Icons.email_outlined,
                              isReadOnly: true,
                              isRequired: false,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildProfileTextField(
                              'Mobile Number',
                              _mobileController,
                              Icons.phone_android_outlined,
                              isNumeric: true,
                              maxLength: 10,
                              isReadOnly: true,
                              isRequired: false,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Bio / Professional Summary',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              TextSpan(
                                  text: ' *',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _bioController,
                          focusNode: _bioFocusNode,
                          maxLines: 3,
                          maxLength: 255,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,\-]')),
                          ],
                          style: const TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.normal,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your bio / professional summary';
                            }
                            if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
                              return 'Bio must contain letters and cannot consist only of special characters or numbers';
                            }
                            if (!RegExp(r'^[a-zA-Z0-9\s.,\-]+$').hasMatch(value)) {
                              return 'Special characters are not allowed';
                            }
                            if (value.trim().length > 255) {
                              return 'Bio cannot exceed 255 characters';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            counterText: '',
                            hintText:
                                'Share a brief summary of your expertise...',
                            hintStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
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
              sectionSpacing,

              // ── Section 1: Professional Details ─────────────────
              sectionCard(
                '1',
                'Professional Details',
                const Color(0xFF0D5D9A),
                [
                  if (isMobile) ...[
                    _buildProfileTextField(
                      'Qualification (MBBS, MD, etc.)',
                      _qualController,
                      Icons.school_outlined,
                      maxLength: 30,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z .,()]'))],
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your qualification';
                        }
                        if (value.trim().length > 30) {
                          return 'Qualification cannot exceed 30 characters';
                        }
                        if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
                          return 'Qualification must contain valid letters';
                        }
                        return null;
                      },
                      focusNode: _qualFocusNode,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Specialization',
                      _specController,
                      Icons.medical_services_outlined,
                      isReadOnly: true,
                      isRequired: false,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Medical Registration Number',
                      _licenseController,
                      Icons.badge_outlined,
                      maxLength: 20,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9/\-]'))],
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your medical registration number';
                        }
                        return null;
                      },
                      focusNode: _licenseFocusNode,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Total Experience (years)',
                      _expController,
                      Icons.work_outline,
                      isNumeric: true,
                      maxLength: 2,
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your total experience';
                        }
                        return null;
                      },
                      focusNode: _expFocusNode,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Areas of Expertise (comma-separated)',
                      _areasOfExpertiseController,
                      Icons.star_outline,
                      maxLength: 100,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ,]'))],
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your areas of expertise';
                        }
                        return null;
                      },
                      focusNode: _areasOfExpertiseFocusNode,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Number of Patients Attended',
                      _patientsController,
                      Icons.people_outline,
                      isNumeric: true,
                      maxLength: 6,
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the number of patients attended';
                        }
                        return null;
                      },
                      focusNode: _patientsFocusNode,
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildProfileTextField(
                            'Qualification (MBBS, MD, etc.)',
                            _qualController,
                            Icons.school_outlined,
                            maxLength: 30,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z .,()]'))],
                            isRequired: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your qualification';
                              }
                              if (value.trim().length > 30) {
                                return 'Qualification cannot exceed 30 characters';
                              }
                              if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
                                return 'Qualification must contain valid letters';
                              }
                              return null;
                            },
                            focusNode: _qualFocusNode,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileTextField(
                            'Specialization',
                            _specController,
                            Icons.medical_services_outlined,
                            isReadOnly: true,
                            isRequired: false,
                          ),
                        ),
                      ],
                    ),
                    fieldSpacing,
                    Row(
                      children: [
                        Expanded(
                          child: _buildProfileTextField(
                            'Medical Registration Number',
                            _licenseController,
                            Icons.badge_outlined,
                            maxLength: 20,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9/\-]'))],
                            isRequired: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your medical registration number';
                              }
                              return null;
                            },
                            focusNode: _licenseFocusNode,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileTextField(
                            'Total Experience (years)',
                            _expController,
                            Icons.work_outline,
                            isNumeric: true,
                            maxLength: 2,
                            isRequired: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your total experience';
                              }
                              return null;
                            },
                            focusNode: _expFocusNode,
                          ),
                        ),
                      ],
                    ),
                    fieldSpacing,
                    Row(
                      children: [
                        Expanded(
                          child: _buildProfileTextField(
                            'Areas of Expertise (comma-separated)',
                            _areasOfExpertiseController,
                            Icons.star_outline,
                            maxLength: 100,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ,]'))],
                            isRequired: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your areas of expertise';
                              }
                              return null;
                            },
                            focusNode: _areasOfExpertiseFocusNode,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileTextField(
                            'Number of Patients Attended',
                            _patientsController,
                            Icons.people_outline,
                            isNumeric: true,
                            maxLength: 6,
                            isRequired: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter the number of patients attended';
                              }
                              return null;
                            },
                            focusNode: _patientsFocusNode,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              sectionSpacing,

              if (user?.role != 'Anaesthetist') ...[
                // ── Section 2: Availability ───────────────────────
                sectionCard('2', 'Availability', AppTheme.successColor, [
                  // Available / Leave Days chips
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Weekly Schedule (Tap: Available ↔ Leave)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map((day) {
                          final isAvailable =
                              _availableDays?.contains(day) ?? false;

                          Color bgColor = isAvailable
                              ? AppTheme.successColor
                              : Colors.red.shade400;
                          Color borderColor = bgColor;
                          Color textColor = Colors.white;

                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => setLocalState(() {
                                if (isAvailable) {
                                  _availableDays?.remove(day);
                                  (_weeklyOffDays ??= []).add(day);
                                } else {
                                  _weeklyOffDays?.remove(day);
                                  (_availableDays ??= []).add(day);
                                }
                                if (_availableDays!.isNotEmpty) {
                                  _scheduleError = null;
                                }
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ),
                  if (_scheduleError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _scheduleError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  fieldSpacing,
                  if (isMobile) ...[
                    _buildTimePickerField(
                      'Slot Start Time',
                      _slotStartController,
                      Icons.access_time_outlined,
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please select start time';
                        }
                        return null;
                      },
                    ),
                    fieldSpacing,
                    _buildTimePickerField(
                      'Slot End Time',
                      _slotEndController,
                      Icons.access_time_filled,
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please select end time';
                        }
                        return null;
                      },
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Slot Duration (e.g. 15 min)',
                      _slotDurationController,
                      Icons.timelapse_outlined,
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter slot duration';
                        }
                        final mins = _parseDuration(value);
                        if (mins == null) {
                          return 'Please enter a valid number (e.g. 15 mins)';
                        }
                        if (mins < 15) {
                          return 'Minimum value is 15 minutes (recommended value)';
                        }
                        if (mins > 59) {
                          return 'Maximum slot duration is 59 minutes';
                        }
                        return null;
                      },
                      focusNode: _slotDurationFocusNode,
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePickerField(
                            'Slot Start Time',
                            _slotStartController,
                            Icons.access_time_outlined,
                            isRequired: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please select start time';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTimePickerField(
                            'Slot End Time',
                            _slotEndController,
                            Icons.access_time_filled,
                            isRequired: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please select end time';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileTextField(
                            'Slot Duration (e.g. 15 min)',
                            _slotDurationController,
                            Icons.timelapse_outlined,
                            isRequired: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter slot duration';
                              }
                              final mins = _parseDuration(value);
                              if (mins == null) {
                                return 'Please enter a valid number (e.g. 15 mins)';
                              }
                              if (mins < 15) {
                                return 'Minimum value is 15 minutes (recommended value)';
                              }
                              if (mins > 59) {
                                return 'Maximum slot duration is 59 minutes';
                              }
                              return null;
                            },
                            focusNode: _slotDurationFocusNode,
                          ),
                        ),
                      ],
                    ),
                  fieldSpacing,

                  // ── Specific Leave Dates ────────────────────────
                  const Text(
                    'Specific Leave Dates — pick individual dates.',
                    style: TextStyle(fontSize: 12, color: Colors.black),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...(_specificLeaveDates ?? []).map(
                        (d) => Chip(
                          label: Text(d, style: const TextStyle(fontSize: 12)),
                          backgroundColor: Colors.orange.shade50,
                          side: BorderSide(color: Colors.orange.shade200),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () =>
                              setLocalState(() => _specificLeaveDates?.remove(d)),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 730),
                            ),
                          );
                          if (picked != null) {
                            final f =
                                '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                            if (_specificLeaveDates?.contains(f) == false) {
                              setLocalState(
                                () => (_specificLeaveDates ??= []).add(f),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                size: 15,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Add Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
                sectionSpacing,

                // ── Section 3: Clinic / Hospital Mapping ──────────
                sectionCard(
                  '3',
                  'Clinic / Hospital Details',
                  const Color(0xFF805AD5),
                  [
                    if (isMobile) ...[
                      _buildProfileTextField(
                        'Clinic / Hospital Name',
                        _clinicNameController,
                        Icons.local_hospital_outlined,
                        maxLength: 100,
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your clinic / hospital name';
                          }
                          return null;
                        },
                        focusNode: _clinicNameFocusNode,
                      ),
                      fieldSpacing,
                      _buildProfileTextField(
                        'Location',
                        _clinicLocationController,
                        Icons.location_on_outlined,
                        maxLength: 100,
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your location';
                          }
                          return null;
                        },
                        focusNode: _clinicLocationFocusNode,
                      ),
                      fieldSpacing,
                      _buildProfileTextField(
                        'Consultation Fee (₹)',
                        _consultationFeeController,
                        Icons.currency_rupee,
                        isNumeric: true,
                        maxLength: 5,
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your consultation fee';
                          }
                          final fee = int.tryParse(value);
                          if (fee == null || fee <= 0) {
                            return 'Please enter a valid fee';
                          }
                          return null;
                        },
                        focusNode: _consultationFeeFocusNode,
                      ),
                    ] else ...[
                      _buildProfileTextField(
                        'Clinic / Hospital Name',
                        _clinicNameController,
                        Icons.local_hospital_outlined,
                        maxLength: 100,
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your clinic / hospital name';
                          }
                          return null;
                        },
                        focusNode: _clinicNameFocusNode,
                      ),
                      fieldSpacing,
                      Row(
                        children: [
                          Expanded(
                            child: _buildProfileTextField(
                              'Location',
                              _clinicLocationController,
                              Icons.location_on_outlined,
                              maxLength: 100,
                              isRequired: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your location';
                                }
                                return null;
                              },
                              focusNode: _clinicLocationFocusNode,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildProfileTextField(
                              'Consultation Fee (₹)',
                              _consultationFeeController,
                              Icons.currency_rupee,
                              isNumeric: true,
                              maxLength: 5,
                              isRequired: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your consultation fee';
                                }
                                final fee = int.tryParse(value);
                                if (fee == null || fee <= 0) {
                                  return 'Please enter a valid fee';
                                }
                                return null;
                              },
                              focusNode: _consultationFeeFocusNode,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                sectionSpacing,
              ],

              sectionSpacing,

              // ── Section 6: Documents ──────────────────────────
              // sectionCard('6', 'Documents', AppTheme.primaryColor, [
              //   Container(
              //     width: double.infinity,
              //     padding: const EdgeInsets.all(20),
              //     decoration: BoxDecoration(
              //       color: AppTheme.primaryLight,
              //       borderRadius: BorderRadius.circular(10),
              //       border: Border.all(
              //         color: AppTheme.primaryColor.withOpacity(0.3),
              //         style: BorderStyle.solid,
              //       ),
              //     ),
              //     child: Column(
              //       children: [
              //         const Icon(
              //           Icons.upload_file_outlined,
              //           size: 36,
              //           color: AppTheme.primaryColor,
              //         ),
              //         const SizedBox(height: 8),
              //         const Text(
              //           'Registration Certificate',
              //           style: TextStyle(
              //             fontWeight: FontWeight.bold,
              //             fontSize: 14,
              //           ),
              //         ),
              //         const SizedBox(height: 4),
              //         const Text(
              //           'Upload your medical registration certificate for admin verification.',
              //           textAlign: TextAlign.center,
              //           style: TextStyle(
              //             color: AppTheme.textSecondaryColor,
              //             fontSize: 12,
              //           ),
              //         ),
              //         const SizedBox(height: 12),
              //         OutlinedButton.icon(
              //           onPressed: () {},
              //           icon: const Icon(Icons.attach_file, size: 18),
              //           label: const Text('Choose File'),
              //           style: OutlinedButton.styleFrom(
              //             foregroundColor: AppTheme.primaryColor,
              //             side: const BorderSide(color: AppTheme.primaryColor),
              //             shape: RoundedRectangleBorder(
              //               borderRadius: BorderRadius.circular(8),
              //             ),
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // ]),
              // sectionSpacing,

              // ── Save Button ───────────────────────────────────
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (hasTimings || user?.role != 'Doctor') ...[
                    OutlinedButton(
                      onPressed: () => GoRouter.of(context).go(AppRoutes.doctorProfile),
                      style: AppTheme.cancelButton.copyWith(
                        minimumSize: MaterialStateProperty.all(
                          const Size(120, 48),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                  ],
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.logoRed,
                      minimumSize: const Size(200, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Update Profile',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    },
  );
  }

  Widget _buildProfileTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumeric = false,
    bool isReadOnly = false,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    bool isRequired = false,
    String? Function(String?)? validator,
    FocusNode? focusNode,
  }) {
    // Determine effective formatters: caller-supplied > isNumeric default > none
    final effectiveFormatters = inputFormatters ??
        (isNumeric ? [FilteringTextInputFormatter.digitsOnly] : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          readOnly: isReadOnly,
          maxLength: maxLength,
          inputFormatters: effectiveFormatters,
          mouseCursor: isReadOnly ? SystemMouseCursors.forbidden : null,
          validator: validator,
          style: TextStyle(
            color: isReadOnly
                ? AppTheme.textSecondaryColor.withOpacity(0.7)
                : AppTheme.textPrimaryColor,
            fontWeight: isReadOnly ? FontWeight.w500 : FontWeight.normal,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: label,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon: Icon(icon, size: 20, color: AppTheme.iconColor),
            suffixIcon: isReadOnly
                ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey)
                : null,
            fillColor: isReadOnly ? const Color(0xFFF7FAFC) : Colors.white,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isRequired = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          validator: validator,
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (picked != null) {
              controller.text = picked.format(context);
            }
          },
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: AppTheme.iconColor),
            hintText: 'Tap to pick time',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              final formatted =
                  '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
              if (controller.text.isEmpty) {
                controller.text = formatted;
              } else {
                controller.text = '${controller.text}, $formatted';
              }
            }
          },
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: AppTheme.iconColor),
            hintText: 'Tap to pick date(s)',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
          ),
        ),
      ],
    );
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
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreeting(),
                const SizedBox(height: 24),
                _buildStatsRow(isMobile),
                const SizedBox(height: 24),
                _buildPatientsTable(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(bool isMobile) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final isAnaesthetist = user?.role == 'Anaesthetist';

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

          // Navigation Items (Scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  if (isAnaesthetist) ...[
                    _buildSidebarItem(0, Icons.grid_view_outlined, 'Dashboard'),
                    _buildSidebarItem(
                      4,
                      Icons.healing_outlined,
                      'OT Management',
                    ),
                    _buildSidebarItem(2, Icons.person_outline, 'My Profile'),
                  ] else ...[
                    _buildSidebarItem(0, Icons.grid_view_outlined, 'Dashboard'),
                    _buildSidebarItem(
                      1,
                      Icons.history_edu_outlined,
                      'My Consultations',
                    ),
                    _buildSidebarItem(
                      6,
                      Icons.science_outlined,
                      'Lab Reports',
                    ),
                    _buildSidebarItem(
                      3,
                      Icons.local_hospital_outlined,
                      'IPD Management',
                    ),
                    _buildSidebarItem(
                      4,
                      Icons.healing_outlined,
                      'OT Management',
                    ),
                    _buildSidebarItem(
                      5,
                      Icons.mic_none_outlined,
                      'AI Dictation',
                    ),
                    _buildSidebarItem(2, Icons.person_outline, 'My Profile'),
                  ],
                ],
              ),
            ),
          ),

          // User Profile Footer
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.borderColor, width: 1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: user == null
                ? const SizedBox.shrink()
                : Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      final user = auth.user;
                      if (user == null) return const SizedBox.shrink();
                      return Row(
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
                                      (user.rawFullname ?? user.fullname).isNotEmpty
                                          ? (user.rawFullname ?? user.fullname)[0].toUpperCase()
                                          : '?',
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
                                          user.rawFullname ?? user.fullname,
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
                            onPressed: () => LogoutHelper.showLogoutConfirmation(
                              context,
                              auth,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final hasTimings = user?.role != 'Doctor' || (
        user?.doctorProfile?.slotStartTime != null &&
        user!.doctorProfile!.slotStartTime!.isNotEmpty &&
        user.doctorProfile?.slotEndTime != null &&
        user.doctorProfile!.slotEndTime!.isNotEmpty &&
        user.doctorProfile?.slotDuration != null &&
        user.doctorProfile!.slotDuration!.isNotEmpty &&
        user.doctorProfile?.availableDays != null &&
        user.doctorProfile!.availableDays!.isNotEmpty
    );

    return InkWell(
      onTap: () {
        if (!hasTimings) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please complete the basic details and profile details.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        _isEditingProfile = false;
        if (index == 0) {
          context.go(AppRoutes.doctorDashboard);
        } else if (index == 1) {
          context.go(AppRoutes.doctorPatients);
        } else if (index == 2) {
          context.go(AppRoutes.doctorProfile);
        } else if (index == 3) {
          context.go(AppRoutes.doctorIpd);
        } else if (index == 4) {
          context.go(AppRoutes.doctorOt);
        } else if (index == 5) {
          context.go(AppRoutes.doctorDictation);
        } else if (index == 6) {
          context.go(AppRoutes.doctorLabReports);
        } else {
          context.go(AppRoutes.doctorDashboard);
        }
      },
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
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF4D5568),
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerTopBar(bool isMobile) {
    return Row(
      children: [
        if (isMobile)
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(
                Icons.menu,
                color: AppTheme.textSecondaryColor,
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),

        Expanded(
          child: InkWell(
            onTap: _showSearchOverlay,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 40,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    size: 18,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isMobile ? 'Search...' : 'Quick search...',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (!isMobile) ...[
          const SizedBox(width: 24),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(
                  (_notifications ?? []).any((n) => n['is_read'] == false)
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none_outlined,
                  color: (_notifications ?? []).any((n) => n['is_read'] == false)
                      ? AppTheme.logoRed
                      : AppTheme.textSecondaryColor,
                ),
                onPressed: _showNotificationsOverlay,
              ),
              if ((_notifications ?? []).any((n) => n['is_read'] == false))
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 10,
                      minHeight: 10,
                    ),
                  ),
                ),
            ],
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
    );
  }

  Widget _buildHeader(bool isMobile, String name) {
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

  Widget _buildGreeting() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    // Determine greeting based on time of day
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    if (hour >= 17) greeting = 'Good Evening';

    return Text(
      '$greeting, ${user?.rawFullname ?? 'Doctor'}',
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    // Calculate real stats
    final now = DateTime.now();

    final int todayCount = _doctorAppointments
        .where((a) => _isSameDay(a.appointmentDate, now))
        .length;
    final int confirmedCount = _doctorAppointments
        .where((a) => a.status == 'Confirmed' || a.status == 'Scheduled')
        .length;
    final int totalPatients = _doctorAppointments.length;

    if (isMobile) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth < 450
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: cardWidth,
                child: _buildStatCard(
                  'Total Appointments',
                  totalPatients.toString(),
                  'All time',
                  Icons.calendar_today_outlined,
                  Colors.blue,
                  isMobile,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildStatCard(
                  'Today\'s Appointments',
                  todayCount.toString(),
                  'Scheduled',
                  Icons.calendar_month_outlined,
                  Colors.indigo,
                  isMobile,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildStatCard(
                  'Confirmed Cases',
                  confirmedCount.toString(),
                  'Ready',
                  Icons.check_circle_outline,
                  Colors.green,
                  isMobile,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildStatCard(
                  'IPD Admission Cases',
                  _doctorAppointments
                      .where((a) => a.status == 'Admitted')
                      .length
                      .toString(),
                  'Pending ward assignment',
                  Icons.local_hospital_outlined,
                  Colors.red,
                  isMobile,
                ),
              ),
            ],
          );
        },
      );
    }
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Appointments',
            totalPatients.toString(),
            'All time',
            Icons.calendar_today_outlined,
            Colors.blue,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Today\'s Appointments',
            todayCount.toString(),
            'Scheduled',
            Icons.calendar_month_outlined,
            Colors.indigo,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Confirmed Cases',
            confirmedCount.toString(),
            'Ready',
            Icons.check_circle_outline,
            Colors.green,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'IPD Admission Cases',
            _doctorAppointments
                .where((a) => a.status == 'Admitted')
                .length
                .toString(),
            'Pending ward assignment',
            Icons.local_hospital_outlined,
            Colors.red,
            isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String sub,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    return StatCard(
      title: title,
      value: value,
      subLabel: sub,
      icon: icon,
      color: color,
      isMobile: isMobile,
    );
  }

  Widget _buildPatientsTable() {
    final bool isMobile = MediaQuery.of(context).size.width < 800;
    List<AppointmentModel> filteredAppts = _doctorAppointments.where((a) {
      // If a specific date is selected, show all statuses. 
      // If we are viewing all dates, only display active statuses.
      if (_selectedDate == null) {
        final status = a.status;
        if (status != 'Confirmed' && status != 'Waiting' && status != 'In Consultation') {
          return false;
        }
      }
      if (_selectedDate != null && !_isSameDay(a.appointmentDate, _selectedDate!)) {
        return false;
      }
      
      // Search logic
      if (_appointmentsSearchQuery.isNotEmpty) {
        final q = _appointmentsSearchQuery.toLowerCase();
        final matchName = a.patientName.toLowerCase().contains(q);
        final matchPhone = a.patientPhone?.toLowerCase().contains(q) ?? false;
        final matchDisplayId = a.patientDisplayId?.toLowerCase().contains(q) ?? false;
        final matchPatientId = a.patientId.toString().contains(q);
        if (!matchName && !matchPhone && !matchDisplayId && !matchPatientId) {
          return false;
        }
      }
      return true;
    }).toList();

    filteredAppts.sort((a, b) {
      if (a.appointmentTime.isEmpty && b.appointmentTime.isEmpty) return 0;
      if (a.appointmentTime.isEmpty) return 1;
      if (b.appointmentTime.isEmpty) return -1;
      try {
        final format = DateFormat('hh:mm a');
        final timeA = format.parse(a.appointmentTime);
        final timeB = format.parse(b.appointmentTime);
        return timeA.compareTo(timeB);
      } catch (e) {
        return a.appointmentTime.compareTo(b.appointmentTime);
      }
    });

    final int totalItems = filteredAppts.length;
    final int totalPages = (totalItems / _appointmentsItemsPerPage).ceil();
    if (_appointmentsCurrentPage >= totalPages && totalPages > 0) {
      _appointmentsCurrentPage = totalPages - 1;
    }
    
    final int startIndex = _appointmentsCurrentPage * _appointmentsItemsPerPage;
    final int endIndex = (startIndex + _appointmentsItemsPerPage < totalItems) 
        ? startIndex + _appointmentsItemsPerPage 
        : totalItems;
    final paginatedAppts = filteredAppts.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Card Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appointments',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (_selectedDate != null)
                      Text(
                        DateFormat('dd/MM/yyyy').format(_selectedDate!),
                        style: const TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                        ),
                      )
                    else
                      const Text(
                        'All Records',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    // Search Bar
                    Container(
                      width: 250,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 16, color: AppTheme.textSecondaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _appointmentsSearchCtrl,
                              onChanged: (val) {
                                setState(() {
                                  _appointmentsCurrentPage = 0;
                                });
                              },
                              decoration: const InputDecoration(
                                hintText: 'Search patients...',
                                hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          if (_appointmentsSearchCtrl.text.isNotEmpty)
                            InkWell(
                              onTap: () {
                                _appointmentsSearchCtrl.clear();
                                setState(() {
                                  _appointmentsSearchQuery = '';
                                  _appointmentsCurrentPage = 0;
                                });
                              },
                              child: const Icon(Icons.close, size: 14, color: AppTheme.textSecondaryColor),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Date Filter Button
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2101),
                          selectableDayPredicate: (DateTime date) {
                            final dateStr = DateFormat(
                              'dd/MM/yyyy',
                            ).format(date);
                            final isBooked = _doctorAppointments.any(
                              (a) => a.appointmentDate == dateStr,
                            );

                            // Essential: initialDate MUST satisfy the predicate or the picker won't open.
                            // We allow today's date and the currently selected date regardless of appointments.
                            final isToday =
                                date.day == DateTime.now().day &&
                                date.month == DateTime.now().month &&
                                date.year == DateTime.now().year;
                            final isCurrentSelection =
                                _selectedDate != null &&
                                date.day == _selectedDate!.day &&
                                date.month == _selectedDate!.month &&
                                date.year == _selectedDate!.year;

                            return isBooked || isToday || isCurrentSelection;
                          },
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppTheme.primaryColor,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedDate == null
                                  ? 'Filter Date'
                                  : DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(_selectedDate!),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_selectedDate != null) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () =>
                                    setState(() => _selectedDate = null),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                      onPressed: _fetchDoctorData,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = isMobile ? 850.0 : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // Table Rows Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        color: const Color(0xFFF7FAFC),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: _buildTableHeaderText('TIME')),
                            Expanded(flex: 2, child: _buildTableHeaderText('DATE')),
                            Expanded(flex: 3, child: _buildTableHeaderText('PATIENT')),
                            Expanded(flex: 2, child: _buildTableHeaderText('TYPE')),
                            Expanded(flex: 3, child: _buildTableHeaderText('REASON')),
                            Expanded(flex: 2, child: _buildTableHeaderText('STATUS')),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.center,
                                child: _buildTableHeaderText('ACTION'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (filteredAppts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(48.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.event_busy,
                                  size: 48,
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedDate == null
                                      ? 'No records found'
                                      : 'No appointments for this date',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 14,
                                  ),
                                ),
                                if (_selectedDate != null)
                                  TextButton(
                                    onPressed: () => setState(() => _selectedDate = null),
                                    child: const Text('View All Records'),
                                  ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...paginatedAppts.map((appt) {
                          return Column(
                            children: [
                              _buildPatientTableRow(appt),
                              const Divider(height: 1),
                            ],
                          );
                        }).toList(),

                      if (totalPages > 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing ${startIndex + 1} to $endIndex of $totalItems entries',
                                style: const TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 13,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: _appointmentsCurrentPage > 0
                                        ? () => setState(() => _appointmentsCurrentPage--)
                                        : null,
                                  ),
                                  Text(
                                    'Page ${_appointmentsCurrentPage + 1} of $totalPages',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: _appointmentsCurrentPage < totalPages - 1
                                        ? () => setState(() => _appointmentsCurrentPage++)
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderText(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textSecondaryColor,
        fontWeight: FontWeight.bold,
        fontSize: 11,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildPatientTableRow(AppointmentModel appt) {
    Color statusColor = AppTheme.primaryColor;
    if (appt.status == 'Confirmed') statusColor = AppTheme.successColor;
    if (appt.status == 'Waiting') statusColor = Colors.orange;
    if (appt.status == 'Completed') statusColor = Colors.red;
    if (appt.status == 'Cancelled') statusColor = Colors.red;
    if (appt.status == 'Checked In') statusColor = Colors.blue;

    final patientIdText = appt.patientDisplayId?.isNotEmpty == true
        ? appt.patientDisplayId!
        : appt.patientId.toString();
    final reasonText = appt.reasonForVisit?.isNotEmpty == true
        ? appt.reasonForVisit!
        : 'N/A';

    return InkWell(
      onTap: () async {
        if (appt.status == 'Waiting') {
          await _startConsultation(appt);
        } else if (appt.status == 'In Consultation') {
          _resumeConsultation(appt);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // Time Column
            Expanded(
              flex: 2,
              child: Text(
                appt.appointmentTime,
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                ),
              ),
            ),

            // Date Column
            Expanded(
              flex: 2,
              child: _isSameDay(appt.appointmentDate, DateTime.now()) 
                  ? const Text(
                      'Today',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : Text(
                      appt.appointmentDate,
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
            ),

            // Patient Column
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    radius: 16,
                    child: Text(
                      appt.patientName.isNotEmpty
                          ? appt.patientName[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
//                       mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          appt.patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          patientIdText,
                          style: const TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Type Column
            Expanded(
              flex: 2,
              child: Text(
                appt.appointmentType,
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                ),
              ),
            ),

            // Reason Column
            Expanded(
              flex: 3,
              child: Tooltip(
                message: reasonText,
                child: Text(
                  reasonText,
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 13,
                  ),
                  maxLines: 1,
//                   maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Status Column
            Expanded(
              flex: 2,
              child: UnconstrainedBox(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    appt.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // Action Column (always same width)
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.center,
                child: (appt.status == 'Waiting' || appt.status == 'Confirmed' || appt.status == 'Admitted' || appt.status == 'Scheduled')
                    ? ElevatedButton.icon(
                        onPressed: () => _startConsultation(appt),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(
                          Icons.medical_services_outlined,
                          size: 16,
                        ),
                        label: const Text(
                          'Take Consultation',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : appt.status == 'In Consultation'
                    ? ElevatedButton.icon(
                        onPressed: () => _resumeConsultation(appt),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.play_circle_outline, size: 16),
                        label: const Text(
                          'Resume Consultation',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : const Text(
                        '-',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnaesthetistDashboardView(bool isMobile) {
    // Calculate stats
    final totalCases = _anaesthetistOtCases.where((c) => c.status != 'OT Case Closed').length;
    final pacPending = _anaesthetistOtCases.where((c) => c.status == 'OT Scheduled' || c.status == 'Pre-Op Completed').length;
    final activeRecovery = _anaesthetistOtCases.where((c) => c.status == 'Post-Op Monitoring').length;
    final emergencyCases = _anaesthetistOtCases.where((c) => c.priority?.toLowerCase() == 'emergency' && c.status != 'OT Case Closed').length;

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
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnaesthetistGreeting(),
                const SizedBox(height: 24),
                _buildAnaesthetistStatsRow(isMobile, totalCases, pacPending, activeRecovery, emergencyCases),
                const SizedBox(height: 24),
                _buildAnaesthetistScheduleTable(isMobile),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnaesthetistGreeting() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    if (hour >= 17) greeting = 'Good Evening';

    return Text(
      '$greeting, Dr. ${user?.rawFullname ?? 'Anaesthetist'}',
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildAnaesthetistStatsRow(
    bool isMobile,
    int totalCases,
    int pacPending,
    int activeRecovery,
    int emergencyCases,
  ) {
    if (isMobile) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildStatCard('Active OT Cases', totalCases.toString(), 'Current schedule', Icons.calendar_today_outlined, Colors.blue, isMobile),
          _buildStatCard('PAC Clearance Pending', pacPending.toString(), 'Needs clearance', Icons.assignment_turned_in_outlined, Colors.orange, isMobile),
          _buildStatCard('Active Recovery (PACU)', activeRecovery.toString(), 'Monitoring', Icons.monitor_heart_outlined, Colors.green, isMobile),
          _buildStatCard('Emergency Surgeries', emergencyCases.toString(), 'High priority', Icons.emergency_outlined, Colors.red, isMobile),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: _buildStatCard('Active OT Cases', totalCases.toString(), 'Current schedule', Icons.calendar_today_outlined, Colors.blue, isMobile)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('PAC Clearance Pending', pacPending.toString(), 'Needs clearance', Icons.assignment_turned_in_outlined, Colors.orange, isMobile)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Active Recovery (PACU)', activeRecovery.toString(), 'Monitoring', Icons.monitor_heart_outlined, Colors.green, isMobile)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Emergency Surgeries', emergencyCases.toString(), 'High priority', Icons.emergency_outlined, Colors.red, isMobile)),
      ],
    );
  }

  Widget _buildAnaesthetistScheduleTable(bool isMobile) {
    // Show only open cases
    final activeCases = _anaesthetistOtCases.where((c) => c.status != 'OT Case Closed').toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Anaesthesia Case Schedule',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Today\'s scheduled cases and pre-anesthesia clearance list',
                      style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (activeCases.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Text('No active OT cases found for today.', style: TextStyle(color: AppTheme.textSecondaryColor)),
              ),
            )
          else if (isMobile)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeCases.length,
              itemBuilder: (context, index) {
                final c = activeCases[index];
                return _buildAnaesthetistCaseCard(c);
              },
            )
          else
            _buildAnaesthetistDesktopTable(activeCases),
        ],
      ),
    );
  }

  Widget _buildAnaesthetistCaseCard(OtCase c) {
    final bool needsPac = c.status == 'OT Scheduled' || c.status == 'Pre-Op Completed';
    final bool inRecovery = c.status == 'Post-Op Monitoring';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                c.patientName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              _buildPriorityBadge(c.priority ?? 'Elective'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${c.patientId} • ${c.gender} • ${c.age}y',
            style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _infoRow(Icons.healing_outlined, 'Surgery: ${c.surgeryType ?? '-'}'),
          _infoRow(Icons.meeting_room_outlined, 'OT Room: ${c.otRoom ?? '-'}'),
          _infoRow(Icons.access_time, 'Slot: ${c.surgerySlot ?? '-'}'),
          _infoRow(Icons.assignment_ind_outlined, 'Surgeon: Dr. ${c.surgeon ?? '-'}'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusBadge(c.status),
              _buildCaseActionButton(c, needsPac, inRecovery, compact: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor))),
        ],
      ),
    );
  }

  Widget _buildAnaesthetistDesktopTable(List<OtCase> cases) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 28,
        horizontalMargin: 24,
        columns: const [
          DataColumn(label: Text('Patient ID & Name', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Surgery Type', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Room / Slot', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Surgeon', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Priority', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: cases.map((c) {
          final bool needsPac = c.status == 'OT Scheduled' || c.status == 'Pre-Op Completed';
          final bool inRecovery = c.status == 'Post-Op Monitoring';
          return DataRow(
            cells: [
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(c.patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${c.patientId} • ${c.gender} • ${c.age}y', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)),
                  ],
                ),
              ),
              DataCell(Text(c.surgeryType ?? '-', style: const TextStyle(fontSize: 13))),
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(c.otRoom ?? 'Unscheduled', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if (c.surgerySlot != null)
                      Text(c.surgerySlot!, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)),
                  ],
                ),
              ),
              DataCell(Text('Dr. ${c.surgeon ?? "-"}', style: const TextStyle(fontSize: 13))),
              DataCell(_buildPriorityBadge(c.priority ?? 'Elective')),
              DataCell(_buildStatusBadge(c.status)),
              DataCell(_buildCaseActionButton(c, needsPac, inRecovery, compact: false)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    final isEmerg = priority.toLowerCase() == 'emergency';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isEmerg ? const Color(0xFFFFEBEE) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isEmerg ? const Color(0xFFFFCDD2) : const Color(0xFFBBDEFB)),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: isEmerg ? const Color(0xFFC62828) : const Color(0xFF1565C0),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color text = const Color(0xFF475569);
    Color border = const Color(0xFFE2E8F0);

    if (status == 'Pre-Op Completed') {
      bg = const Color(0xFFFFF7ED);
      text = const Color(0xFFC2410C);
      border = const Color(0xFFFFEDD5);
    } else if (status == 'Anaesthesia Cleared') {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF047857);
      border = const Color(0xFFD1FAE5);
    } else if (status == 'Post-Op Monitoring') {
      bg = const Color(0xFFF0FDF4);
      text = const Color(0xFF15803D);
      border = const Color(0xFFDCFCE7);
    } else if (status == 'Surgery In Progress') {
      bg = const Color(0xFFF0F9FF);
      text = const Color(0xFF0369A1);
      border = const Color(0xFFE0F2FE);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        status,
        style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCaseActionButton(OtCase c, bool needsPac, bool inRecovery, {required bool compact}) {
    String label = 'Open OT Step';
    IconData icon = Icons.chevron_right;
    Color color = AppTheme.primaryColor;
    int targetTab = 1; // Default to Active Cases list

    if (needsPac) {
      label = 'Anesthesia Assessment (PAC)';
      icon = Icons.assignment_turned_in_outlined;
      color = Colors.orange;
      targetTab = 1; // tab index or case details
    } else if (inRecovery) {
      label = 'Monitor PACU Recovery';
      icon = Icons.monitor_heart_outlined;
      color = Colors.green;
      targetTab = 1;
    }

    return ElevatedButton.icon(
      onPressed: () {
        setState(() {
          _otInitialSelectedCase = c;
          _otInitialTab = targetTab;
          _selectedIndex = 4; // OT Management Screen
        });
      },
      icon: Icon(icon, size: 14, color: Colors.white),
      label: Text(compact ? (needsPac ? 'PAC Assessment' : 'PACU Recovery') : label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 0,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildLabReportsView(bool isMobile) {
    if (_isLoadingLabReports) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Grouping logic
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final req in _labReports) {
      final String groupKey = req['consultation_id']?.toString() ?? 'single_${req['id']}';
      if (!groups.containsKey(groupKey)) {
        groups[groupKey] = [];
      }
      groups[groupKey]!.add(req);
    }

    final filteredGroups = <List<Map<String, dynamic>>>[];
    for (final entry in groups.entries) {
      final groupReqs = entry.value;
      
      final matchesSearch = groupReqs.any((req) {
        final patientName = (req['patient_name'] ?? '').toString().toLowerCase();
        final patientId = (req['patient_display_id'] ?? req['patient_id']?.toString() ?? '').toString().toLowerCase();
        final testName = (req['test_name'] ?? '').toString().toLowerCase();
        final query = _labSearchQuery.toLowerCase();
        return patientName.contains(query) || patientId.contains(query) || testName.contains(query);
      });

      if (!matchesSearch) continue;

      bool matchesStatus = false;
      if (_labStatusFilter == 'All') {
        matchesStatus = true;
      } else if (_labStatusFilter == 'Pending') {
        matchesStatus = groupReqs.any((req) {
          final reqStatus = req['status'] ?? 'Pending';
          return reqStatus == 'Pending' || reqStatus == 'Sample Collected';
        });
      } else {
        matchesStatus = groupReqs.any((req) {
          final reqStatus = req['status'] ?? 'Pending';
          return reqStatus == _labStatusFilter;
        });
      }

      if (!matchesStatus) continue;

      filteredGroups.add(groupReqs);
    }

    filteredGroups.sort((a, b) {
      final aDateStr = a.first['created_at']?.toString() ?? '';
      final bDateStr = b.first['created_at']?.toString() ?? '';
      if (aDateStr.isEmpty || bDateStr.isEmpty) return 0;
      return bDateStr.compareTo(aDateStr);
    });

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Lab Reports',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Track sent lab test requests and observed results received from laboratory.',
                    style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                onPressed: _fetchLabReports,
                tooltip: 'Refresh Reports',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── Lab Summary Stats Row ──────────────────────────────────────
          Builder(builder: (context) {
            final now = DateTime.now();
            
            // Group by consultation_id to find partially completed reports
            final Map<String, List<Map<String, dynamic>>> groups = {};
            for (final req in _labReports) {
              final String groupKey = req['consultation_id']?.toString() ?? 'single_${req['id']}';
              if (!groups.containsKey(groupKey)) {
                groups[groupKey] = [];
              }
              groups[groupKey]!.add(req);
            }

            final int partiallyCompleted = groups.values.where((groupReqs) {
              final totalTests = groupReqs.length;
              final completedTests = groupReqs.where((r) => r['status'] == 'Completed').length;
              return completedTests > 0 && completedTests < totalTests;
            }).length;

            final int pending = _labReports.where((r) {
              final s = r['status'] ?? '';
              return s == 'Pending' || s == 'Sample Collected';
            }).length;
            final int completed = _labReports.where((r) => r['status'] == 'Completed').length;

            // Overdue = Pending/In-progress past estimated_completion_at
            final List<Map<String, dynamic>> overdueList = _labReports.where((r) {
              final s = r['status'] ?? '';
              if (s == 'Completed') return false;
              final estStr = r['estimated_completion_at'];
              if (estStr == null) return false;
              final est = DateTime.tryParse(estStr.toString());
              if (est == null) return false;
              return now.isAfter(est.toLocal());
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Row
                Row(
                  children: [
                    _buildLabSummaryCard(
                      label: 'Overdue',
                      count: overdueList.length,
                      icon: Icons.warning_amber_outlined,
                      color: Colors.red.shade700,
                      bgColor: Colors.red.shade50,
                      highlight: overdueList.isNotEmpty,
                      onTap: overdueList.isNotEmpty
                          ? () => setState(() => _showOverduePanel = !_showOverduePanel)
                          : null,
                      isActive: _showOverduePanel,
                    ),
                    const SizedBox(width: 16),
                    _buildLabSummaryCard(
                      label: 'Pending',
                      count: pending,
                      icon: Icons.hourglass_empty_outlined,
                      color: const Color(0xFFE65100),
                      bgColor: Colors.orange.shade50,
                    ),
                    const SizedBox(width: 16),
                    _buildLabSummaryCard(
                      label: 'Partially Completed',
                      count: partiallyCompleted,
                      icon: Icons.incomplete_circle_outlined,
                      color: Colors.amber.shade800,
                      bgColor: Colors.amber.shade50,
                    ),
                    const SizedBox(width: 16),
                    _buildLabSummaryCard(
                      label: 'Completed',
                      count: completed,
                      icon: Icons.check_circle_outline,
                      color: Colors.green.shade700,
                      bgColor: Colors.green.shade50,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Overdue Alert Panel — shown only when toggled
                if (_showOverduePanel && overdueList.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time_filled, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Overdue Lab Results — ${overdueList.length} test${overdueList.length > 1 ? 's' : ''} past estimated completion',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...overdueList.map((req) {
                          final est = req['estimated_completion_at'] != null
                              ? DateTime.tryParse(req['estimated_completion_at'].toString())?.toLocal()
                              : null;
                          final overdueDuration = est != null ? now.difference(est) : null;
                          final overdueText = overdueDuration != null
                              ? (overdueDuration.inHours >= 24
                                  ? '${overdueDuration.inDays}d ${overdueDuration.inHours.remainder(24)}h overdue'
                                  : (overdueDuration.inHours > 0
                                      ? '${overdueDuration.inHours}h ${overdueDuration.inMinutes.remainder(60)}m overdue'
                                      : '${overdueDuration.inMinutes}m overdue'))
                              : 'Overdue';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade400,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${req['patient_name'] ?? 'Unknown'} (${req['patient_display_id'] ?? req['patient_id'] ?? ''})',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.science, size: 12, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(
                                            req['test_name'] ?? '',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                                          ),
                                          if (req['priority'] != null && req['priority'] != 'Normal') ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: req['priority'] == 'Emergency' ? Colors.red.shade100 : Colors.orange.shade100,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                req['priority'],
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: req['priority'] == 'Emergency' ? Colors.red.shade800 : Colors.orange.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (est != null)
                                        Text(
                                          'Was due: ${DateFormat('dd-MMM-yyyy hh:mm a').format(est)}',
                                          style: TextStyle(fontSize: 11, color: Colors.red.shade600),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    overdueText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),

                if (_showOverduePanel && overdueList.isNotEmpty) const SizedBox(height: 20),
              ],
            );
          }),

          // Search & Filter Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: TextField(
                      controller: _labSearchController,
                      onChanged: (v) => setState(() => _labSearchQuery = v),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        hintText: 'Search by Patient Name, ID, or Test...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondaryColor),
                        suffixIcon: _labSearchQuery.isNotEmpty
                            ? MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    _labSearchController.clear();
                                    setState(() => _labSearchQuery = '');
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
                const SizedBox(width: 16),
                _buildLabFilterTab('All'),
                const SizedBox(width: 8),
                _buildLabFilterTab('Pending'),
                const SizedBox(width: 8),
                _buildLabFilterTab('Sample Collected'),
                const SizedBox(width: 8),
                _buildLabFilterTab('Completed'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Reports List
          if (filteredGroups.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.science_outlined, size: 64, color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    const Text(
                      'No lab reports found matching filters',
                      style: TextStyle(color: AppTheme.textSecondaryColor),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredGroups.length,
              itemBuilder: (context, index) {
                final groupReqs = filteredGroups[index];
                return _buildLabReportGroupCard(groupReqs, isMobile);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLabSummaryCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required Color bgColor,
    bool highlight = false,
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    return Expanded(
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.15) : bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? color : (highlight ? color.withOpacity(0.6) : color.withOpacity(0.2)),
                width: isActive || highlight ? 1.5 : 1,
              ),
              boxShadow: isActive || highlight
                  ? [BoxShadow(color: color.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 3))]
                  : [],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                color: color.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (onTap != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              isActive ? Icons.expand_less : Icons.expand_more,
                              size: 14,
                              color: color.withOpacity(0.7),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabFilterTab(String label) {
    final isActive = _labStatusFilter == label;
    return InkWell(
      onTap: () => setState(() => _labStatusFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

  Widget _buildLabReportGroupCard(List<Map<String, dynamic>> groupReqs, bool isMobile) {
    final firstReq = groupReqs.first;
    final patientName = firstReq['patient_name'] ?? 'Unknown';
    final patientId = firstReq['patient_display_id'] ?? firstReq['patient_id']?.toString() ?? '--';
    final patientGender = firstReq['patient_gender'] ?? '--';
    final patientAge = firstReq['patient_age'] ?? '--';
    final doctor = firstReq['doctor_name'] ?? 'Doctor';
    final createdStr = firstReq['created_at'] != null
        ? DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(firstReq['created_at']).toLocal())
        : '--';

    final String groupKey = firstReq['consultation_id']?.toString() ?? 'single_${firstReq['id']}';
    final isExpanded = _expandedLabGroupKeys.contains(groupKey);

    final totalTests = groupReqs.length;
    final completedTests = groupReqs.where((req) => (req['status'] ?? 'Pending') == 'Completed').length;
    final hasAnySampleCollected = groupReqs.any((req) => (req['status'] ?? 'Pending') == 'Sample Collected');
    final hasAnyCompleted = completedTests > 0;

    final isAllCompleted = completedTests == totalTests;
    final isInProgress = !isAllCompleted && (hasAnyCompleted || hasAnySampleCollected);

    final displayReqs = groupReqs.where((req) {
      final reqStatus = req['status'] ?? 'Pending';
      if (_labStatusFilter == 'All') return true;
      if (_labStatusFilter == 'Pending') {
        return reqStatus == 'Pending' || reqStatus == 'Sample Collected';
      }
      return reqStatus == _labStatusFilter;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedLabGroupKeys.remove(groupKey);
                  } else {
                    _expandedLabGroupKeys.add(groupKey);
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              patientName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$patientId • $patientGender • $patientAge yrs',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ordered by Dr. $doctor • $createdStr',
                          style: const TextStyle(fontSize: 12, color: AppTheme.logoRed, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  if (!isExpanded) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'REQUESTED TESTS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondaryColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              groupReqs.map((r) => r['test_name'] ?? '').join(', '),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF4338CA),
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.start,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAllCompleted ? Colors.green.shade50 : (isInProgress ? Colors.blue.shade50 : Colors.orange.shade50),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isAllCompleted ? Colors.green.shade200 : (isInProgress ? Colors.blue.shade200 : Colors.orange.shade200),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          isAllCompleted ? 'Completed' : (isInProgress ? 'In Progress' : 'Pending'),
                          style: TextStyle(
                            color: isAllCompleted ? Colors.green : (isInProgress ? Colors.blue : Colors.orange),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppTheme.borderColor),
              const SizedBox(height: 16),
              const Text(
                'REQUESTED TESTS:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayReqs.length,
                separatorBuilder: (context, idx) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final req = displayReqs[idx];
                  return _buildGroupTestItem(req, isMobile);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTestItem(Map<String, dynamic> req, bool isMobile) {
    final int testId = req['id'] is int ? req['id'] : int.parse(req['id'].toString());
    final testName = req['test_name'] ?? 'Lab Test';
    final status = req['status'] ?? 'Pending';
    final isCompleted = status == 'Completed';
    final isSampleCollected = status == 'Sample Collected';
    final isExpanded = _expandedTestIds.contains(testId);

    final lowerTestName = testName.toString().toLowerCase();
    final isXrayOrImage = lowerTestName.contains('x-ray') ||
        lowerTestName.contains('xray') ||
        lowerTestName.contains('ultrasound') ||
        lowerTestName.contains('mri') ||
        lowerTestName.contains('scan') ||
        lowerTestName.contains('image') ||
        lowerTestName.contains('usg');

    String imageAsset = 'assets/image/chest_xray.png';
    if (lowerTestName.contains('ultrasound') || lowerTestName.contains('usg')) {
      imageAsset = 'assets/image/ultrasound.png';
    }

    Color statusColor;
    Color statusBg;
    IconData statusIcon;
    if (isCompleted) {
      statusColor = Colors.green.shade700;
      statusBg = Colors.green.shade50;
      statusIcon = Icons.check_circle_outline;
    } else if (isSampleCollected) {
      statusColor = Colors.blue.shade700;
      statusBg = Colors.blue.shade50;
      statusIcon = Icons.hourglass_top_outlined;
    } else {
      statusColor = Colors.orange.shade700;
      statusBg = Colors.orange.shade50;
      statusIcon = Icons.pending_actions_outlined;
    }

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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              color: statusColor,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: isCompleted
                        ? () {
                            setState(() {
                              if (isExpanded) {
                                _expandedTestIds.remove(testId);
                              } else {
                                _expandedTestIds.add(testId);
                              }
                            });
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: statusBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(statusIcon, color: statusColor, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  testName,
                                  style: const TextStyle(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.bold, 
                                    color: AppTheme.textPrimaryColor
                                  ),
                                ),
                                 if (req['target_tat_minutes'] != null) ...[
                                   const SizedBox(height: 2),
                                   Text(
                                     'Duration: ${_formatDuration(req['target_tat_minutes'] is int ? req['target_tat_minutes'] as int : int.tryParse(req['target_tat_minutes']?.toString() ?? '') ?? 0)}',
                                     style: const TextStyle(
                                       fontSize: 11,
                                       color: AppTheme.textSecondaryColor,
                                       fontWeight: FontWeight.w500,
                                     ),
                                   ),
                                 ],
                                 if (status != 'Completed') ...[
                                   if (req['queue_position'] != null) ...[
                                     const SizedBox(height: 2),
                                     Text(
                                       'Queue Position: #${req['queue_position']}',
                                       style: const TextStyle(
                                         fontSize: 11,
                                         color: AppTheme.primaryColor,
                                         fontWeight: FontWeight.bold,
                                       ),
                                     ),
                                   ],
                                   if (req['estimated_completion_at'] != null) ...[
                                     const SizedBox(height: 2),
                                     Text(
                                       'Est Completion: ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(req['estimated_completion_at']).toLocal())}',
                                       style: const TextStyle(
                                         fontSize: 11,
                                         color: AppTheme.secondaryColor,
                                         fontWeight: FontWeight.bold,
                                       ),
                                     ),
                                   ],
                                   if (req['scheduled_start_override'] != null) ...[
                                     const SizedBox(height: 2),
                                     Text(
                                       'Rescheduled: ${DateFormat('dd-MMM-yyyy').format(DateTime.parse(req['scheduled_start_override']).toLocal())}',
                                       style: const TextStyle(
                                         fontSize: 11,
                                         color: Colors.blue,
                                         fontWeight: FontWeight.bold,
                                       ),
                                     ),
                                   ],
                                   if (req['technician_name'] != null || req['machine_name'] != null) ...[
                                     const SizedBox(height: 2),
                                     Text(
                                       'Resources: ${req['technician_name'] ?? 'Unassigned'} • ${req['machine_name'] ?? 'Unassigned'}',
                                       style: const TextStyle(
                                         fontSize: 11,
                                         color: AppTheme.textPrimaryColor,
                                         fontWeight: FontWeight.w600,
                                       ),
                                     ),
                                   ],
                                   if (req['schedule_status'] != null && req['schedule_status'] != 'Scheduled') ...[
                                     const SizedBox(height: 2),
                                     Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                       decoration: BoxDecoration(
                                         color: req['schedule_status'] == 'Waiting for Technician' ? Colors.purple.shade50 : Colors.teal.shade50,
                                         borderRadius: BorderRadius.circular(4),
                                       ),
                                       child: Text(
                                         req['schedule_status'],
                                         style: TextStyle(
                                           fontSize: 9,
                                           color: req['schedule_status'] == 'Waiting for Technician' ? Colors.purple.shade800 : Colors.teal.shade800,
                                           fontWeight: FontWeight.bold,
                                         ),
                                       ),
                                     ),
                                   ],
                                   if (req['priority'] != null && req['priority'] != 'Normal') ...[
                                     const SizedBox(height: 2),
                                     Text(
                                       'Priority: ${req['priority']}',
                                       style: TextStyle(
                                         fontSize: 11,
                                         color: req['priority'] == 'Emergency' ? Colors.red.shade700 : Colors.orange.shade700,
                                         fontWeight: FontWeight.bold,
                                       ),
                                     ),
                                   ],
                                   if (req['delay_reason'] != null && req['delay_reason'].toString().isNotEmpty) ...[
                                     const SizedBox(height: 4),
                                     Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                       decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                                       child: Text(
                                         'Delay Issue: ${req['delay_reason']}',
                                         style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                                       ),
                                     ),
                                   ],
                                 ] else ...[
                                   if (req['actual_tat_minutes'] != null) ...[
                                     const SizedBox(height: 2),
                                     Text(
                                       'Actual TAT: ${req['actual_tat_minutes']} mins (${req['completion_status'] ?? 'On Time'})',
                                       style: const TextStyle(
                                         fontSize: 11,
                                         color: Colors.green,
                                         fontWeight: FontWeight.bold,
                                       ),
                                     ),
                                   ],
                                 ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withOpacity(0.2), width: 0.5),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          if (isCompleted) ...[
                            const SizedBox(width: 8),
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: AppTheme.textSecondaryColor,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (isCompleted && isExpanded)
                    Container(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 16, color: AppTheme.borderColor),
                          if (isXrayOrImage) ...[
                            const Text(
                              'DIAGNOSTIC IMAGING VISUALIZATION (PACS):',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              height: 280,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade900, width: 2),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.asset(
                                        imageAsset,
                                        fit: BoxFit.contain,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'PATIENT ID: ${req['patient_display_id'] ?? 'SPMC'}',
                                          style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                        ),
                                        Text(
                                          'NAME: ${req['patient_name']?.toString().toUpperCase() ?? ''}',
                                          style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'),
                                        ),
                                        Text(
                                          'SEX: ${req['patient_gender'] ?? ''}  AGE: ${req['patient_age'] ?? ''}Y',
                                          style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          testName.toString().toUpperCase(),
                                          style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                        ),
                                        const Text(
                                          'GE PACS DICOM v4.2',
                                          style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'),
                                        ),
                                        const Text(
                                          'W: 400 L: 40',
                                          style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(4)),
                                      child: const Text(
                                        'L',
                                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.zoom_in, color: Colors.white, size: 12),
                                          SizedBox(width: 4),
                                          Text(
                                            'PACS LIVE',
                                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          const Text(
                            'OBSERVED VALUES (RECEIVED):',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(height: 8),
                          if (resultsList.isEmpty)
                            const Text('No parameter details available.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12))
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
                                    Padding(padding: EdgeInsets.all(8.0), child: Text('Parameter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                    Padding(padding: EdgeInsets.all(8.0), child: Text('Observed Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                    Padding(padding: EdgeInsets.all(8.0), child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                    Padding(padding: EdgeInsets.all(8.0), child: Text('Reference Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  ],
                                ),
                                ...resultsList.map((res) {
                                  return TableRow(
                                    children: [
                                      Padding(padding: const EdgeInsets.all(8.0), child: Text(res['parameter'] ?? '', style: const TextStyle(fontSize: 12))),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0), 
                                        child: Text(
                                          res['value'] ?? '', 
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                                        )
                                      ),
                                      Padding(padding: const EdgeInsets.all(8.0), child: Text(res['unit'] ?? '', style: const TextStyle(fontSize: 12))),
                                      Padding(padding: const EdgeInsets.all(8.0), child: Text(res['reference_range'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor))),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          if (req['remarks'] != null && req['remarks'].toString().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text('REMARKS / OBSERVATIONS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                            const SizedBox(height: 4),
                            Text(req['remarks'], style: const TextStyle(fontSize: 12)),
                          ],
                          if (req['attachment_url'] != null && req['attachment_url'].toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.picture_as_pdf, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Report Document: ${req['attachment_url']}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ],
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
}
