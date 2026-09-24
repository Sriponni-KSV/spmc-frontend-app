import 'package:flutter/material.dart';
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
import 'nurse_profile_view.dart';
import 'opd_management.dart';
import 'ipd_management.dart';
import 'ot_management.dart';
import 'home_visit_list_view.dart';
import 'home_visit_execution_screen.dart';
import '../widgets/access_denied_widget.dart';
import '../controllers/appointment_controller.dart';
import '../models/appointment_model.dart';
import '../utils/logout_helper.dart';
import '../models/user_model.dart';
import '../controllers/nurse_shift_controller.dart';
import '../widgets/user_profile_dialog.dart';
import '../utils/modal_history_helper.dart';
import '../config/nurse_nav_config.dart';
import '../utils/app_localizations.dart';
import '../widgets/app_top_bar_actions.dart';

class NurseDashboardScreen extends StatefulWidget {
  final int initialIndex;
  final bool isRegisteringPatient;
  final bool forceBooking;
  final PatientModel? existingPatient;
  final PatientModel? viewPatient;
  final bool isEditingProfile;
  final int? selectedHomeVisitId;
  final bool isReadOnlyHomeVisit;
  const NurseDashboardScreen({
    Key? key,
    this.initialIndex = 0,
    this.isRegisteringPatient = false,
    this.forceBooking = false,
    this.existingPatient,
    this.viewPatient,
    this.isEditingProfile = false,
    this.selectedHomeVisitId,
    this.isReadOnlyHomeVisit = false,
  }) : super(key: key);

  @override
  State<NurseDashboardScreen> createState() => _NurseDashboardScreenState();
}

class _NurseDashboardScreenState extends State<NurseDashboardScreen> {
  int _selectedIndex = 0;
  int? _selectedHomeVisitId;
  bool _isReadOnlyHomeVisit = false;
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

  final NurseShiftController _shiftCtrl = NurseShiftController();
  Map<String, dynamic>? _activeShiftData;
  Map<String, dynamic>? _todayShiftData;

  String _activeAdmissionsCount = '--';
  String _patientVisitsCount = '--';
  bool _isLoadingDashboardStats = false;
  List<Map<String, dynamic>> _allWardsShiftData = [];
  bool _isLoadingShiftStatus = false;
  List<Map<String, dynamic>> _handovers = [];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _selectedHomeVisitId = widget.selectedHomeVisitId;
    _isReadOnlyHomeVisit = widget.isReadOnlyHomeVisit;
    _isRegisteringPatient = widget.isRegisteringPatient;
    _patientToComplete = widget.existingPatient;
    _viewPatient = widget.viewPatient;
    _forceBookingForm = widget.forceBooking;
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant NurseDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex ||
        widget.isRegisteringPatient != oldWidget.isRegisteringPatient ||
        widget.forceBooking != oldWidget.forceBooking ||
        widget.existingPatient != oldWidget.existingPatient ||
        widget.viewPatient != oldWidget.viewPatient ||
        widget.selectedHomeVisitId != oldWidget.selectedHomeVisitId ||
        widget.isReadOnlyHomeVisit != oldWidget.isReadOnlyHomeVisit) {
      setState(() {
        _selectedIndex = widget.initialIndex;
        _selectedHomeVisitId = widget.selectedHomeVisitId;
        _isReadOnlyHomeVisit = widget.isReadOnlyHomeVisit;
        _isRegisteringPatient = widget.isRegisteringPatient;
        _patientToComplete = widget.existingPatient;
        _viewPatient = widget.viewPatient;
        _forceBookingForm = widget.forceBooking;
      });
    }
  }

  Future<void> _fetchDashboardStats() async {
    if (!mounted) return;
    setState(() => _isLoadingDashboardStats = true);
    try {
      final stats = await _shiftCtrl.fetchNurseStats();
      if (mounted) {
        setState(() {
          _activeAdmissionsCount =
              stats['activeAdmissions']?.toString() ?? '--';
          _patientVisitsCount = stats['patientVisits']?.toString() ?? '--';
        });
      }
    } catch (e) {
      debugPrint('Error fetching nurse stats: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingDashboardStats = false);
      }
    }
  }

  Future<void> _fetchData() async {
    await Future.wait([
      _fetchPatients(),
      _fetchAppointments(),
      _fetchShiftStatus(),
      _fetchHandovers(),
      _fetchDashboardStats(),
    ]);
  }

  Future<void> _fetchShiftStatus() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    if (mounted) setState(() => _isLoadingShiftStatus = true);
    try {
      final res = await _shiftCtrl.fetchActiveShift(nurseId: user.id);
      if (res['success'] == true) {
        final todayShift = res['today_shift'];
        if (res['active'] == true) {
          final List data = res['data'] ?? [];
          final list = List<Map<String, dynamic>>.from(data);

          // Find if this nurse is assigned to any ward
          Map<String, dynamic>? myAlloc;
          for (final w in list) {
            if (w['assigned_nurse_id']?.toString() == user.id.toString()) {
              myAlloc = w;
              break;
            }
          }

          if (mounted) {
            setState(() {
              _allWardsShiftData = list;
              _activeShiftData = myAlloc;
              _todayShiftData = todayShift;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _allWardsShiftData = [];
              _activeShiftData = null;
              _todayShiftData = todayShift;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _allWardsShiftData = [];
            _activeShiftData = null;
            _todayShiftData = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching active shift status: $e');
    } finally {
      if (mounted) setState(() => _isLoadingShiftStatus = false);
    }
  }

  Future<void> _fetchHandovers() async {
    try {
      final list = await _shiftCtrl.fetchHandovers();
      if (mounted) {
        setState(() {
          _handovers = list;
        });
      }
    } catch (e) {
      debugPrint('Error fetching handovers: $e');
    }
  }

  Future<void> _acknowledgeHandover(int handoverId) async {
    try {
      await _shiftCtrl.acknowledgeHandover(handoverId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Handover acknowledged successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error acknowledging handover: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Future<bool> _confirmLeaveActiveVisit() async {
    if (_selectedHomeVisitId == null || _isReadOnlyHomeVisit) {
      return true;
    }
    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isMobile = MediaQuery.of(ctx).size.width < 500;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppTheme.getCardColor(ctx),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32,
            vertical: 24,
          ),
          child: Container(
            width: isMobile ? double.infinity : 440,
            constraints: const BoxConstraints(maxWidth: 440),
            padding: EdgeInsets.all(isMobile ? 18 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.dangerColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('unsaved_clinical_data', fallback: 'Unsaved Clinical Session Data'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.getTextPrimaryColor(ctx),
                          fontFamily: 'Inter',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr('active_home_visit_body', fallback: 'An active Home Visit Care session is currently in progress. If you navigate away now, any unsaved inputs or form entries will be lost.\n\nDo you want to leave this clinical visit?'),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.getTextSecondaryColor(ctx),
                    height: 1.4,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 24),
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        style: AppTheme.dangerButton,
                        onPressed: () {
                          ModalHistoryHelper.skipNextHistoryBack();
                          Navigator.of(ctx).pop(true);
                        },
                        child: Text(context.tr('leave_page', fallback: 'Leave Page')),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        style: AppTheme.cancelButton,
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(context.tr('stay_on_page', fallback: 'Stay on Page')),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: AppTheme.cancelButton,
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(context.tr('stay_on_page', fallback: 'Stay on Page')),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: AppTheme.dangerButton,
                        onPressed: () {
                          ModalHistoryHelper.skipNextHistoryBack();
                          Navigator.of(ctx).pop(true);
                        },
                        child: Text(context.tr('leave_page', fallback: 'Leave Page')),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
    return shouldLeave == true;
  }

  Future<bool> _confirmLeaveRegistration() async {
    if (!_isRegisteringPatient) {
      return true;
    }
    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isMobile = MediaQuery.of(ctx).size.width < 500;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppTheme.getCardColor(ctx),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32,
            vertical: 24,
          ),
          child: Container(
            width: isMobile ? double.infinity : 440,
            constraints: const BoxConstraints(maxWidth: 440),
            padding: EdgeInsets.all(isMobile ? 18 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.dangerColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('unsaved_patient_reg', fallback: 'Unsaved Patient Registration'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.getTextPrimaryColor(ctx),
                          fontFamily: 'Inter',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr('leave_registration_body', fallback: 'You are currently filling the patient registration form. If you navigate away now, any unsaved inputs will be lost.\n\nDo you want to leave this page?'),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.getTextSecondaryColor(ctx),
                    height: 1.4,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 24),
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        style: AppTheme.dangerButton,
                        onPressed: () {
                          ModalHistoryHelper.skipNextHistoryBack();
                          Navigator.of(ctx).pop(true);
                        },
                        child: Text(context.tr('leave_page', fallback: 'Leave Page')),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        style: AppTheme.cancelButton,
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(context.tr('stay_on_page', fallback: 'Stay on Page')),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: AppTheme.cancelButton,
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(context.tr('stay_on_page', fallback: 'Stay on Page')),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: AppTheme.dangerButton,
                        onPressed: () {
                          ModalHistoryHelper.skipNextHistoryBack();
                          Navigator.of(ctx).pop(true);
                        },
                        child: Text(context.tr('leave_page', fallback: 'Leave Page')),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
    return shouldLeave == true;
  }

  void _changePage(
    int index, {
    bool isRegistering = false,
    bool forceBooking = false,
    PatientModel? prefilledPatient,
  }) async {
    if (!mounted) return;
    if (_selectedHomeVisitId != null && !_isReadOnlyHomeVisit) {
      final shouldLeave = await _confirmLeaveActiveVisit();
      if (!shouldLeave || !mounted) return;
    }
    if (_isRegisteringPatient) {
      if (index == 1 && isRegistering) {
        return;
      }
      final shouldLeave = await _confirmLeaveRegistration();
      if (!shouldLeave || !mounted) return;
      setState(() => _isRegisteringPatient = false);
    }
    setState(() {
      _selectedHomeVisitId = null;
      _isReadOnlyHomeVisit = false;
      _selectedIndex = index;
      if (index != 2) {
        _forceBookingForm = false;
        _selectedPatientForBooking = null;
        _selectedDoctorForBooking = null;
      } else if (forceBooking) {
        _forceBookingForm = true;
      }
    });
    switch (index) {
      case 0:
        context.go(AppRoutes.nurseDashboard);
        break;
      case 1:
        if (isRegistering) {
          context.go(
            AppRoutes.nurseNewPatient,
            extra: prefilledPatient ?? _patientToComplete,
          );
        } else {
          context.go(AppRoutes.nursePatients);
        }
        break;
      case 2:
        if (forceBooking) {
          context.go(AppRoutes.nurseBookAppointment);
        } else {
          context.go(AppRoutes.nurseAppointments);
        }
        break;
      case 3:
        context.go(AppRoutes.nurseDoctors);
        break;
      case 4:
        context.go(AppRoutes.nurseProfile);
        break;
      case 5:
        context.go(AppRoutes.nurseOpd);
        break;
      case 6:
        context.go(AppRoutes.nurseIpd);
        break;
      case 7:
        context.go(AppRoutes.nurseOt);
        break;
      case 8:
        context.go(AppRoutes.nurseDocAppointments);
        break;
      case 9:
        context.go(AppRoutes.nurseHomeVisits);
        break;
      default:
        context.go(AppRoutes.nurseDashboard);
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
          onBookAppointment: NurseNavConfig.showAppointments
              ? (patientMap) {
                  if (patientMap != null) {
                    setState(
                      () => _selectedPatientForBooking = PatientModel.fromJson(
                        patientMap,
                      ),
                    );
                  }
                  _changePage(2, forceBooking: true);
                }
              : null,
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

  bool _isFormActive() {
    if (_isRegisteringPatient ||
        widget.isRegisteringPatient ||
        widget.isEditingProfile ||
        _patientToComplete != null ||
        _selectedHomeVisitId != null ||
        _forceBookingForm ||
        widget.forceBooking) {
      return true;
    }
    try {
      final loc = GoRouterState.of(context).matchedLocation;
      if (loc.contains('new-patient') ||
          loc.contains('edit-patient') ||
          loc.contains('book-appointment') ||
          loc.contains('home-visits/execute')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    final bool isFormActive = _isFormActive();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.getBackgroundColor(context),
      drawer: isMobile ? Drawer(child: _buildSidebar(context)) : null,
      floatingActionButton: null,
      body: Stack(
        children: [
          Row(
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
          if (!isFormActive)
            CustomSpeedDial(
              isVisible: !isFormActive,
              children: [
                if (Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).user?.hasPermission('add_patient') ??
                    false)
                  SpeedDialChild(
                    label: context.tr('new_patient', fallback: 'New Patient'),
                    icon: Icons.person_add_alt_1_outlined,
                    color: AppTheme.dangerColor,
                    onTap: () => _changePage(1, isRegistering: true),
                  ),
                if (NurseNavConfig.showAppointments &&
                    (Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).user?.hasPermission('book_appointment') ??
                        false))
                  SpeedDialChild(
                    label: context.tr('book_appointment', fallback: 'Book Appointment'),
                    icon: Icons.calendar_month_outlined,
                    color: const Color(0xFF0D5D9A),
                    onTap: () => _changePage(2, forceBooking: true),
                  ),
              ],
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
          key: ValueKey('nurse_reg_${_patientToComplete?.id ?? 'new'}'),
          existingPatient: _patientToComplete,
          onBack: () {
            final patientToReturn = _patientToComplete;
            setState(() {
              _isRegisteringPatient = false;
              _patientToComplete = null;
              if (patientToReturn != null && patientToReturn.id != null) {
                _viewPatient = patientToReturn;
              }
            });
            if (patientToReturn != null && patientToReturn.id != null) {
              context.go(AppRoutes.nurseViewPatient, extra: patientToReturn);
            } else {
              context.go(AppRoutes.nursePatients);
            }
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
            onRegisterPatient: ([prefilledPatient]) {
              setState(() {
                _patientToComplete = prefilledPatient;
              });
              _changePage(1, isRegistering: true, prefilledPatient: prefilledPatient);
            },
            onCompleteProfile: (patient) {
              context.go(AppRoutes.nurseEditPatient, extra: patient);
            },
            onBookAppointment: (patient) {
              if (NurseNavConfig.showAppointments) {
                setState(() => _selectedPatientForBooking = patient);
                _changePage(2, forceBooking: true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr(
                        'appointment_booking_disabled',
                        fallback: 'Appointment section is currently disabled.',
                      ),
                    ),
                  ),
                );
              }
            },
            onRefresh: _fetchPatients,
          );
        }
        return const AccessDeniedWidget();
      case 2:
        if (user?.hasPermission('book_appointment') ?? false) {
          return AppointmentsView(
            key: const ValueKey('nurse_appointments_tab_view'),
            startWithBookingForm: _forceBookingForm || widget.forceBooking,
            initialPatient: _selectedPatientForBooking,
            initialDoctor: _selectedDoctorForBooking,
          );
        }
        return const AccessDeniedWidget();
      case 3:
        return DoctorsView(
          onBookAppointment: NurseNavConfig.showAppointments
              ? (doctor) {
                  setState(() => _selectedDoctorForBooking = doctor);
                  _changePage(2, forceBooking: true);
                }
              : null,
        );
      case 4:
        return NurseProfileView(isEditing: widget.isEditingProfile);
      case 5:
        return OPDManagementScreen(isMobile: isMobile, title: 'OPD Assistance');
      case 6:
        return IPDManagementScreen(isMobile: isMobile);
      case 7:
        return OTManagementScreen(isMobile: isMobile);
      case 8:
        return const AppointmentsView(initialViewMode: 'Doctor');
      case 9:
        if (_selectedHomeVisitId != null) {
          return HomeVisitExecutionScreen(
            visitId: _selectedHomeVisitId!,
            isReadOnlyView: _isReadOnlyHomeVisit,
            onBack: () {
              setState(() {
                _selectedHomeVisitId = null;
                _isReadOnlyHomeVisit = false;
              });
              context.go(AppRoutes.nurseHomeVisits);
            },
          );
        }
        return HomeVisitListView(
          showScheduleButton: false,
          onExecuteVisit: (visitId) {
            setState(() {
              _selectedHomeVisitId = visitId;
              _isReadOnlyHomeVisit = false;
            });
            context.go('/nurse/home-visits/execute/$visitId');
          },
          onViewSummary: (visitId) {
            setState(() {
              _selectedHomeVisitId = visitId;
              _isReadOnlyHomeVisit = true;
            });
            context.go('/nurse/home-visits/summary/$visitId');
          },
        );
      default:
        return _buildDashboardView(isMobile);
    }
  }

  Widget _buildDashboardView(bool isMobile) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed Top Bar
        Container(
          padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 20, isMobile ? 16 : 24, 10),
          color: Colors.transparent,
          child: _buildBannerTopBar(isMobile),
        ),
        // Scrollable Content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16.0 : 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user != null
                      ? '${context.tr('hello', fallback: 'Hello')}, ${user.fullname}! 👋'
                      : context.tr('dashboard', fallback: 'Dashboard'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('welcome_hospital_overview', fallback: "Welcome back! Here's your hospital overview"),
                  style: TextStyle(
                    color: AppTheme.getTextSecondaryColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                _buildStatsRow(isMobile),
                const SizedBox(height: 24),
                _buildShiftStatusPanel(isMobile),
                const SizedBox(height: 20),
                ..._buildPendingHandoverCards(isMobile),
                const SizedBox(height: 4),
                if (isMobile) ...[
                  _buildAlertsSection(),
                  const SizedBox(height: 20),
                  _buildRecentPatients(),
                  if (NurseNavConfig.showAppointments) ...[
                    const SizedBox(height: 20),
                    _buildUpcomingAppointments(),
                  ],
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: NurseNavConfig.showAppointments ? 5 : 1,
                        child: _buildAlertsSection(),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: NurseNavConfig.showAppointments ? 5 : 1,
                        child: _buildRecentPatients(),
                      ),
                      if (NurseNavConfig.showAppointments) ...[
                        const SizedBox(width: 20),
                        Expanded(flex: 4, child: _buildUpcomingAppointments()),
                      ],
                    ],
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        return Container(
          width: 275,
          margin: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.getBorderColor(context)),
            boxShadow: isDark
                ? []
                : [
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Image.asset(
                  'assets/image/full_logo.png',
                  width: 110,
                  height: 90,
                ),
              ),

              // Navigation Items (Scrollable Area driven by NurseNavConfig)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: NurseNavConfig.getVisibleNavItems(user)
                        .map(
                          (item) {
                            String translatedLabel = item.label;
                            final lower = item.label.toLowerCase();
                            if (lower == 'dashboard') translatedLabel = context.tr('dashboard', fallback: item.label);
                            else if (lower == 'patients') translatedLabel = context.tr('patients', fallback: item.label);
                            else if (lower == 'appointments') translatedLabel = context.tr('appointments', fallback: item.label);
                            else if (lower == 'doctors') translatedLabel = context.tr('doctors', fallback: item.label);
                            else if (lower.contains('opd')) translatedLabel = context.tr('opd_management', fallback: item.label);
                            else if (lower.contains('ipd')) translatedLabel = context.tr('ipd_management', fallback: item.label);
                            else if (lower.contains('ot')) translatedLabel = context.tr('ot_management', fallback: item.label);
                            else if (lower.contains('home visit')) translatedLabel = context.tr('home_visit_care', fallback: item.label);
                            else if (lower == 'profile') translatedLabel = context.tr('profile', fallback: item.label);

                            return _buildSidebarItem(
                              item.index,
                              item.icon,
                              translatedLabel,
                            );
                          },
                        )
                        .toList(),
                  ),
                ),
              ),

              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppTheme.getBorderColor(context), width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: user == null
                    ? const SizedBox.shrink()
                    : Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  UserProfileDialog.show(context, user),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor,
                                    radius: 18,
                                    child: Text(
                                      user.fullname.isNotEmpty
                                          ? user.fullname[0].toUpperCase()
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.fullname,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: AppTheme.getTextPrimaryColor(context),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          context.translateRole(user.role),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.getTextSecondaryColor(context),
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
                            icon: Icon(
                              Icons.logout,
                              size: 18,
                              color: AppTheme.getTextSecondaryColor(context),
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
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 200),
      preferBelow: false,
      verticalOffset: 20,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      ),
      child: InkWell(
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
                color: isSelected ? Colors.white : AppTheme.getTextSecondaryColor(context),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.getTextPrimaryColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
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
    final isDark = AppTheme.isDark(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isMobile) ...[
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu, color: AppTheme.getTextPrimaryColor(context)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const SizedBox(width: 4),
        ],

        // Search Bar
        Expanded(
          child: InkWell(
            onTap: _showSearchOverlay,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.getBorderColor(context), width: 1.2),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: AppTheme.getTextSecondaryColor(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('search_anything', fallback: 'Search anything...'),
                      style: TextStyle(fontSize: 14, color: AppTheme.getTextSecondaryColor(context)),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.notifications_none_outlined, color: AppTheme.getTextPrimaryColor(context), size: 22),
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Color(0xFFE53E3E), shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                child: const Text(
                  '3',
                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(width: 16),
        AppTopBarActions(
          showClock: !isMobile,
          liveClockWidget: const LiveClock(isDark: false),
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    final bool isDark = AppTheme.isDark(context);
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

    final List<Widget> statItems = [
      _buildStatItem(
        'Total Patients',
        totalPatients.toString(),
        Icons.people_outline,
        const Color(0xFF0C5D9A),
      ),
      if (NurseNavConfig.showAppointments)
        _buildStatItem(
          'Today\'s Appointments',
          todaysApptsCount.toString(),
          Icons.calendar_today_outlined,
          AppTheme.secondaryColor,
        ),
      if (NurseNavConfig.showIpdManagement)
        _buildStatItem(
          'Active Admissions',
          _activeAdmissionsCount,
          Icons.bedroom_child_outlined,
          const Color(0xFFDD3B3B),
        ),
      if (NurseNavConfig.showOpdAssistance)
        _buildStatItem(
          'Patient Visits',
          _patientVisitsCount,
          Icons.monitor_heart_outlined,
          const Color(0xFF7C5CBF),
        ),
      if (!NurseNavConfig.showAppointments &&
          !NurseNavConfig.showIpdManagement &&
          !NurseNavConfig.showOpdAssistance)
        _buildStatItem(
          'Pending Handovers',
          _handovers.length.toString(),
          Icons.assignment_turned_in_outlined,
          AppTheme.secondaryColor,
        ),
    ];

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
          border: Border.all(color: AppTheme.getBorderColor(context)),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: statItems,
        ),
      );
    }

    final List<Widget> rowChildren = [];
    for (int i = 0; i < statItems.length; i++) {
      if (i > 0) {
        rowChildren.add(_buildVerticalDivider());
      }
      rowChildren.add(Expanded(child: statItems[i]));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: rowChildren,
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 20),
      color: AppTheme.getBorderColor(context),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    String translatedTitle = title;
    if (title == 'Total Patients') {
      translatedTitle = context.tr('total_patients', fallback: title);
    } else if (title == 'Today\'s Appointments') {
      translatedTitle = context.tr('today_appointments', fallback: title);
    } else if (title == 'Active Admissions') {
      translatedTitle = context.tr('active_admissions', fallback: title);
    } else if (title == 'Patient Visits') {
      translatedTitle = context.tr('patient_visits', fallback: title);
    } else if (title == 'Pending Handovers') {
      translatedTitle = context.tr('pending_handovers', fallback: title);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimaryColor(context),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  translatedTitle,
                  style: TextStyle(
                    color: AppTheme.getTextSecondaryColor(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection() {
    final isDark = AppTheme.isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getBorderColor(context)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppTheme.dangerColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  context.tr('critical_alerts', fallback: 'Alerts & Notifications'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '2',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAlertItem(
            isDark ? AppTheme.darkSurfaceColor : AppTheme.alertBgColor,
            AppTheme.alertTextColor,
            context.tr('alert_opd_inflow', fallback: 'High Patient Inflow in OPD'),
            '10m ago',
          ),
          const SizedBox(height: 12),
          _buildAlertItem(
            isDark ? AppTheme.darkSurfaceColor : AppTheme.infoBgColor,
            AppTheme.infoColor,
            context.tr('alert_ward_capacity', fallback: 'Ward A Approaching Capacity'),
            '25m ago',
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              // Footer action to view alerts
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    context.tr('view_all_alerts', fallback: 'View All Alerts'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppTheme.getTextPrimaryColor(context).withOpacity(0.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Color bg, Color textColor, String text, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: textColor, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
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
                const SizedBox(height: 3),
                Text(
                  time,
                  style: TextStyle(
                    color: textColor.withOpacity(0.65),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPatients() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getBorderColor(context)),
        boxShadow: AppTheme.isDark(context)
            ? []
            : [
                BoxShadow(
                  color: AppTheme.secondaryColor.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.people_outline,
                        color: AppTheme.secondaryColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('recent_patients', fallback: 'Recent Patients'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.getTextPrimaryColor(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _changePage(1),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                ),
                child: Text(
                  context.tr('view_all', fallback: 'View All'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
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
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  context.tr('no_patients_found', fallback: 'No patients found'),
                  style: TextStyle(color: AppTheme.getTextSecondaryColor(context)),
                ),
              ),
            )
          else
            ..._dbPatients.take(4).map((p) {
              final genderStr = p.gender.toLowerCase() == 'male'
                  ? context.tr('gender_male', fallback: 'Male')
                  : (p.gender.toLowerCase() == 'female'
                      ? context.tr('gender_female', fallback: 'Female')
                      : p.gender);
              final ageStr = '${p.age}${context.tr('years_short', fallback: 'y')} • $genderStr';
              return _buildPatientItem(
                p.name,
                ageStr,
                context.tr('registered', fallback: 'Registered'),
                p.isQuickRegister
                    ? context.tr('quick', fallback: 'Quick')
                    : context.tr('standard', fallback: 'Standard'),
                p.isQuickRegister
                    ? const Color(0xFF6B7FD4)
                    : const Color(0xFF0EA5A0),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildPatientItem(
    String name,
    String info,
    String label,
    String status,
    Color statusColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.getAvatarColors(name)['bg'],
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.getAvatarColors(name)['text'],
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  info,
                  style: TextStyle(
                    color: AppTheme.getTextSecondaryColor(context),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.getTextSecondaryColor(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointments() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getBorderColor(context)),
        boxShadow: AppTheme.isDark(context)
            ? []
            : [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_month_outlined,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('upcoming_appointments', fallback: 'Upcoming Appointments'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.getTextPrimaryColor(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _changePage(2),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                ),
                child: Text(
                  context.tr('view_all', fallback: 'View All'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
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
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  context.tr('no_appointments_found', fallback: 'No appointments found'),
                  style: TextStyle(color: AppTheme.getTextSecondaryColor(context)),
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
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          size: 40,
                          color: AppTheme.getBorderColor(context),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('no_appointments_today', fallback: 'No appointments for today'),
                          style: TextStyle(
                            color: AppTheme.getTextSecondaryColor(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.getTextPrimaryColor(context),
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
            style: TextStyle(
              color: AppTheme.getTextSecondaryColor(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.isDark(context)
                  ? AppTheme.primaryColor.withOpacity(0.18)
                  : const Color(0xFFEFF6FF),
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
          Divider(height: 1, color: AppTheme.getBorderColor(context)),
        ],
      ),
    );
  }

  // --- Helpers ---

  String _formatTo12Hour(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--';
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour % 12 == 0 ? 12 : hour % 12;
      final formattedMinute = minute.toString().padLeft(2, '0');
      return '${formattedHour.toString().padLeft(2, '0')}:$formattedMinute $ampm';
    } catch (_) {
      return timeStr;
    }
  }

  // --- Shift Status Panel & Handover Cards ---

  Widget _buildShiftStatusPanel(bool isMobile) {
    String currentShift = context.tr('active_shift', fallback: 'Active Shift');
    String wardType = context.tr('general_ward', fallback: 'General Ward');
    String timings = '06:00 AM - 02:00 PM';
    String assignedNurse = context.tr('not_assigned', fallback: 'Not Assigned');
    String status = context.tr('not_assigned', fallback: 'Not Assigned');
    String prevNurse = context.tr('none', fallback: 'None');
    String nextNurse = context.tr('none', fallback: 'None');
    String wardRoom = context.tr('none', fallback: 'None');

    Map<String, dynamic>? dataToUse = _activeShiftData ?? _todayShiftData;

    if (dataToUse != null) {
      final shiftRaw = dataToUse['shift_name'] ?? dataToUse['current_shift'];
      currentShift = shiftRaw != null ? '$shiftRaw' : context.tr('active_shift', fallback: 'Active Shift');
      final wardRaw = dataToUse['ward_type'];
      wardType = wardRaw != null ? '$wardRaw' : context.tr('general_ward', fallback: 'General Ward');
      final startTime = dataToUse['start_time']?.toString();
      final endTime = dataToUse['end_time']?.toString();
      timings = '${_formatTo12Hour(startTime)} - ${_formatTo12Hour(endTime)}';
      assignedNurse =
          dataToUse['assigned_nurse']?.toString() ??
          dataToUse['nurse_name']?.toString() ??
          context.tr('not_assigned', fallback: 'Not Assigned');
      final rawStatus = dataToUse['status']?.toString();
      status = rawStatus != null
          ? (rawStatus.toLowerCase() == 'assigned'
              ? context.tr('status_assigned', fallback: 'Assigned')
              : rawStatus)
          : context.tr('status_assigned', fallback: 'Assigned');
      prevNurse = dataToUse['previous_nurse']?.toString() ?? context.tr('none', fallback: 'None');
      nextNurse = dataToUse['next_nurse']?.toString() ?? context.tr('none', fallback: 'None');
      wardRoom = dataToUse['ward_type']?.toString() ?? context.tr('none', fallback: 'None');
    }

    final isAssigned = status.toLowerCase() == 'assigned' || status == context.tr('status_assigned', fallback: 'Assigned');
    final statusColor = isAssigned
        ? const Color(0xFF2E7D32)
        : const Color(0xFF92400E);
    final statusBg = isAssigned
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFEF3C7);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias, // Clip children to rounded corners
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor,
          width: 2.5,
        ), // Outer blue border
        boxShadow: AppTheme.isDark(context)
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 20,
              vertical: isMobile ? 12 : 14,
            ),
            color: AppTheme.primaryColor, // Logo Blue
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.wb_sunny_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$currentShift  ·  $wardType',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timings,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(
                        Icons.wb_sunny_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$currentShift  ·  $wardType',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          timings,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // Body Columns
          Container(
            color: AppTheme.getCardColor(context),
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMobile) ...[
                  _buildShiftInfoRowLight(context.tr('assigned_nurse', fallback: 'Assigned Nurse'), assignedNurse),
                  const SizedBox(height: 10),
                  _buildShiftInfoRowLight(
                    context.tr('status', fallback: 'Status'),
                    status,
                    isStatus: true,
                    statusBg: statusBg,
                    statusColor: statusColor,
                  ),
                  const SizedBox(height: 10),
                  _buildShiftInfoRowLight(context.tr('prev_nurse', fallback: 'Prev Nurse'), prevNurse),
                  const SizedBox(height: 10),
                  _buildShiftInfoRowLight(context.tr('next_nurse', fallback: 'Next Nurse'), nextNurse),
                  const SizedBox(height: 10),
                  _buildShiftInfoRowLight(context.tr('ward_room', fallback: 'Ward/Room'), wardRoom),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: _buildShiftInfoColumnWithIcon(
                          Icons.person_outline,
                          context.tr('assigned_nurse', fallback: 'Assigned Nurse'),
                          assignedNurse,
                        ),
                      ),
                      _buildShiftLightDivider(),
                      Expanded(
                        child: _buildShiftStatusBadgeColumnWithIcon(
                          Icons.person_outline,
                          context.tr('status', fallback: 'Status'),
                          status,
                          statusBg,
                          statusColor,
                        ),
                      ),
                      _buildShiftLightDivider(),
                      Expanded(
                        child: _buildShiftInfoColumnWithIcon(
                          Icons.person_outline,
                          context.tr('prev_nurse', fallback: 'Prev Nurse'),
                          prevNurse,
                        ),
                      ),
                      _buildShiftLightDivider(),
                      Expanded(
                        child: _buildShiftInfoColumnWithIcon(
                          Icons.single_bed_outlined,
                          context.tr('next_nurse', fallback: 'Next Nurse'),
                          nextNurse,
                        ),
                      ),
                      _buildShiftLightDivider(),
                      Expanded(
                        child: _buildShiftInfoColumnWithIcon(
                          Icons.hub_outlined,
                          context.tr('ward_room', fallback: 'Ward/Room'),
                          wardRoom,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftInfoColumnWithIcon(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.getTextSecondaryColor(context),
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: AppTheme.getTextPrimaryColor(context),
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShiftStatusBadgeColumnWithIcon(
    IconData icon,
    String label,
    String value,
    Color bg,
    Color textColor,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.getTextSecondaryColor(context),
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShiftInfoRowLight(
    String label,
    String value, {
    bool isStatus = false,
    Color? statusBg,
    Color? statusColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.getTextSecondaryColor(context),
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        if (isStatus && statusBg != null && statusColor != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          )
        else
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.getTextPrimaryColor(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
      ],
    );
  }

  Widget _buildShiftLightDivider() {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppTheme.getBorderColor(context),
    );
  }

  List<Widget> _buildPendingHandoverCards(bool isMobile) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return [];

    final isDark = AppTheme.isDark(context);
    final pending = _handovers
        .where(
          (h) =>
              h['incoming_nurse_id']?.toString() == user.id.toString() &&
              h['status'] == 'Pending',
        )
        .toList();

    return pending.map((h) {
      final outgoing = h['outgoing_nurse_name'] ?? 'Unassigned';
      final ward = h['ward_type'] ?? '';
      final shift = h['shift_name'] ?? '';

      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF451A03).withOpacity(0.45) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.swap_horiz,
                          color: Color(0xFFD97706),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr('pending_shift_handover', fallback: 'Pending Shift Handover'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Incoming from $outgoing for $ward Ward ($shift Shift). Please acknowledge.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(context.tr('acknowledge', fallback: 'Acknowledge')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _acknowledgeHandover(h['id']),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.swap_horiz,
                      color: Color(0xFFD97706),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('pending_shift_handover', fallback: 'Pending Shift Handover'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Incoming from $outgoing for $ward Ward ($shift Shift). Please acknowledge.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(context.tr('acknowledge', fallback: 'Acknowledge')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _acknowledgeHandover(h['id']),
                  ),
                ],
              ),
      );
    }).toList();
  }
}

class CardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          const Color(0xFFD1D5DB) // Soft gray line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    path.moveTo(0, size.height * 0.6);

    // Smooth S-curve wave going across the bottom
    path.cubicTo(
      size.width * 0.25,
      size.height * 0.2,
      size.width * 0.75,
      size.height * 1.0,
      size.width,
      size.height * 0.6,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BubbleBackgroundPainter extends CustomPainter {
  final Color color;
  final bool isLeft;

  BubbleBackgroundPainter({required this.color, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // Circle base
    path.addOval(Rect.fromLTWH(0, 0, size.width, size.height));

    // Symmetrical speech bubble tail pointers extending outwards
    if (isLeft) {
      path.moveTo(size.width * 0.18, size.height * 0.76);
      path.lineTo(size.width * 0.02, size.height * 0.96);
      path.lineTo(size.width * 0.38, size.height * 0.88);
    } else {
      path.moveTo(size.width * 0.82, size.height * 0.76);
      path.lineTo(size.width * 0.98, size.height * 0.96);
      path.lineTo(size.width * 0.62, size.height * 0.88);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
