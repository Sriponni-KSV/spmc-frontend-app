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
import 'doctor_ipd_management.dart';
import 'ot_management.dart';
import '../controllers/ot_controller.dart';

class DashboardScreen extends StatefulWidget {
  final int initialIndex;
  const DashboardScreen({Key? key, this.initialIndex = 0}) : super(key: key);

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
  final FocusNode _mainFocusNode = FocusNode();
  AppointmentModel? _activeAppointment;
  bool _isEditingProfile = false;
  String? _selectedPatientName;
  String _selectedConsultationYearFilter = 'All';
  String _consultationSearchQuery = '';
  late TextEditingController _consultationSearchController;
  DoctorController get _doctorController => DoctorController();
  final OtController _otController = OtController();
  List<OtCase> _anaesthetistOtCases = [];
  OtCase? _otInitialSelectedCase;
  int? _otInitialTab;
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

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _initControllers();
    _fetchDoctorData();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _selectedIndex = widget.initialIndex;
      });
    }
  }

  void _initControllers() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _nameController = TextEditingController(text: user?.fullname ?? '');
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
  }

  @override
  void dispose() {
    _mainFocusNode.dispose();
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

  bool _isDoctorMatch(String docName, String userName) {
    String clean(String s) {
      s = s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (s.startsWith('dr.')) s = s.substring(3).trim();
      if (s.startsWith('dr ')) s = s.substring(2).trim();
      if (s.contains(' - ')) s = s.split(' - ')[0].trim();
      return s;
    }

    final cDoc = clean(docName);
    final cUser = clean(userName);
    if (cDoc.isEmpty || cUser.isEmpty) return false;
    return cDoc == cUser || cDoc.contains(cUser) || cUser.contains(cDoc);
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
            return _isDoctorMatch(appt.doctorName, user?.fullname ?? '');
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

    try {
      setState(() => _isLoading = true);
      await _appointmentController.updateStatus(
        appointment.id!,
        'In Consultation',
      );
      await _fetchDoctorData();
      if (!mounted) return;
      setState(
        () => _activeAppointment = appointment.copyWith(
          status: 'In Consultation',
        ),
      );
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
    setState(() {
      _activeAppointment = appointment;
    });
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
      final date = DateFormatter.toDateTime(c['appointment_date']) ?? DateTime.now();
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
        drawer: isMobile ? Drawer(child: _buildSidebar(isMobile)) : null,

        floatingActionButton: CustomSpeedDial(children: []),
        body: Row(
          children: [
            if (!isMobile) _buildSidebar(isMobile),
            Expanded(
              child: Column(
                children: [
                  _buildHeader(isMobile, user?.fullname ?? 'Doctor'),
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
          _fetchConsultations(); // Refresh after potentially saving/updating
          _fetchDoctorData(); // Refresh appointment list status
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
                final dt = DateFormatter.toDateTime(c['appointment_date']) ?? DateTime.now();
                uniqueYears.add(dt.year);
              }
              final sortedYears = uniqueYears.toList()..sort((a, b) => b.compareTo(a));

              // If this patient is expanded, calculate filtered consultations
              List<Map<String, dynamic>> filtered = [];
              if (_selectedPatientName == patientName) {
                filtered = patientConsuls.where((c) {
                  final dt = DateFormatter.toDateTime(c['appointment_date']) ?? DateTime.now();
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
                    final date = (c['appointment_date'] ?? '').toString().toLowerCase();
                    if (!symptoms.contains(q) &&
                        !history.contains(q) &&
                        !diagnosis.contains(q) &&
                        !dept.contains(q) &&
                        !doc.contains(q) &&
                        !date.contains(q)) {
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
        final dt = DateFormatter.toDateTime(c['appointment_date']) ?? DateTime.now();
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
                      '${_formatConsultationDate(c['appointment_date'])} / ${c['appointment_time']}',
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
          isHeader: true,
        ),
        const SizedBox(height: 12),
        _buildGridRow(
          dept,
          null,
          customValueWidget: _buildEditPencilButton(c),
        ),
        const SizedBox(height: 12),
        if (c['symptoms'] != null && c['symptoms'].toString().isNotEmpty) ...[
          _buildGridRow(
            'Problem',
            c['symptoms'].toString(),
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
            labsList.join(', '),
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

            setState(() {
              _activeAppointment = appt;
            });
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
                'Diagnosis',
                consultation['diagnosis'] ?? 'None recorded',
                Icons.biotech_outlined,
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
        setState(() => _isEditingProfile = false);
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Professional Profile',
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
                onPressed: () => setState(() => _isEditingProfile = true),
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
                          user?.fullname.isNotEmpty == true
                              ? user!.fullname[0].toUpperCase()
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
                            user?.fullname ?? 'Doctor',
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
                    user?.fullname ?? '-',
                    Icons.person_outline,
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
                    user?.fullname ?? '-',
                    Icons.person_outline,
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
          ] else ...[
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
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _isEditingProfile = false),
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
                              user?.fullname.isNotEmpty == true
                                  ? user!.fullname[0].toUpperCase()
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
                              user?.fullname ?? 'Doctor',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (user?.specialization?.isNotEmpty == true)
                              Text(
                                user!.specialization!,
                                style: const TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
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
                      ),
                      fieldSpacing,
                      _buildProfileTextField(
                        'Email Address',
                        _emailController,
                        Icons.email_outlined,
                        isReadOnly: true,
                      ),
                      fieldSpacing,
                      _buildProfileTextField(
                        'Mobile Number',
                        _mobileController,
                        Icons.phone_android_outlined,
                        isNumeric: true,
                        maxLength: 10,
                        isReadOnly: true,
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bio / Professional Summary',
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
                            style: const TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontWeight: FontWeight.normal,
                            ),
                            decoration: InputDecoration(
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
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildProfileTextField(
                              'Email Address',
                              _emailController,
                              Icons.email_outlined,
                              isReadOnly: true,
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
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bio / Professional Summary',
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
                          style: const TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.normal,
                          ),
                          decoration: InputDecoration(
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
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Specialization',
                      _specController,
                      Icons.medical_services_outlined,
                      isReadOnly: true,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Medical Registration Number',
                      _licenseController,
                      Icons.badge_outlined,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Total Experience (years)',
                      _expController,
                      Icons.work_outline,
                      isNumeric: true,
                      maxLength: 2,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Areas of Expertise (comma-separated)',
                      _areasOfExpertiseController,
                      Icons.star_outline,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Number of Patients Attended',
                      _patientsController,
                      Icons.people_outline,
                      isNumeric: true,
                      maxLength: 6,
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildProfileTextField(
                            'Qualification (MBBS, MD, etc.)',
                            _qualController,
                            Icons.school_outlined,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileTextField(
                            'Specialization',
                            _specController,
                            Icons.medical_services_outlined,
                            isReadOnly: true,
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
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              sectionSpacing,

              // ── Section 2: Availability ───────────────────────
              sectionCard('2', 'Availability', AppTheme.successColor, [
                // Available / Leave Days chips
                const Text(
                  'Weekly Schedule (Tap: Available ↔ Leave)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
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
                fieldSpacing,
                if (isMobile) ...[
                  _buildTimePickerField(
                    'Slot Start Time',
                    _slotStartController,
                    Icons.access_time_outlined,
                  ),
                  fieldSpacing,
                  _buildTimePickerField(
                    'Slot End Time',
                    _slotEndController,
                    Icons.access_time_filled,
                  ),
                  fieldSpacing,
                  _buildProfileTextField(
                    'Slot Duration (e.g. 15 min)',
                    _slotDurationController,
                    Icons.timelapse_outlined,
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimePickerField(
                          'Slot Start Time',
                          _slotStartController,
                          Icons.access_time_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTimePickerField(
                          'Slot End Time',
                          _slotEndController,
                          Icons.access_time_filled,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildProfileTextField(
                          'Slot Duration (e.g. 15 min)',
                          _slotDurationController,
                          Icons.timelapse_outlined,
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
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Location',
                      _clinicLocationController,
                      Icons.location_on_outlined,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Consultation Fee (₹)',
                      _consultationFeeController,
                      Icons.currency_rupee,
                      isNumeric: true,
                      maxLength: 5,
                    ),
                  ] else ...[
                    _buildProfileTextField(
                      'Clinic / Hospital Name',
                      _clinicNameController,
                      Icons.local_hospital_outlined,
                    ),
                    fieldSpacing,
                    Row(
                      children: [
                        Expanded(
                          child: _buildProfileTextField(
                            'Location',
                            _clinicLocationController,
                            Icons.location_on_outlined,
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
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              sectionSpacing,

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
                  OutlinedButton(
                    onPressed: () => setState(() => _isEditingProfile = false),
                    style: AppTheme.cancelButton.copyWith(
                      minimumSize: MaterialStateProperty.all(
                        const Size(120, 48),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
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
  }) {
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
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          readOnly: isReadOnly,
          maxLength: maxLength,
          inputFormatters: isNumeric
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          mouseCursor: isReadOnly ? SystemMouseCursors.forbidden : null,
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
    );
  }

  Widget _buildSidebar(bool isMobile) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final isAnaesthetist = user?.role == 'Anaesthetist';

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
                Image.asset(
                  'assets/image/full_logo.png',
                  width: 100,
                  height: 89,
                ),
              ],
            ),
          ),

          // Navigation Items (Scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
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
                      3,
                      Icons.local_hospital_outlined,
                      'IPD Management',
                    ),
                    _buildSidebarItem(
                      4,
                      Icons.healing_outlined,
                      'OT Management',
                    ),
                    _buildSidebarItem(2, Icons.person_outline, 'My Profile'),
                  ],
                ],
              ),
            ),
          ),

          // User Profile Footer
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(
                color: AppTheme.borderColor,
                height: 1,
                thickness: 1,
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    final user = auth.user;
                    if (user == null) return const SizedBox.shrink();
                    return Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: CircleAvatar(
                            backgroundColor: AppTheme.getAvatarColors(
                              user.fullname,
                            )['bg'],
                            radius: 18,
                            child: Text(
                              user.fullname.isNotEmpty
                                  ? user.fullname[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: AppTheme.getAvatarColors(
                                  user.fullname,
                                )['text'],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
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
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
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
        } else {
          context.go(AppRoutes.doctorDashboard);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
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

  Widget _buildHeader(bool isMobile, String name) {
    return Container(
      height: isMobile ? 80 : 90,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: Row(
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
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
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
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: AppTheme.textSecondaryColor,
                  ),
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
    // Determine greeting based on time of day
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    if (hour >= 17) greeting = 'Good Evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, ${user?.fullname ?? 'Doctor'}',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Here\'s a quick look at your scheduled appointments today.',
          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
        ),
      ],
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
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildStatCard(
            'Total Appointments',
            totalPatients.toString(),
            'All time',
            Icons.calendar_today_outlined,
            Colors.blue,
            isMobile,
          ),
          _buildStatCard(
            'Today\'s Appointments',
            todayCount.toString(),
            'Scheduled',
            Icons.calendar_month_outlined,
            Colors.indigo,
            isMobile,
          ),
          _buildStatCard(
            'Confirmed Cases',
            confirmedCount.toString(),
            'Ready',
            Icons.check_circle_outline,
            Colors.green,
            isMobile,
          ),
          _buildStatCard(
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
        ],
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
    final filteredAppts = _doctorAppointments.where((a) {
      // Show all appointments except Cancelled and Admitted ones
      if (a.status.toLowerCase() == 'cancelled') return false;
      if (a.status.toLowerCase() == 'admitted') return false;
      if (_selectedDate == null) return true;

      return _isSameDay(a.appointmentDate, _selectedDate!);
    }).toList();

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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    TextButton(
                      onPressed: _fetchDoctorData,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Table Rows Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: const Color(0xFFF7FAFC),
            child: Row(
              children: [
                Expanded(flex: 3, child: _buildTableHeaderText('PATIENT')),
                Expanded(flex: 2, child: _buildTableHeaderText('PATIENT ID')),
                Expanded(flex: 2, child: _buildTableHeaderText('TYPE')),
                Expanded(flex: 2, child: _buildTableHeaderText('TIME')),
                Expanded(flex: 3, child: _buildTableHeaderText('REASON')),
                Expanded(flex: 2, child: _buildTableHeaderText('STATUS')),
                Expanded(
                  flex: 2,
                  child: SizedBox(),
                ), // Action column for alignment
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
            ...filteredAppts.take(10).map((appt) {
              return Column(
                children: [
                  _buildPatientTableRow(appt),
                  const Divider(height: 1),
                ],
              );
            }).toList(),

          if (filteredAppts.length > 10)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: TextButton(
                  onPressed: () {},
                  child: Text('View All ${filteredAppts.length} Appointments'),
                ),
              ),
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
                    child: Text(
                      appt.patientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Patient ID Column
            Expanded(
              flex: 2,
              child: Text(
                patientIdText,
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                ),
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

            // Reason Column
            Expanded(
              flex: 3,
              child: Text(
                reasonText,
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                alignment: Alignment.centerRight,
                child: appt.status == 'Waiting'
                    ? TextButton.icon(
                        onPressed: () => _startConsultation(appt),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
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
                    : appt.status == 'Confirmed'
                    ? TextButton.icon(
                        onPressed: null,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
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
                    ? TextButton.icon(
                        onPressed: () => _resumeConsultation(appt),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.secondaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
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
                    : const SizedBox.shrink(),
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

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          _buildAnaesthetistGreeting(),
          const SizedBox(height: 24),
          
          // Stats Row
          _buildAnaesthetistStatsRow(isMobile, totalCases, pacPending, activeRecovery, emergencyCases),
          const SizedBox(height: 24),
          
          // OT Cases Schedule Table
          _buildAnaesthetistScheduleTable(isMobile),
        ],
      ),
    );
  }

  Widget _buildAnaesthetistGreeting() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    if (hour >= 17) greeting = 'Good Evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, Dr. ${user?.fullname ?? 'Anaesthetist'}',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Here\'s a look at your anesthesia schedule and checklists today.',
          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
        ),
      ],
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
}
