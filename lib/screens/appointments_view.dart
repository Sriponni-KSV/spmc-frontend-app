import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/routes/route_constants.dart';
import '../widgets/custom_dropdown_search.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../utils/app_localizations.dart';
import '../models/patient_model.dart';
import '../models/user_model.dart';
import '../models/appointment_model.dart';
import '../controllers/patient_controller.dart';
import '../controllers/admin_controller.dart';
import '../controllers/appointment_controller.dart';
import '../widgets/appointment_details_dialog.dart';
import 'mocdoc_appointments_view.dart';
import '../utils/date_formatter.dart';
import '../utils/tamil_transliteration_helper.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';

class AppointmentsView extends StatefulWidget {
  final bool startWithBookingForm;
  final PatientModel? initialPatient;
  final UserModel? initialDoctor;
  final String? initialViewMode;

  const AppointmentsView({
    super.key,
    this.startWithBookingForm = false,
    this.initialPatient,
    this.initialDoctor,
    this.initialViewMode,
  });

  @override
  State<AppointmentsView> createState() => _AppointmentsViewState();
}

class _AppointmentsViewState extends State<AppointmentsView> {
  String _currentViewMode = 'Table';
  String _selectedStatus = 'All Status';
  int _currentPage = 0;
  final int _itemsPerPage = 10;
  String _searchQuery = '';
  final TextEditingController _apptSearchController = TextEditingController();
  DateTime? _filterDate = DateTime.now();
  String _selectedApptType = 'Routine';
  final List<String> _apptTypes = [
    'Routine',
    'Follow Up',
    'New Visit',
    'Scheduled',
    'Emergency',
  ];
  bool _isBookingAppointment = false;

  // Form Selections
  PatientModel? _selectedPatient;
  String? _selectedDept;
  UserModel? _selectedDoctor;
  String? _selectedTime;
  DateTime? _bookingDate;

  final TextEditingController _bpSystolicController = TextEditingController();
  final TextEditingController _bpDiastolicController = TextEditingController();
  final TextEditingController _sugarController = TextEditingController();
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(text: '');
  final TextEditingController _reasonController = TextEditingController();

  // Live Data
  final PatientController _patientController = PatientController();
  final AdminController _adminController = AdminController();
  final AppointmentController _appointmentController = AppointmentController();

  List<PatientModel> _patients = [];
  List<UserModel> _doctors = [];
  List<AppointmentModel> _appointments = [];
  List<String> _departments = [];
  List<String> _availableSlots = [];
  final int _intervalMinutes = 30; // Set to 15 or 30
  bool _isLoadingData = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialViewMode != null) {
      _currentViewMode = _normalizeViewMode(widget.initialViewMode!);
    }
    if (widget.startWithBookingForm || widget.initialPatient != null) {
      _isBookingAppointment = true;
      if (widget.initialPatient != null) {
        _selectedPatient = widget.initialPatient;
      }
      if (widget.initialDoctor != null) {
        _selectedDoctor = widget.initialDoctor;
      }
    }
    _fetchData();
    _reasonController.addListener(() {
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant AppointmentsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.startWithBookingForm != oldWidget.startWithBookingForm &&
            widget.startWithBookingForm) ||
        (widget.initialPatient != oldWidget.initialPatient &&
            widget.initialPatient != null) ||
        (widget.initialDoctor != oldWidget.initialDoctor &&
            widget.initialDoctor != null)) {
      setState(() {
        _isBookingAppointment = true;
        if (widget.initialPatient != null) {
          _selectedPatient = widget.initialPatient;
        }
        if (widget.initialDoctor != null) {
          _selectedDoctor = widget.initialDoctor;
        }
      });
    } else if (oldWidget.startWithBookingForm && !widget.startWithBookingForm) {
      setState(() {
        _isBookingAppointment = false;
        _clearSelections();
      });
    }
  }

  String _normalizeViewMode(String mode) {
    if (mode.contains('Hospital')) return 'Hospital';
    if (mode.contains('Doctor')) return 'Doctor';
    if (mode.contains('Both') || mode.contains('Combo')) return 'Both';
    return 'Table';
  }

  String _getTranslatedApptType(String type) {
    switch (type.toLowerCase().trim()) {
      case 'routine':
        return context.tr('appt_type_routine', fallback: 'Routine');
      case 'follow up':
        return context.tr('appt_type_follow_up', fallback: 'Follow Up');
      case 'new visit':
        return context.tr('appt_type_new_visit', fallback: 'New Visit');
      case 'scheduled':
        return context.tr('appt_type_scheduled', fallback: 'Scheduled');
      case 'emergency':
        return context.tr('appt_type_emergency', fallback: 'Emergency');
      default:
        return type;
    }
  }

  String _getTranslatedDepartment(String dept) {
    switch (dept.toLowerCase().trim()) {
      case 'general medicine':
        return context.tr('dept_gen_medicine', fallback: 'General Medicine');
      case 'cardiology':
        return context.tr('dept_cardiology', fallback: 'Cardiology');
      case 'pediatrics':
        return context.tr('dept_pediatrics', fallback: 'Pediatrics');
      case 'orthopedics':
        return context.tr('dept_orthopedics', fallback: 'Orthopedics');
      case 'dermatology':
        return context.tr('dept_dermatology', fallback: 'Dermatology');
      case 'gynecology':
        return context.tr('dept_gynecology', fallback: 'Gynecology');
      case 'neurology':
        return context.tr('dept_neurology', fallback: 'Neurology');
      case 'ent':
        return context.tr('dept_ent', fallback: 'ENT');
      case 'ophthalmology':
        return context.tr('dept_ophthalmology', fallback: 'Ophthalmology');
      case 'dental':
        return context.tr('dept_dental', fallback: 'Dental');
      case 'psychiatry':
        return context.tr('dept_psychiatry', fallback: 'Psychiatry');
      case 'general surgery':
      case 'surgery':
        return context.tr('dept_surgery', fallback: 'General Surgery');
      default:
        return dept;
    }
  }

  String _getTranslatedStatus(String status) {
    final s = status.toLowerCase().replaceAll('-', ' ').replaceAll('_', ' ').trim();
    switch (s) {
      case 'confirmed':
        return context.tr('status_confirmed', fallback: 'Confirmed');
      case 'waiting':
        return context.tr('status_waiting', fallback: 'Waiting');
      case 'in consultation':
        return context.tr('status_in_consultation', fallback: 'In Consultation');
      case 'completed':
        return context.tr('status_completed', fallback: 'Completed');
      case 'no show':
        return context.tr('status_no_show', fallback: 'No Show');
      case 'cancelled':
        return context.tr('status_cancelled', fallback: 'Cancelled');
      default:
        return status;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _apptSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });
    try {
      final patients = await _patientController.fetchPatients();
      final doctors = await _adminController.fetchStaff(role: 'Doctor');
      final appointments = await _appointmentController.fetchAppointments();
      final specializations = await _adminController.fetchSpecializations();
      if (!mounted) return;
      setState(() {
        _patients = patients;
        _doctors = doctors.where((d) {
          if (d.status.toLowerCase() != 'active') return false;
          final dp = d.doctorProfile;
          if (dp == null) return false;
          if (dp.slotStartTime == null || dp.slotStartTime!.trim().isEmpty) return false;
          if (dp.slotEndTime == null || dp.slotEndTime!.trim().isEmpty) return false;
          if (dp.slotDuration == null || dp.slotDuration!.trim().isEmpty) return false;
          if (dp.availableDays == null || dp.availableDays!.isEmpty) return false;
          return true;
        }).toList();
        _appointments = appointments;
        final activeDoctorSpecializations = _doctors
            .map((d) => d.specialization)
            .where((s) => s != null)
            .toSet();
        _departments = specializations
            .map((e) => e['name'].toString())
            .where((name) => activeDoctorSpecializations.contains(name))
            .toList();

        // Dynamically recalculate available slots if doctor and date are already selected
        if (_selectedDoctor != null && _bookingDate != null) {
          final foundDoctor = _doctors.where((d) => d.id == _selectedDoctor!.id).toList();
          if (foundDoctor.isNotEmpty) {
            _selectedDoctor = foundDoctor.first;
          }
          final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          final dayName = weekDays[_bookingDate!.weekday - 1];
          bool isDocAvailable = true;
          if (_selectedDoctor!.availableDays != null &&
              !_selectedDoctor!.availableDays!.contains(dayName)) {
            isDocAvailable = false;
          }
          if (_selectedDoctor!.weeklyOffDays != null &&
              _selectedDoctor!.weeklyOffDays!.contains(dayName)) {
            isDocAvailable = false;
          }
          final dateStr = DateFormat('dd/MM/yyyy').format(_bookingDate!);
          if (_selectedDoctor!.specificLeaveDates != null &&
              _selectedDoctor!.specificLeaveDates!.contains(dateStr)) {
            isDocAvailable = false;
          }
          if (isDocAvailable) {
            _availableSlots = _generateSlotsForDoctor(_selectedDoctor!);
          } else {
            _availableSlots = [];
          }
        } else {
          _availableSlots = [];
        }

        // Set initial patient if provided
        if (widget.initialPatient != null) {
          final found = patients
              .where(
                (p) =>
                    (p.id != null && p.id == widget.initialPatient!.id) ||
                    (p.patientId != null &&
                        p.patientId == widget.initialPatient!.patientId),
              )
              .toList();
          if (found.isNotEmpty) {
            _selectedPatient = found.first;
          }
        }

        // Set initial doctor and department if provided
        if (widget.initialDoctor != null) {
          final foundDoctor = doctors
              .where((d) => d.id == widget.initialDoctor!.id)
              .toList();
          if (foundDoctor.isNotEmpty) {
            _selectedDoctor = foundDoctor.first;
            _selectedDept = _selectedDoctor!.specialization;
          }
        }

        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoadingData = false;
      });
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'N/A';
    try {
      String cleanDate = dateStr.contains('T')
          ? dateStr.split('T')[0]
          : dateStr;
      DateTime? dt;
      try {
        dt = DateFormat('dd/MM/yyyy').parse(cleanDate);
      } catch (_) {
        try {
          dt = DateFormat('yyyy-MM-dd').parse(cleanDate);
        } catch (_) {}
      }

      if (dt == null) return dateStr;
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  // Helper to get initials
  String _getInitials(String name) {
    if (name.isEmpty) return '';
    List<String> parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Future<void> _showVitalsMissingDialog(BuildContext context, AppointmentModel appt) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              const Text('Vitals Required', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Vitals must be recorded before changing the appointment status to "Waiting". Would you like to enter them now?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close alert
                _openVitalsEntryDialog(context, appt);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Enter Vitals Now', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _openVitalsEntryDialog(BuildContext context, AppointmentModel appt) {
    final apptDt = DateFormatter.toDateTime(appt.appointmentDate);
    if (apptDt != null) {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final apptMidnight = DateTime(apptDt.year, apptDt.month, apptDt.day);
      if (apptMidnight.isAfter(todayMidnight)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vitals collection is disabled for future-dated appointments.'),
            backgroundColor: Color(0xFFB45309),
          ),
        );
        _openViewDetailsDialog(context, appt);
        return;
      }
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppointmentDetailsDialog(
        appointment: appt,
        editVitalsOnly: true,
        onRefresh: () {
          _fetchData();
        },
      ),
    );
  }

  void _openViewDetailsDialog(BuildContext context, AppointmentModel appt) {
    showDialog(
      context: context,
      builder: (context) => AppointmentDetailsDialog(
        appointment: appt,
        editVitalsOnly: false,
        onRefresh: () {
          _fetchData();
        },
      ),
    );
  }

  // No longer needed: _deptDoctors map

  // Dynamic Time Slots Generator
  List<String> _generateAllTimeSlots() {
    List<String> slots = [];
    // Fallback default slots if no doctor is selected or profile is incomplete
    // Morning Session: 09:00 AM - 01:00 PM
    slots.addAll(_generateSlotsForSession(9, 0, 13, 0, 30));
    // Afternoon Session: 02:00 PM - 05:00 PM
    slots.addAll(_generateSlotsForSession(14, 0, 17, 0, 30));
    return slots;
  }

  List<String> _generateSlotsForDoctor(UserModel doctor) {
    if (doctor.slotStartTime == null || doctor.slotEndTime == null) {
      return _generateAllTimeSlots();
    }

    int duration = _intervalMinutes;
    if (doctor.slotDuration != null) {
      duration =
          int.tryParse(doctor.slotDuration!.split(' ')[0]) ?? _intervalMinutes;
    }

    try {
      DateTime start = _parseTime(doctor.slotStartTime!);
      DateTime end = _parseTime(doctor.slotEndTime!);

      List<String> slots = [];
      DateTime current = start;
      while (current.isBefore(end)) {
        slots.add(DateFormat('hh:mm a').format(current));
        current = current.add(Duration(minutes: duration));
      }
      return slots;
    } catch (e) {
      return _generateAllTimeSlots();
    }
  }

  DateTime _parseTime(String timeStr) {
    final timeParts = timeStr.split(' ');
    final hms = timeParts[0].split(':');
    int hour = int.parse(hms[0]);
    int minute = hms.length > 1 ? int.parse(hms[1]) : 0;
    if (timeParts.length > 1) {
      if (timeParts[1].toUpperCase() == 'PM' && hour < 12) hour += 12;
      if (timeParts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
    }
    return DateTime(2026, 1, 1, hour, minute);
  }

  List<String> _generateSlotsForSession(
    int startHour,
    int startMin,
    int endHour,
    int endMin,
    int interval,
  ) {
    List<String> sessionSlots = [];
    DateTime start = DateTime(2026, 1, 1, startHour, startMin);
    DateTime end = DateTime(2026, 1, 1, endHour, endMin);

    while (start.isBefore(end)) {
      sessionSlots.add(DateFormat('hh:mm a').format(start));
      start = start.add(Duration(minutes: interval));
    }
    return sessionSlots;
  }

  String _normalizeTime(String timeStr) {
    try {
      String clean = timeStr.trim();
      if (clean.toUpperCase().contains('AM') || clean.toUpperCase().contains('PM')) {
        DateTime dt = DateFormat('h:mm a').parse(clean);
        return DateFormat('hh:mm a').format(dt);
      } else {
        DateTime dt = DateFormat('HH:mm').parse(clean);
        return DateFormat('hh:mm a').format(dt);
      }
    } catch (_) {
      return timeStr.trim();
    }
  }

  void _updateAvailableSlots() {
    if (_selectedDoctor == null || _bookingDate == null) {
      setState(() {
        _availableSlots = [];
      });
      return;
    }

    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = weekDays[_bookingDate!.weekday - 1];

    // 1. Check if day is available (if doctor specifies availableDays)
    if (_selectedDoctor!.availableDays != null &&
        _selectedDoctor!.availableDays!.isNotEmpty &&
        !_selectedDoctor!.availableDays!.contains(dayName)) {
      setState(() => _availableSlots = []);
      return;
    }

    // 2. Check for weekly off
    if (_selectedDoctor!.weeklyOffDays != null &&
        _selectedDoctor!.weeklyOffDays!.isNotEmpty &&
        _selectedDoctor!.weeklyOffDays!.contains(dayName)) {
      setState(() => _availableSlots = []);
      return;
    }

    // 3. Check for specific leave
    final dateStr = DateFormat('dd/MM/yyyy').format(_bookingDate!);
    if (_selectedDoctor!.specificLeaveDates != null &&
        _selectedDoctor!.specificLeaveDates!.contains(dateStr)) {
      setState(() => _availableSlots = []);
      return;
    }

    setState(() {
      _availableSlots = _generateSlotsForDoctor(_selectedDoctor!);
    });
  }

  bool _isDateSelectable(DateTime date) {
    if (_selectedDoctor == null) return true;

    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = weekDays[date.weekday - 1];
    final dateStr = DateFormat('dd/MM/yyyy').format(date);

    bool isAvailable = false;
    if (_selectedDoctor!.availableDays == null ||
        _selectedDoctor!.availableDays!.isEmpty ||
        _selectedDoctor!.availableDays!.contains(dayName)) {
      isAvailable = true;
    }

    if (_selectedDoctor!.weeklyOffDays != null &&
        _selectedDoctor!.weeklyOffDays!.isNotEmpty &&
        _selectedDoctor!.weeklyOffDays!.contains(dayName)) {
      isAvailable = false;
    }

    if (_selectedDoctor!.specificLeaveDates != null &&
        _selectedDoctor!.specificLeaveDates!.contains(dateStr)) {
      isAvailable = false;
    }

    return isAvailable;
  }

  List<String> _getFilteredTimeSlots() {
    if (_bookingDate == null || _selectedDoctor == null) return [];

    DateTime now = DateTime.now();
    bool isToday =
        _bookingDate!.year == now.year &&
        _bookingDate!.month == now.month &&
        _bookingDate!.day == now.day;

    final dateStr1 = DateFormat('dd/MM/yyyy').format(_bookingDate!);
    final dateStr2 = DateFormat('yyyy-MM-dd').format(_bookingDate!);

    List<String> baseSlots = _availableSlots;
    if (baseSlots.isEmpty) {
      baseSlots = _generateSlotsForDoctor(_selectedDoctor!);
    }

    return baseSlots.where((slot) {
      // 1. Check if already booked
      bool isBooked = _appointments.any((a) {
        if (a.status.toLowerCase() == 'cancelled') return false;
        if (a.doctorName.toLowerCase().trim() !=
            _selectedDoctor!.fullname.toLowerCase().trim()) {
          return false;
        }

        String aDate = a.appointmentDate;
        if (aDate.contains('T')) aDate = aDate.split('T')[0];
        if (aDate != dateStr1 && aDate != dateStr2) return false;

        return _normalizeTime(a.appointmentTime) == _normalizeTime(slot);
      });

      if (isBooked) return false;

      // 2. If today, filter out past slots (unless it's the currently selected slot)
      if (isToday && slot != _selectedTime) {
        try {
          DateTime slotTime = DateFormat('hh:mm a').parse(slot);
          DateTime fullSlotTime = DateTime(
            _bookingDate!.year,
            _bookingDate!.month,
            _bookingDate!.day,
            slotTime.hour,
            slotTime.minute,
          );
          return fullSlotTime.isAfter(now);
        } catch (e) {
          return true;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    if (_isBookingAppointment) {
      return _buildBookingForm(isMobile);
    }

    if (_currentViewMode != 'Table') {
      final mocdocMode = _currentViewMode == 'Hospital'
          ? 'Hospital View'
          : (_currentViewMode == 'Doctor' ? 'Doctor View' : 'Combo View');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16.0 : 24.0,
              isMobile ? 16.0 : 24.0,
              isMobile ? 16.0 : 24.0,
              0,
            ),
            child: _buildHeader(isMobile),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: MocDocAppointmentsView(
              initialViewMode: mocdocMode,
              hideHeader: true,
              onViewModeChanged: (mode) {
                setState(() {
                  _currentViewMode = _normalizeViewMode(mode);
                });
              },
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
          const SizedBox(height: 32),
          _buildStatCards(isMobile),
          const SizedBox(height: 32),
          _buildFilters(isMobile),
          const SizedBox(height: 24),
          _buildAppointmentsTable(isMobile),
        ],
      ),
    );
  }

  Widget _buildBookingForm(bool isMobile) {
    Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back Link
        InkWell(
          onTap: () {
            setState(() {
              _isBookingAppointment = false;
              _clearSelections();
            });
            final path = GoRouterState.of(context).matchedLocation;
            if (path.startsWith('/nurse')) {
              context.go(AppRoutes.nurseAppointments);
            } else if (path.startsWith('/reception')) {
              context.go(AppRoutes.frontDeskAppointments);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_back, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                context.tr('back_to_appointments', fallback: 'Back to Appointments'),
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Title
        Text(
          context.tr('book_appointment', fallback: 'Book Appointment'),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('book_appointment_sub', fallback: 'Schedule a new appointment for a patient'),
          style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
        ),
      ],
    );

    if (isMobile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 32),
            if (_isLoadingData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFormCard(
                  title: '',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel(context.tr('select_patient_req', fallback: 'Select Patient *')),
                      _buildDropdown<PatientModel>(
                        hint: '',
                        value: _selectedPatient,
                        items: _patients,
                        itemLabel: (p) => '${p.name} (${p.patientId ?? "N/A"})',
                        onChanged: (val) =>
                            setState(() => _selectedPatient = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildFormCard(
                  title: context.tr('patient_vitals_label', fallback: 'Patient Vitals'),
                  headerExtra: TextButton(
                    onPressed: () {},
                    child: Text(
                      context.tr('collect_vitals', fallback: 'Collect vitals'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel(context.tr('blood_pressure', fallback: 'Blood Pressure')),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _bpSystolicController,
                              hint: '120',
                              maxLength: 3,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (val) {
                                final text = val?.trim() ?? '';
                                if (text.isEmpty) return null;
                                final num = int.tryParse(text);
                                if (num == null) return 'Enter a number';
                                if (num == 0) return 'Cannot be 0';
                                if (num < 90 || num > 300) return 'Must be 90 to 300';
                                return null;
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              '/',
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildTextField(
                              controller: _bpDiastolicController,
                              hint: '80',
                              maxLength: 3,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (val) {
                                final text = val?.trim() ?? '';
                                if (text.isEmpty) return null;
                                final num = int.tryParse(text);
                                if (num == null) return 'Enter a number';
                                if (num == 0) return 'Cannot be 0';
                                if (num < 50 || num > 180) return 'Must be 50 to 180';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel(context.tr('sugar_level_plain', fallback: 'Sugar Level')),
                                _buildTextField(
                                  controller: _sugarController,
                                  hint: '100 mg/dL',
                                  maxLength: 6,
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                  validator: (val) {
                                    final text = val?.trim() ?? '';
                                    if (text.isEmpty) return null;
                                    final num = double.tryParse(text);
                                    if (num == null) return 'Enter a number';
                                    if (num == 0) return 'Cannot be 0';
                                    if (num < 30 || num > 600) return 'Must be 30 to 600';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel(context.tr('temperature', fallback: 'Temperature')),
                                _buildTextField(
                                  controller: _tempController,
                                  hint: '98.6°F',
                                  maxLength: 5,
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                  validator: (val) {
                                    final text = val?.trim() ?? '';
                                    if (text.isEmpty) return null;
                                    final num = double.tryParse(text);
                                    if (num == null) return 'Enter a number';
                                    if (num == 0) return 'Cannot be 0';
                                    if (num < 90 || num > 115) return 'Must be 90 to 115';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildFormCard(
                  title: context.tr('visit_details', fallback: 'Visit Details'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel(context.tr('appointment_type_req', fallback: 'Appointment Type *')),
                      _buildDropdown<String>(
                        hint: '',
                        value: _selectedApptType,
                        items: _apptTypes,
                        itemLabel: (s) => _getTranslatedApptType(s),
                        onChanged: (val) =>
                            setState(() => _selectedApptType = val ?? ''),
                      ),
                      const SizedBox(height: 16),
                      _buildFieldLabel(context.tr('reason_req', fallback: 'Reason *')),
                      _buildTextField(
                        controller: _reasonController,
                        hint: context.tr('reason_hint', fallback: 'e.g. Regular check-up, fever, etc.'),
                        isNumeric: false,
                        maxLength: 500,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]'),
                          ),
                          LengthLimitingTextInputFormatter(500),
                        ],
                        validator: (val) {
                          final text = val?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Reason for visit is required';
                          }
                          if (!RegExp(r'[a-zA-Z]').hasMatch(text)) {
                            return 'Reason must contain at least one alphabet character';
                          }
                          if (text.length > 500) {
                            return 'Reason must not exceed 500 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildFormCard(
                  title: context.tr('department_doctor', fallback: 'Department & Doctor'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel(context.tr('department_req', fallback: 'Department *')),
                      _buildDropdown<String>(
                        hint: '',
                        value: _selectedDept,
                        items: _departments,
                        itemLabel: (s) => _getTranslatedDepartment(s),
                        onChanged: (val) {
                          if (val != _selectedDept) {
                            setState(() {
                              _selectedDept = val;
                              _selectedDoctor = null;
                              _selectedTime = null;
                            });
                            _updateAvailableSlots();
                          }
                        },
                      ),
                      if (_selectedDept != null) ...[
                        const SizedBox(height: 24),
                        _buildFieldLabel(context.tr('select_doctor_req', fallback: 'Select Doctor *')),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 76,
                          child:
                              _doctors
                                  .where(
                                    (d) => d.specialization == _selectedDept,
                                  )
                                  .isEmpty
                              ? Center(
                                  child: Text(
                                    context.tr('no_doctors_available', fallback: 'No doctors available'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _doctors
                                      .where(
                                        (d) =>
                                            d.specialization == _selectedDept,
                                      )
                                      .length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    final doc = _doctors
                                        .where(
                                          (d) =>
                                              d.specialization == _selectedDept,
                                        )
                                        .toList()[index];
                                    final isSelected = (_selectedDoctor?.id != null && _selectedDoctor?.id == doc.id) ||
                                        (_selectedDoctor?.fullname.trim().toLowerCase() ==
                                            doc.fullname.trim().toLowerCase());
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedDoctor = doc;
                                          _selectedTime = null;
                                        });
                                        _updateAvailableSlots();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFFF0F7FF)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF3B82F6)
                                                : AppTheme.borderColor,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 12,
                                              backgroundColor: const Color(
                                                0xFF1E40AF,
                                              ),
                                              child: Text(
                                                _getInitials(doc.fullname),
                                                style: const TextStyle(
                                                  fontSize: 8,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  doc.fullname,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Color(0xFF2D3748),
                                                  ),
                                                ),
                                                if (doc.staffUniqueId != null && doc.staffUniqueId!.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    doc.staffUniqueId!,
                                                    style: const TextStyle(
                                                      color: AppTheme.textSecondaryColor,
                                                      fontSize: 9,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildFormCard(
                  title: context.tr('date_and_time', fallback: 'Date & Time'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel(context.tr('appointment_date_req', fallback: 'Appointment Date *')),
                      TextField(
                        controller: _dateController,
                        readOnly: true,
                        onTap: () async {
                          bool hasAnyAvailable = _selectedDoctor?.availableDays?.isNotEmpty ?? false;
                          DateTime initial = _bookingDate ?? DateTime.now();
                          
                          if (hasAnyAvailable) {
                            for (int i = 0; i < 365; i++) {
                              if (_isDateSelectable(initial)) break;
                              initial = initial.add(const Duration(days: 1));
                            }
                          }

                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: initial,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            selectableDayPredicate: hasAnyAvailable ? _isDateSelectable : null,
                          );
                          if (picked != null) {
                            setState(() {
                              _bookingDate = picked;
                              _dateController.text = DateFormat(
                                'dd/MM/yyyy',
                              ).format(picked);
                              _selectedTime = null; // Reset time
                            });
                            _updateAvailableSlots();
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'dd/mm/yyyy',
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: Color(0xFF94A3B8),
                          ),
                          suffixIcon: const Icon(
                            Icons.calendar_month,
                            size: 18,
                            color: Color(0xFF1E293B),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.borderColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (_bookingDate != null) ...[
                        const SizedBox(height: 24),
                        _buildFieldLabel(context.tr('available_time_slots_req', fallback: 'Available Time Slots *')),
                        const SizedBox(height: 8),
                        () {
                          final filteredSlots = _getFilteredTimeSlots();
                          if (filteredSlots.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  context.tr('no_slots_today', fallback: 'No more slots available for today'),
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 2.5,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: filteredSlots.length,
                            itemBuilder: (context, index) {
                              final time = filteredSlots[index];
                              final isSelected = _selectedTime == time;
                              return MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _selectedTime = time),
                                  borderRadius: BorderRadius.circular(8),
                                  hoverColor: AppTheme.primaryColor.withOpacity(
                                    0.05,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : AppTheme.borderColor,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: AppTheme.primaryColor
                                                    .withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                      child: Text(
                                        time,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Summary section at bottom for mobile
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.borderColor.withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('appointment_summary', fallback: 'Appointment Summary'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_selectedPatient != null)
                        _buildSummaryItem(
                          Icons.person_outline,
                          context.tr('patient_name_label', fallback: 'Patient'),
                          _selectedPatient!.name,
                        ),

                      if (_selectedDoctor != null)
                        _buildSummaryItem(
                          Icons.medical_services_outlined,
                          context.tr('doctor_label', fallback: 'Doctor'),
                          _selectedDoctor!.fullname,
                          subtitle: _selectedDept != null ? _getTranslatedDepartment(_selectedDept!) : null,
                        ),

                      if (_bookingDate != null)
                        _buildSummaryItem(
                          Icons.calendar_month_outlined,
                          context.tr('date_heading', fallback: 'Date'),
                          DateFormat('dd/MM/yyyy').format(_bookingDate!),
                        ),

                      if (_selectedTime != null)
                        _buildSummaryItem(
                          Icons.access_time,
                          context.tr('time_heading', fallback: 'Time'),
                          _selectedTime!,
                        ),

                      if (_selectedApptType.isNotEmpty)
                        _buildSummaryItem(
                          Icons.info_outline,
                          context.tr('type_heading', fallback: 'Type'),
                          _getTranslatedApptType(_selectedApptType),
                        ),

                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed:
                            (_selectedPatient != null &&
                                _selectedDoctor != null &&
                                _bookingDate != null &&
                                _selectedTime != null)
                            ? () async {
                                try {
                                  _validateVitals();
                                  final hasVitalsDuringBooking =
                                      _bpSystolicController.text.trim().isNotEmpty &&
                                      _tempController.text.trim().isNotEmpty;
                                  final appointment = AppointmentModel(
                                    patientId: _selectedPatient!.id!,
                                    patientName: _selectedPatient!.name,
                                    department: _selectedDept!,
                                    doctorName: _selectedDoctor!.fullname,
                                    appointmentDate: DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(_bookingDate!),
                                    appointmentTime: _selectedTime!,
                                    appointmentType: _selectedApptType,
                                    bloodPressureSystolic: int.tryParse(
                                      _bpSystolicController.text,
                                    ),
                                    bloodPressureDiastolic: int.tryParse(
                                      _bpDiastolicController.text,
                                    ),
                                    sugarLevel: double.tryParse(
                                      _sugarController.text,
                                    ),
                                    temperature: double.tryParse(
                                      _tempController.text,
                                    ),
                                    reasonForVisit: _reasonController.text,
                                    status: hasVitalsDuringBooking ? 'Waiting' : 'Confirmed',
                                  );

                                  await _appointmentController.bookAppointment(
                                    appointment,
                                  );

                                  final path = GoRouterState.of(context).matchedLocation;
                                  if (path.startsWith('/nurse')) {
                                    context.go(AppRoutes.nurseAppointments);
                                  } else if (path.startsWith('/reception')) {
                                    context.go(AppRoutes.frontDeskAppointments);
                                  } else {
                                    setState(() => _isBookingAppointment = false);
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.tr('appointment_booked_success', fallback: 'Appointment Booked Successfully!'),
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  _clearSelections();
                                  _fetchData(); // Refresh the table
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: const Size(0, 52),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.tr('book_appointment', fallback: 'Book Appointment'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
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
    }

    // Desktop View
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 32),
          if (_isLoadingData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Scrollable Form
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 32),
                      child: Column(
                        children: [
                          _buildFormCard(
                            title: '',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel(context.tr('select_patient_req', fallback: 'Select Patient *')),
                                _buildDropdown<PatientModel>(
                                  hint: '',
                                  value: _selectedPatient,
                                  items: _patients,
                                  itemLabel: (p) => '${p.name} (${p.patientId ?? "N/A"})',
                                  onChanged: (val) =>
                                      setState(() => _selectedPatient = val),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildFormCard(
                            title: context.tr('patient_vitals_label', fallback: 'Patient Vitals'),
                            headerExtra: TextButton(
                              onPressed: () {},
                              child: Text(
                                context.tr('collect_vitals', fallback: 'Collect vitals during booking'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel(context.tr('blood_pressure', fallback: 'Blood Pressure')),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildTextField(
                                              controller: _bpSystolicController,
                                              hint: '120',
                                              maxLength: 3,
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              validator: (val) {
                                                final text = val?.trim() ?? '';
                                                if (text.isEmpty) return null;
                                                final num = int.tryParse(text);
                                                if (num == null) return 'Enter a number';
                                                if (num == 0) return 'Cannot be 0';
                                                if (num < 90 || num > 300) return 'Must be 90 to 300';
                                                return null;
                                              },
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                            ),
                                            child: Text(
                                              '/',
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: _buildTextField(
                                              controller: _bpDiastolicController,
                                              hint: '80',
                                              maxLength: 3,
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              validator: (val) {
                                                final text = val?.trim() ?? '';
                                                if (text.isEmpty) return null;
                                                final num = int.tryParse(text);
                                                if (num == null) return 'Enter a number';
                                                if (num == 0) return 'Cannot be 0';
                                                if (num < 50 || num > 180) return 'Must be 50 to 180';
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel(context.tr('sugar_level_plain', fallback: 'Sugar Level')),
                                      _buildTextField(
                                        controller: _sugarController,
                                        hint: '100 mg/dL',
                                        maxLength: 6,
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                        validator: (val) {
                                          final text = val?.trim() ?? '';
                                          if (text.isEmpty) return null;
                                          final num = double.tryParse(text);
                                          if (num == null) return 'Enter a number';
                                          if (num == 0) return 'Cannot be 0';
                                          if (num < 30 || num > 600) return 'Must be 30 to 600';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel(context.tr('temperature', fallback: 'Temperature')),
                                      _buildTextField(
                                        controller: _tempController,
                                        hint: '98.6°F',
                                        maxLength: 5,
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                        validator: (val) {
                                          final text = val?.trim() ?? '';
                                          if (text.isEmpty) return null;
                                          final num = double.tryParse(text);
                                          if (num == null) return 'Enter a number';
                                          if (num == 0) return 'Cannot be 0';
                                          if (num < 90 || num > 115) return 'Must be 90 to 115';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildFormCard(
                            title: context.tr('visit_details', fallback: 'Visit Details'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel(context.tr('appointment_type_req', fallback: 'Appointment Type *')),
                                _buildDropdown<String>(
                                  hint: '',
                                  value: _selectedApptType,
                                  items: _apptTypes,
                                  itemLabel: (s) => _getTranslatedApptType(s),
                                  onChanged: (val) =>
                                      setState(() => _selectedApptType = val ?? ''),
                                ),
                                const SizedBox(height: 16),
                                _buildFieldLabel(context.tr('reason_req', fallback: 'Reason *')),
                                _buildTextField(
                                  controller: _reasonController,
                                  hint: context.tr('reason_hint', fallback: 'e.g. Regular check-up, fever, etc.'),
                                  isNumeric: false,
                                  maxLength: 500,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]'),
                                    ),
                                    LengthLimitingTextInputFormatter(500),
                                  ],
                                  validator: (val) {
                                    final text = val?.trim() ?? '';
                                    if (text.isEmpty) {
                                      return 'Reason for visit is required';
                                    }
                                    if (!RegExp(r'[a-zA-Z]').hasMatch(text)) {
                                      return 'Reason must contain at least one alphabet character';
                                    }
                                    if (text.length > 500) {
                                      return 'Reason must not exceed 500 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildFormCard(
                            title: context.tr('department_doctor', fallback: 'Department & Doctor'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel(context.tr('department_req', fallback: 'Department *')),
                                _buildDropdown<String>(
                                  hint: '',
                                  value: _selectedDept,
                                  items: _departments,
                                  itemLabel: (s) => _getTranslatedDepartment(s),
                                  onChanged: (val) {
                                    if (val != _selectedDept) {
                                      setState(() {
                                        _selectedDept = val;
                                        _selectedDoctor = null;
                                        _selectedTime = null;
                                      });
                                      _updateAvailableSlots();
                                    }
                                  },
                                ),
                                if (_selectedDept != null) ...[
                                  const SizedBox(height: 24),
                                  _buildFieldLabel(context.tr('select_doctor_req', fallback: 'Select Doctor *')),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 76,
                                    child:
                                        _doctors
                                            .where(
                                              (d) =>
                                                  d.specialization ==
                                                  _selectedDept,
                                            )
                                            .isEmpty
                                        ? Center(
                                            child: Text(
                                              context.tr('no_doctors_available', fallback: 'No doctors available in this department'),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          )
                                        : ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: _doctors
                                                .where(
                                                  (d) =>
                                                      d.specialization ==
                                                      _selectedDept,
                                                )
                                                .length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(width: 16),
                                            itemBuilder: (context, index) {
                                              final doc = _doctors
                                                  .where(
                                                    (d) =>
                                                        d.specialization ==
                                                        _selectedDept,
                                                  )
                                                  .toList()[index];
                                              final isSelected = (_selectedDoctor?.id != null && _selectedDoctor?.id == doc.id) ||
                                                  (_selectedDoctor?.fullname.trim().toLowerCase() ==
                                                      doc.fullname.trim().toLowerCase());
                                              return InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedDoctor = doc;
                                                    _selectedTime = null;
                                                  });
                                                  _updateAvailableSlots();
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFFF0F7FF,
                                                          )
                                                        : Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? const Color(
                                                            0xFF3B82F6,
                                                            )
                                                          : AppTheme
                                                                .borderColor,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        isSelected
                                                            ? Icons
                                                                  .radio_button_checked
                                                            : Icons
                                                                  .radio_button_off,
                                                        size: 18,
                                                        color: isSelected
                                                            ? const Color(
                                                                0xFF3B82F6,
                                                              )
                                                            : const Color(
                                                                0xFF94A3B8,
                                                              ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      CircleAvatar(
                                                        radius: 14,
                                                        backgroundColor:
                                                            const Color(
                                                              0xFF1E40AF,
                                                            ),
                                                        child: Text(
                                                          _getInitials(
                                                            doc.fullname,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 10,
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            doc.fullname,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 13,
                                                                  color: Color(
                                                                    0xFF2D3748,
                                                                  ),
                                                                ),
                                                          ),
                                                          if (doc.staffUniqueId != null && doc.staffUniqueId!.isNotEmpty) ...[
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              doc.staffUniqueId!,
                                                              style: const TextStyle(
                                                                color: AppTheme.textSecondaryColor,
                                                                fontSize: 10,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildFormCard(
                            title: context.tr('date_and_time', fallback: 'Date & Time'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel(context.tr('appointment_date_req', fallback: 'Appointment Date *')),
                                TextField(
                                  controller: _dateController,
                                  readOnly: true,
                                  onTap: () async {
                                    bool hasAnyAvailable = _selectedDoctor?.availableDays?.isNotEmpty ?? false;
                                    DateTime initial = _bookingDate ?? DateTime.now();
                                    
                                    if (hasAnyAvailable) {
                                      for (int i = 0; i < 365; i++) {
                                        if (_isDateSelectable(initial)) break;
                                        initial = initial.add(const Duration(days: 1));
                                      }
                                    }

                                    DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: initial,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                      selectableDayPredicate: hasAnyAvailable ? _isDateSelectable : null,
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _bookingDate = picked;
                                        _dateController.text = DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(picked);
                                        _selectedTime = null; // Reset time
                                      });
                                      _updateAvailableSlots();
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'dd/mm/yyyy',
                                    filled: true,
                                    fillColor: Colors.white,
                                    prefixIcon: const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    suffixIcon: const Icon(
                                      Icons.calendar_month,
                                      size: 18,
                                      color: Color(0xFF1E293B),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppTheme.borderColor,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppTheme.primaryColor,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                if (_bookingDate != null) ...[
                                  const SizedBox(height: 24),
                                  _buildFieldLabel(context.tr('available_time_slots_req', fallback: 'Available Time Slots *')),
                                  const SizedBox(height: 8),
                                  () {
                                    final filteredSlots =
                                        _getFilteredTimeSlots();
                                    if (_selectedDoctor == null) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 20,
                                        ),
                                        child: Center(
                                          child: Text(
                                            context.tr('select_doctor_req', fallback: 'Please select a doctor to see available time slots'),
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    if (filteredSlots.isEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 20,
                                        ),
                                        child: Center(
                                          child: Text(
                                            context.tr('no_slots_today', fallback: 'No more slots available for today'),
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 4,
                                            childAspectRatio: 2.5,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                          ),
                                      itemCount: filteredSlots.length,
                                      itemBuilder: (context, index) {
                                        final time = filteredSlots[index];
                                        final isSelected =
                                            _selectedTime == time;
                                        return InkWell(
                                          onTap: () => setState(
                                            () => _selectedTime = time,
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppTheme.primaryColor
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected
                                                    ? AppTheme.primaryColor
                                                    : AppTheme.borderColor,
                                              ),
                                            ),
                                            child: Center(
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.access_time,
                                                    size: 14,
                                                    color: isSelected
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF94A3B8,
                                                          ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    time,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: isSelected
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF1E293B,
                                                            ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }(),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                // Right Column: Summary
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.borderColor.withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('appointment_summary', fallback: 'Appointment Summary'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),

                            if (_selectedPatient != null)
                              _buildSummaryItem(
                                Icons.person_outline,
                                context.tr('patient_name_label', fallback: 'Patient'),
                                _selectedPatient!.name,
                              ),

                            if (_selectedDoctor != null)
                              _buildSummaryItem(
                                Icons.medical_services_outlined,
                                context.tr('doctor_label', fallback: 'Doctor'),
                                _selectedDoctor!.fullname,
                                subtitle: _selectedDept != null ? _getTranslatedDepartment(_selectedDept!) : null,
                              ),

                            if (_bookingDate != null)
                              _buildSummaryItem(
                                Icons.calendar_month_outlined,
                                context.tr('date_heading', fallback: 'Date'),
                                DateFormat(
                                  'dd/MM/yyyy',
                                ).format(_bookingDate!),
                              ),

                            if (_selectedTime != null)
                              _buildSummaryItem(
                                Icons.access_time,
                                context.tr('time_heading', fallback: 'Time'),
                                _selectedTime!,
                              ),

                            if (_selectedApptType.isNotEmpty)
                              _buildSummaryItem(
                                Icons.info_outline,
                                context.tr('type_heading', fallback: 'Type'),
                                _getTranslatedApptType(_selectedApptType),
                              ),

                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed:
                                  (_selectedPatient != null &&
                                      _selectedDoctor != null &&
                                      _bookingDate != null &&
                                      _selectedTime != null)
                                  ? () async {
                                      try {
                                        _validateVitals();
                                        final hasVitalsDuringBooking =
                                            _bpSystolicController.text.trim().isNotEmpty &&
                                            _tempController.text.trim().isNotEmpty;
                                        final appointment = AppointmentModel(
                                          patientId: _selectedPatient!.id!,
                                          patientName: _selectedPatient!.name,
                                          department: _selectedDept!,
                                          doctorName: _selectedDoctor!.fullname,
                                          appointmentDate: DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(_bookingDate!),
                                          appointmentTime: _selectedTime!,
                                          appointmentType: _selectedApptType,
                                          bloodPressureSystolic: int.tryParse(
                                            _bpSystolicController.text,
                                          ),
                                          bloodPressureDiastolic: int.tryParse(
                                            _bpDiastolicController.text,
                                          ),
                                          sugarLevel: double.tryParse(
                                            _sugarController.text,
                                          ),
                                          temperature: double.tryParse(
                                            _tempController.text,
                                          ),
                                          reasonForVisit:
                                              _reasonController.text,
                                          status: hasVitalsDuringBooking ? 'Waiting' : 'Confirmed',
                                        );

                                        await _appointmentController
                                            .bookAppointment(appointment);
                                         final path = GoRouterState.of(context).matchedLocation;
                                         if (path.startsWith('/nurse')) {
                                           context.go(AppRoutes.nurseAppointments);
                                         } else if (path.startsWith('/reception')) {
                                           context.go(AppRoutes.frontDeskAppointments);
                                         } else {
                                           setState(
                                             () => _isBookingAppointment = false,
                                           );
                                         }

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              context.tr('appointment_booked_success', fallback: 'Appointment Booked Successfully!'),
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        _clearSelections();
                                        _fetchData(); // Refresh the table
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size(0, 44),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    context.tr('book_appointment', fallback: 'Book Appointment'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    if (!label.contains('*')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      );
    }

    final parts = label.split('*');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: parts[0],
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            const TextSpan(
              text: '*',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            if (parts.length > 1 && parts[1].isNotEmpty)
              TextSpan(
                text: parts[1],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A5568),
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isNumeric = true,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        isDense: true,
        counterText: maxLength != null ? '' : null,
        errorMaxLines: 2,
        errorStyle: const TextStyle(
          fontSize: 11,
          color: AppTheme.dangerColor,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppTheme.dangerColor,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppTheme.dangerColor,
            width: 1.5,
          ),
        ),
      ),
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
      maxLength: maxLength,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      inputFormatters: inputFormatters ??
          (isNumeric
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]'),
                  ),
                  LengthLimitingTextInputFormatter(maxLength ?? 500),
                ]),
    );
  }

  Widget _buildSummaryItem(
    IconData icon,
    String label,
    String value, {
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _validateVitals() {
    final reasonText = _reasonController.text.trim();
    if (reasonText.isEmpty) {
      throw 'Reason for visit is required';
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(reasonText)) {
      throw 'Reason for visit must contain at least one alphabet character';
    }
    if (reasonText.length > 500) {
      throw 'Reason for visit must not exceed 500 characters';
    }

    final sysText = _bpSystolicController.text.trim();
    final diaText = _bpDiastolicController.text.trim();
    final sugarText = _sugarController.text.trim();
    final tempText = _tempController.text.trim();

    if (sysText.isNotEmpty) {
      final val = int.tryParse(sysText);
      if (val == null) throw 'BP Systolic must be an integer';
      if (val == 0) throw 'BP Systolic cannot be 0';
      if (val < 90 || val > 300) throw 'BP Systolic must be between 90 and 300 mmHg';
    }
    if (diaText.isNotEmpty) {
      final val = int.tryParse(diaText);
      if (val == null) throw 'BP Diastolic must be an integer';
      if (val == 0) throw 'BP Diastolic cannot be 0';
      if (val < 50 || val > 180) throw 'BP Diastolic must be between 50 and 180 mmHg';
    }
    if (sugarText.isNotEmpty) {
      final val = double.tryParse(sugarText);
      if (val == null) throw 'Sugar Level must be a number';
      if (val == 0) throw 'Sugar Level cannot be 0';
      if (val < 30 || val > 600) throw 'Sugar Level must be between 30 and 600 mg/dL';
    }
    if (tempText.isNotEmpty) {
      final val = double.tryParse(tempText);
      if (val == null) throw 'Temperature must be a number';
      if (val == 0) throw 'Temperature cannot be 0';
      if (val < 90 || val > 115) throw 'Temperature must be between 90 and 115 °F';
    }
  }

  void _clearSelections() {
    _selectedPatient = null;
    _selectedDept = null;
    _selectedDoctor = null;
    _selectedTime = null;
    _bookingDate = null;
    _dateController.text = '';
    _bpSystolicController.clear();
    _bpDiastolicController.clear();
    _sugarController.clear();
    _tempController.clear();
    _reasonController.clear();
    _selectedApptType = 'Routine';
  }

  Widget _buildFormCard({
    required String title,
    required Widget child,
    Widget? headerExtra,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty || headerExtra != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                if (headerExtra != null) headerExtra,
              ],
            ),
            const SizedBox(height: 20),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String hint,
    T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required Function(T?) onChanged,
  }) {
    final map = <String, String>{};
    for (int i = 0; i < items.length; i++) {
      map[i.toString()] = itemLabel(items[i]);
    }
    
    String? selectedIndexString;
    if (value != null) {
      final idx = items.indexOf(value);
      if (idx != -1) {
        selectedIndexString = idx.toString();
      }
    }
    
    return CustomDropdownSearch(
      label: hint,
      value: selectedIndexString,
      dropdownMap: map,
      onChanged: (val) {
        if (val != null) {
          final idx = int.tryParse(val);
          if (idx != null && idx >= 0 && idx < items.length) {
            onChanged(items[idx]);
          } else {
            onChanged(null);
          }
        } else {
          onChanged(null);
        }
      },
    );
  }

  Widget _buildViewSwitcher() {
    final modes = [
      {'key': 'Table', 'label': context.tr('table_view', fallback: 'Table View')},
      {'key': 'Hospital', 'label': context.tr('hospital_view', fallback: 'Hospital View')},
      {'key': 'Doctor', 'label': context.tr('doctor_view', fallback: 'Doctor View')},
      {'key': 'Both', 'label': context.tr('both_view', fallback: 'Both View')},
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: modes.map((m) {
          final isSel = _currentViewMode == m['key'];
          return InkWell(
            onTap: () => setState(() => _currentViewMode = m['key']!),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isSel ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSel
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                m['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSel
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('appointments', fallback: 'Appointments'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('manage_appointments_sub', fallback: 'Manage and schedule patient appointments'),
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildViewSwitcher(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoadingData ? null : _fetchData,
                  icon: _isLoadingData
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(context.tr('refresh', fallback: 'Refresh')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final path = GoRouterState.of(context).matchedLocation;
                    if (path.startsWith('/nurse')) {
                      context.go(AppRoutes.nurseBookAppointment);
                    } else if (path.startsWith('/reception')) {
                      context.go(AppRoutes.frontDeskBookAppointment);
                    } else {
                      setState(() => _isBookingAppointment = true);
                    }
                  },
                  icon: const Icon(Icons.add, size: 20),
                  label: Text(context.tr('book_appointment', fallback: 'Book Appointment')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('appointments', fallback: 'Appointments'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('manage_appointments_sub', fallback: 'Manage and schedule patient appointments'),
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isLoadingData ? null : _fetchData,
                  icon: _isLoadingData
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(context.tr('refresh', fallback: 'Refresh')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(120, 44),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    final path = GoRouterState.of(context).matchedLocation;
                    if (path.startsWith('/nurse')) {
                      context.go(AppRoutes.nurseBookAppointment);
                    } else if (path.startsWith('/reception')) {
                      context.go(AppRoutes.frontDeskBookAppointment);
                    } else {
                      setState(() => _isBookingAppointment = true);
                    }
                  },
                  icon: const Icon(Icons.add, size: 20),
                  label: Text(context.tr('book_appointment', fallback: 'Book Appointment')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildViewSwitcher(),
      ],
    );
  }

  Widget _buildStatCards(bool isMobile) {
    DateTime displayDate = _filterDate ?? DateTime.now();
    String dateStr1 = DateFormat('dd/MM/yyyy').format(displayDate);
    String dateStr2 = DateFormat('yyyy-MM-dd').format(displayDate);

    // Filter appointments for the selected/today date
    final targetAppts = _appointments.where((a) {
      if (a.status.toLowerCase() == 'admitted') return false;
      String apptDate = a.appointmentDate;
      if (apptDate.contains('T')) {
        apptDate = apptDate.split('T')[0];
      }
      return apptDate == dateStr1 || apptDate == dateStr2;
    }).toList();

    int total = targetAppts.length;
    int confirmed = targetAppts.where((a) => a.status == 'Confirmed').length;
    int cancelled = targetAppts.where((a) => a.status == 'Cancelled').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0) return const SizedBox.shrink();
        double cardWidth =
            math.max(0.0, (constraints.maxWidth - (16 * 2)) / 3);
        if (isMobile) {
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildStatCard(
                context.tr('total_today', fallback: 'Total Today'),
                total.toString(),
                icon: Icons.calendar_today_rounded,
                accentColor: const Color(0xFF005691),
              ),
              _buildStatCard(
                context.tr('confirmed', fallback: 'Confirmed'),
                confirmed.toString(),
                icon: Icons.check_circle_rounded,
                accentColor: const Color(0xFF16A34A),
              ),
              _buildStatCard(
                context.tr('cancelled', fallback: 'Cancelled'),
                cancelled.toString(),
                icon: Icons.cancel_rounded,
                accentColor: const Color(0xFFDC2626),
              ),
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildStatCard(
              context.tr('total_today', fallback: 'Total Today'),
              total.toString(),
              icon: Icons.calendar_today_rounded,
              accentColor: const Color(0xFF005691),
              width: cardWidth,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              context.tr('confirmed', fallback: 'Confirmed'),
              confirmed.toString(),
              icon: Icons.check_circle_rounded,
              accentColor: const Color(0xFF16A34A),
              width: cardWidth,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              context.tr('cancelled', fallback: 'Cancelled'),
              cancelled.toString(),
              icon: Icons.cancel_rounded,
              accentColor: const Color(0xFFDC2626),
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value, {
    required IconData icon,
    required Color accentColor,
    double? width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isMobile) {
    final searchBar = Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 20,
            color: AppTheme.getTextSecondaryColor(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _apptSearchController,
              style: TextStyle(
                color: AppTheme.getTextPrimaryColor(context),
                fontSize: 14,
              ),
              onChanged: (v) => setState(() {
                _searchQuery = v;
                _currentPage = 0;
              }),
              decoration: InputDecoration(
                hintText: context.tr('search_appointments', fallback: 'Search appointments by patient, doctor, or department...'),
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppTheme.getTextSecondaryColor(context),
                ),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 20, color: AppTheme.textSecondaryColor),
              onPressed: () {
                _apptSearchController.clear();
                setState(() {
                  _searchQuery = '';
                  _currentPage = 0;
                });
              },
            ),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          searchBar,
          CustomDropdownSearch(
            label: '',
            value: _selectedStatus,
            dropdownMap: {
              'All Status': context.tr('all_status', fallback: 'All Status'),
              'Confirmed': context.tr('status_confirmed', fallback: 'Confirmed'),
              'Waiting': context.tr('status_waiting', fallback: 'Waiting'),
              'In Consultation': context.tr('status_in_consultation', fallback: 'In Consultation'),
              'Completed': context.tr('status_completed', fallback: 'Completed'),
              'No Show': context.tr('status_no_show', fallback: 'No Show'),
              'Cancelled': context.tr('status_cancelled', fallback: 'Cancelled'),
            },
            height: 48,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedStatus = val;
                  _currentPage = 0;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.isDark(context) ? AppTheme.darkInputFillColor : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.getBorderColor(context)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppTheme.getTextSecondaryColor(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _filterDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) {
                        setState(() {
                          _filterDate = picked;
                          _currentPage = 0;
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _filterDate == null
                            ? 'Select Date'
                            : DateFormat('dd/MM/yyyy').format(_filterDate!),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_filterDate != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() {
                      _filterDate = null;
                      _currentPage = 0;
                    }),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        searchBar,
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              width: 180,
              child: CustomDropdownSearch(
                label: '',
                value: _selectedStatus,
                dropdownMap: {
                  'All Status': context.tr('all_status', fallback: 'All Status'),
                  'Confirmed': context.tr('status_confirmed', fallback: 'Confirmed'),
                  'Waiting': context.tr('status_waiting', fallback: 'Waiting'),
                  'In Consultation': context.tr('status_in_consultation', fallback: 'In Consultation'),
                  'Completed': context.tr('status_completed', fallback: 'Completed'),
                  'No Show': context.tr('status_no_show', fallback: 'No Show'),
                  'Cancelled': context.tr('status_cancelled', fallback: 'Cancelled'),
                },
                height: 48,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedStatus = val;
                      _currentPage = 0;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.isDark(context) ? AppTheme.darkInputFillColor : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.getBorderColor(context)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppTheme.getTextSecondaryColor(context),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _filterDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) {
                        setState(() {
                          _filterDate = picked;
                          _currentPage = 0;
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _filterDate == null
                            ? 'Select Date'
                            : DateFormat('dd/MM/yyyy').format(_filterDate!),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                  ),
                  if (_filterDate != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() {
                        _filterDate = null;
                        _currentPage = 0;
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppointmentsTable(bool isMobile) {
    final filteredAppts = _appointments.where((a) {
      if (a.status.toLowerCase() == 'admitted') {
        return false;
      }
      if (_selectedStatus != 'All Status') {
        final currentNormalized = a.status.toLowerCase().replaceAll('-', ' ').trim();
        final filterNormalized = _selectedStatus.toLowerCase().replaceAll('-', ' ').trim();
        if (currentNormalized != filterNormalized) {
          return false;
        }
      }
      if (_filterDate != null) {
        String apptDate = a.appointmentDate;
        if (apptDate.contains('T')) {
          apptDate = apptDate.split('T')[0];
        }
        String filterFormat1 = DateFormat('yyyy-MM-dd').format(_filterDate!);
        String filterFormat2 = DateFormat('dd/MM/yyyy').format(_filterDate!);
        if (apptDate != filterFormat1 && apptDate != filterFormat2) {
          return false;
        }
      }
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesQuery = a.patientName.toLowerCase().contains(query) ||
            (a.patientDisplayId?.toLowerCase().contains(query) ?? false) ||
            (a.patientPhone?.toLowerCase().contains(query) ?? false) ||
            a.doctorName.toLowerCase().contains(query) ||
            a.department.toLowerCase().contains(query);
        if (!matchesQuery) return false;
      }
      return true;
    }).toList();

    final totalAppointments = filteredAppts.length;
    final totalPages = (totalAppointments / _itemsPerPage).ceil();

    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
    if (_currentPage < 0) _currentPage = 0;

    final apps = filteredAppts
        .skip(_currentPage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    if (filteredAppts.isEmpty) {
      bool isToday = false;
      if (_filterDate != null) {
        DateTime now = DateTime.now();
        isToday =
            _filterDate!.year == now.year &&
            _filterDate!.month == now.month &&
            _filterDate!.day == now.day;
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                isToday ? 'No appointments today' : 'No appointments found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try changing the filters or book a new appointment',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    if (isMobile) {
      return Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: apps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final appt = apps[index];
              return _buildAppointmentCardMobile(appt);
            },
          ),
          if (totalPages > 1) ...[
            const SizedBox(height: 16),
            _buildPaginationControls(totalPages, true),
          ],
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.isDark(context) ? AppTheme.darkSurfaceColor : const Color(0xFFEDF2F7),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _buildTableHeader('S.No', flex: 1),
                _buildTableHeader('Time', flex: 2),
                _buildTableHeader('Date', flex: 2),
                _buildTableHeader('Patient', flex: 4),
                _buildTableHeader('Department', flex: 2),
                _buildTableHeader('Doctor', flex: 3),
                _buildTableHeader('Type', flex: 2),
                _buildTableHeader('Reason', flex: 3),
                _buildTableHeader('Status', flex: 2),
                _buildTableHeader('Actions', flex: 2, leftPadding: 16),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final appt = apps[index];
              final serialNo = (index + 1) + (_currentPage * _itemsPerPage);
              return Column(
                children: [
                  _buildAppointmentRow(appt, serialNo),
                  const Divider(height: 1),
                ],
              );
            },
          ),
          if (totalPages > 1) ...[
            _buildPaginationControls(totalPages, false),
          ],
        ],
      ),
    );
  }

  Widget _buildAppointmentCardMobile(AppointmentModel appt) {
    final statusColor = AppTheme.getStatusTextColor(appt.status);
    final statusBg = AppTheme.getStatusBgColor(appt.status);
    
    final bool hasVitals = appt.bloodPressureSystolic != null && appt.temperature != null;
    final apptDt = DateFormatter.toDateTime(appt.appointmentDate);
    final bool isFuture = apptDt != null &&
        DateTime(apptDt.year, apptDt.month, apptDt.day)
            .isAfter(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.getAvatarColors(appt.patientName)['bg'],
                      child: Text(
                        _getInitials(appt.patientName),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.getAvatarColors(appt.patientName)['text'],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TamilTransliterationHelper.translate(context, appt.patientName),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _formatDate(appt.appointmentDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getTranslatedStatus(appt.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Text(
                appt.appointmentTime,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 24),
              const Icon(
                Icons.medical_services_outlined,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Text.rich(
                TextSpan(
                  text: appt.doctorName,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                  children: [
                    if (appt.doctorDisplayId != null &&
                        appt.doctorDisplayId!.isNotEmpty)
                      TextSpan(
                        text: ' (${appt.doctorDisplayId})',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.business_outlined,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Text(
                _getTranslatedDepartment(appt.department),
                style: const TextStyle(fontSize: 13, color: Color(0xFF3B82F6)),
              ),
              const Spacer(),
              Text(
                _getTranslatedApptType(appt.appointmentType),
                style: TextStyle(
                  fontSize: 10,
                  color: appt.appointmentType == 'Emergency'
                      ? Colors.red
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (appt.isRescheduled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                context.tr('rescheduled', fallback: 'Rescheduled'),
                style: const TextStyle(
                  color: Color(0xFF9333EA),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openViewDetailsDialog(context, appt),
                      icon: const Icon(Icons.visibility, size: 12),
                      label: Text(context.tr('view_details', fallback: 'View Details'), style: const TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    if (appt.status == 'Confirmed') ...[
                      if (!hasVitals && !isFuture)
                        ElevatedButton.icon(
                          onPressed: () => _openVitalsEntryDialog(context, appt),
                          icon: const Icon(Icons.monitor_heart, size: 12, color: Colors.white),
                          label: Text(context.tr('add_vitals', fallback: 'Add Vitals'), style: const TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),

                      ElevatedButton(
                        onPressed: () async {
                          String? cancelReason;
                          await showDialog(
                            context: context,
                            builder: (dialogCtx) {
                              final ctrl = TextEditingController();
                              final formKey = GlobalKey<FormState>();
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.dangerColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.cancel_outlined,
                                        color: AppTheme.dangerColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Cancel Appointment',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                content: SizedBox(
                                  width: 400,
                                  child: Form(
                                    key: formKey,
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Are you sure you want to cancel the appointment for ${appt.patientName}?',
                                          style: const TextStyle(
                                            color: AppTheme.textSecondaryColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Reason for Cancellation *',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: AppTheme.textPrimaryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: ctrl,
                                          maxLines: 3,
                                          maxLength: 200,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                              RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]'),
                                            ),
                                            LengthLimitingTextInputFormatter(200),
                                          ],
                                          validator: (val) {
                                            final v = val?.trim() ?? '';
                                            if (v.isEmpty) {
                                              return 'Please enter a cancellation reason';
                                            }
                                            if (v.length < 3) {
                                              return 'Reason must be at least 3 characters';
                                            }
                                            if (v.length > 200) {
                                              return 'Reason cannot exceed 200 characters';
                                            }
                                            if (!RegExp(r'[a-zA-Z]').hasMatch(v)) {
                                              return 'Reason must contain alphabetic characters';
                                            }
                                            return null;
                                          },
                                          decoration: InputDecoration(
                                            hintText: 'e.g. Patient requested cancellation due to personal emergency',
                                            hintStyle: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textSecondaryColor,
                                            ),
                                            fillColor: const Color(0xFFF1F5F9),
                                            filled: true,
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: AppTheme.borderColor),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: AppTheme.borderColor),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                                            ),
                                            errorBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: AppTheme.dangerColor, width: 1.5),
                                            ),
                                            focusedErrorBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: AppTheme.dangerColor, width: 1.5),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                actions: [
                                  OutlinedButton(
                                    onPressed: () => Navigator.pop(dialogCtx),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.textSecondaryColor,
                                      side: const BorderSide(color: AppTheme.borderColor),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Keep Appointment'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (formKey.currentState!.validate()) {
                                        cancelReason = ctrl.text.trim();
                                        Navigator.pop(dialogCtx);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.dangerColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Cancel Appointment'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (cancelReason != null) {
                            try {
                              await _appointmentController.updateStatus(
                                appt.id!,
                                'Cancelled',
                                cancellationReason: cancelReason,
                              );
                              _fetchData();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else
                      const Text('-', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionLabel(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
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

  Widget _buildTableHeader(
    String label, {
    int flex = 1,
    double leftPadding = 0,
  }) {
    String translated = label;
    if (label == 'Time') {
      translated = context.tr('time', fallback: label);
    } else if (label == 'Date') {
      translated = context.tr('date', fallback: label);
    } else if (label == 'Patient') {
      translated = context.tr('patient_name', fallback: label);
    } else if (label == 'Department') {
      translated = context.tr('department', fallback: label);
    } else if (label == 'Doctor') {
      translated = context.tr('doctor', fallback: label);
    } else if (label == 'Type') {
      translated = context.tr('type', fallback: label);
    } else if (label == 'Reason') {
      translated = context.tr('reason', fallback: label);
    } else if (label == 'Status') {
      translated = context.tr('status', fallback: label);
    } else if (label == 'Actions') {
      translated = context.tr('actions', fallback: label);
    }

    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.only(left: leftPadding),
        child: Text(
          translated,
          style: TextStyle(
            color: AppTheme.isDark(context)
                ? AppTheme.darkTextSecondaryColor
                : const Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentRow(AppointmentModel appt, int serialNo) {
    final id = appt.id!;
    final time = appt.appointmentTime;
    final date = appt.appointmentDate;
    final patientName = appt.patientName;
    final patientInitials = _getInitials(appt.patientName);
    final patientIdText = appt.patientDisplayId?.isNotEmpty == true
        ? appt.patientDisplayId!
        : appt.patientId.toString();
    final doctorName = appt.doctorName;
    final doctorDisplayId = appt.doctorDisplayId;
    final type = appt.appointmentType;
    final department = appt.department;
    final reason = appt.reasonForVisit?.isNotEmpty == true ? appt.reasonForVisit! : 'N/A';
    final status = appt.status;
    final statusColor = AppTheme.getStatusTextColor(appt.status);
    final statusBg = AppTheme.getStatusBgColor(appt.status);
    final isRescheduled = appt.isRescheduled;
    final bool hasVitals = appt.bloodPressureSystolic != null && appt.temperature != null;
    final apptDt = DateFormatter.toDateTime(appt.appointmentDate);
    final bool isFuture = apptDt != null &&
        DateTime(apptDt.year, apptDt.month, apptDt.day)
            .isAfter(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

    final now = DateTime.now();
    bool isToday = false;
    try {
      final parts = date.split('/');
      if (parts.length == 3) {
        isToday = int.parse(parts[0]) == now.day &&
            int.parse(parts[1]) == now.month &&
            int.parse(parts[2]) == now.year;
      }
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '$serialNo',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4A5568),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    time,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isToday ? context.tr('today', fallback: 'Today') : _formatDate(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF475569),
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isRescheduled) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      context.tr('rescheduled', fallback: 'Resched'),
                      style: const TextStyle(
                        color: Color(0xFF9333EA),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.getAvatarColors(patientName)['bg'],
                    child: Text(
                      patientInitials,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.getAvatarColors(patientName)['text'],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        TamilTransliterationHelper.translate(context, patientName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        patientIdText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Text(
                _getTranslatedDepartment(department),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Icon(
                  Icons.medical_services_outlined,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          doctorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (doctorDisplayId != null && doctorDisplayId.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            doctorDisplayId,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Text(
                _getTranslatedApptType(type),
                style: TextStyle(
                  fontSize: 13,
                  color: type == 'Emergency'
                      ? Colors.red
                      : const Color(0xFF64748B),
                  fontWeight: type == 'Emergency'
                      ? FontWeight.bold
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Tooltip(
              message: reason,
              child: Text(
                reason,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getTranslatedStatus(status),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildActionLabel(
                    Icons.visibility_outlined,
                    context.tr('view', fallback: 'View'),
                    const Color(0xFF3182CE),
                    onTap: () => _openViewDetailsDialog(context, appt),
                  ),
                  if (status == 'Confirmed') ...[
                    if (!hasVitals && !isFuture) ...[
                      _buildActionLabel(
                        Icons.monitor_heart_outlined,
                        context.tr('add_vitals', fallback: 'Add Vitals'),
                        const Color(0xFF0F766E),
                        onTap: () => _openVitalsEntryDialog(context, appt),
                      ),
                    ],
                    _buildActionLabel(
                      Icons.cancel_outlined,
                      context.tr('cancel', fallback: 'Cancel'),
                      Colors.redAccent,
                      onTap: () async {
                        String? cancelReason;
                        await showDialog(
                          context: context,
                          builder: (dialogCtx) {
                            final ctrl = TextEditingController();
                            final formKey = GlobalKey<FormState>();
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.dangerColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.cancel_outlined,
                                      color: AppTheme.dangerColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Cancel Appointment',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              content: SizedBox(
                                width: 400,
                                child: Form(
                                  key: formKey,
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Are you sure you want to cancel the appointment for ${appt.patientName}?',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondaryColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Reason for Cancellation *',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppTheme.textPrimaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: ctrl,
                                        maxLines: 3,
                                        maxLength: 200,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]'),
                                          ),
                                          LengthLimitingTextInputFormatter(200),
                                        ],
                                        validator: (val) {
                                          final v = val?.trim() ?? '';
                                          if (v.isEmpty) {
                                            return 'Please enter a cancellation reason';
                                          }
                                          if (v.length < 3) {
                                            return 'Reason must be at least 3 characters';
                                          }
                                          if (v.length > 200) {
                                            return 'Reason cannot exceed 200 characters';
                                          }
                                          if (!RegExp(r'[a-zA-Z]').hasMatch(v)) {
                                            return 'Reason must contain alphabetic characters';
                                          }
                                          return null;
                                        },
                                        decoration: InputDecoration(
                                          hintText: 'e.g. Patient requested cancellation due to personal emergency',
                                          hintStyle: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                          fillColor: const Color(0xFFF1F5F9),
                                          filled: true,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: AppTheme.borderColor),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: AppTheme.borderColor),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: AppTheme.dangerColor, width: 1.5),
                                          ),
                                          focusedErrorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: AppTheme.dangerColor, width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              actions: [
                                OutlinedButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.textSecondaryColor,
                                    side: const BorderSide(color: AppTheme.borderColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Keep Appointment'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    if (formKey.currentState!.validate()) {
                                      cancelReason = ctrl.text.trim();
                                      Navigator.pop(dialogCtx);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.dangerColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Cancel Appointment'),
                                ),
                              ],
                            );
                          },
                        );
                        if (cancelReason != null) {
                          try {
                            await _appointmentController.updateStatus(
                              id,
                              'Cancelled',
                              cancellationReason: cancelReason,
                            );
                            _fetchData();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                          }
                        }
                      },
                    ),
                  ] else
                    const Text('-', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(int totalPages, bool isMobile) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Page ${_currentPage + 1} of $totalPages',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(80, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(
                color: _currentPage > 0
                    ? AppTheme.primaryColor
                    : AppTheme.borderColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.chevron_left, size: 18),
                Text('Prev'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _currentPage < totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(80, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(
                color: _currentPage < totalPages - 1
                    ? AppTheme.primaryColor
                    : AppTheme.borderColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Next'),
                Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
