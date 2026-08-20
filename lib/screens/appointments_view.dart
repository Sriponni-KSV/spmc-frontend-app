import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/routes/route_constants.dart';
import '../widgets/custom_dropdown_search.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../models/patient_model.dart';
import '../models/user_model.dart';
import '../models/appointment_model.dart';
import '../controllers/patient_controller.dart';
import '../controllers/admin_controller.dart';
import '../controllers/appointment_controller.dart';
import '../widgets/appointment_details_dialog.dart';
import 'mocdoc_appointments_view.dart';

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

  void _updateAvailableSlots() {
    if (_selectedDoctor == null || _bookingDate == null) {
      setState(() {
        _availableSlots = [];
      });
      return;
    }

    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = weekDays[_bookingDate!.weekday - 1];

    // 1. Check if day is available
    if (_selectedDoctor!.availableDays == null ||
        !_selectedDoctor!.availableDays!.contains(dayName)) {
      setState(() => _availableSlots = []);
      return;
    }

    // 2. Check for weekly off
    if (_selectedDoctor!.weeklyOffDays != null &&
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
    if (_selectedDoctor == null) return true; // Allow all days if no doctor is selected yet, or we could return false to force doctor selection. Returning true for better UX before validation.

    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = weekDays[date.weekday - 1];
    final dateStr = DateFormat('dd/MM/yyyy').format(date);

    bool isAvailable = false;
    if (_selectedDoctor!.availableDays != null &&
        _selectedDoctor!.availableDays!.contains(dayName)) {
      isAvailable = true;
    }

    if (_selectedDoctor!.weeklyOffDays != null &&
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

    final dateStr = DateFormat('dd/MM/yyyy').format(_bookingDate!);

    return _availableSlots.where((slot) {
      // 1. Check if already booked
      bool isBooked = _appointments.any(
        (a) =>
            a.doctorName == _selectedDoctor!.fullname &&
            a.appointmentDate == dateStr &&
            a.appointmentTime == slot &&
            a.status != 'Cancelled',
      );

      if (isBooked) return false;

      // 2. If today, filter out past slots
      if (isToday) {
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back, size: 16, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text(
                'Back to Appointments',
                style: TextStyle(
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
        const Text(
          'Book Appointment',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Schedule a new appointment for a patient',
          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
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
                      _buildFieldLabel('Select Patient *'),
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
                  title: 'Patient Vitals',
                  headerExtra: TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Collect vitals',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Blood Pressure'),
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
                                _buildFieldLabel('Sugar Level'),
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
                                _buildFieldLabel('Temperature'),
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
                  title: 'Visit Details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Appointment Type *'),
                      _buildDropdown<String>(
                        hint: '',
                        value: _selectedApptType,
                        items: _apptTypes,
                        itemLabel: (s) => s,
                        onChanged: (val) =>
                            setState(() => _selectedApptType = val!),
                      ),
                      const SizedBox(height: 16),
                      _buildFieldLabel('Reason *'),
                      _buildTextField(
                        controller: _reasonController,
                        hint: 'e.g. Regular check-up, fever, etc.',
                        isNumeric: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildFormCard(
                  title: 'Department & Doctor',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Department *'),
                      _buildDropdown<String>(
                        hint: '',
                        value: _selectedDept,
                        items: _departments,
                        itemLabel: (s) => s,
                        onChanged: (val) => setState(() {
                          _selectedDept = val;
                          _selectedDoctor = null;
                        }),
                      ),
                      if (_selectedDept != null) ...[
                        const SizedBox(height: 24),
                        _buildFieldLabel('Select Doctor *'),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 76,
                          child:
                              _doctors
                                  .where(
                                    (d) => d.specialization == _selectedDept,
                                  )
                                  .isEmpty
                              ? const Center(
                                  child: Text(
                                    'No doctors available',
                                    style: TextStyle(
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
                                    final isSelected =
                                        _selectedDoctor?.fullname ==
                                        doc.fullname;
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
                  title: 'Date & Time',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Appointment Date *'),
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
                        _buildFieldLabel('Available Time Slots *'),
                        const SizedBox(height: 8),
                        () {
                          final filteredSlots = _getFilteredTimeSlots();
                          if (filteredSlots.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'No more slots available for today',
                                  style: TextStyle(
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
                      const Text(
                        'Appointment Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_selectedPatient != null)
                        _buildSummaryItem(
                          Icons.person_outline,
                          'Patient',
                          _selectedPatient!.name,
                        ),

                      if (_selectedDoctor != null)
                        _buildSummaryItem(
                          Icons.medical_services_outlined,
                          'Doctor',
                          _selectedDoctor!.fullname,
                          subtitle: _selectedDept,
                        ),

                      if (_bookingDate != null)
                        _buildSummaryItem(
                          Icons.calendar_month_outlined,
                          'Date',
                          DateFormat('dd/MM/yyyy').format(_bookingDate!),
                        ),

                      if (_selectedTime != null)
                        _buildSummaryItem(
                          Icons.access_time,
                          'Time',
                          _selectedTime!,
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
                                    const SnackBar(
                                      content: Text(
                                        'Appointment Booked Successfully!',
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Book Appointment',
                              style: TextStyle(fontWeight: FontWeight.bold),
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
                                _buildFieldLabel('Select Patient *'),
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
                            title: 'Patient Vitals',
                            headerExtra: TextButton(
                              onPressed: () {},
                              child: const Text(
                                'Collect vitals during booking',
                                style: TextStyle(
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
                                      _buildFieldLabel('Blood Pressure'),
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
                                      _buildFieldLabel('Sugar Level'),
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
                                      _buildFieldLabel('Temperature'),
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
                            title: 'Visit Details',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Appointment Type *'),
                                _buildDropdown<String>(
                                  hint: '',
                                  value: _selectedApptType,
                                  items: _apptTypes,
                                  itemLabel: (s) => s,
                                  onChanged: (val) =>
                                      setState(() => _selectedApptType = val!),
                                ),
                                const SizedBox(height: 16),
                                _buildFieldLabel('Reason *'),
                                _buildTextField(
                                  controller: _reasonController,
                                  hint: 'e.g. Regular check-up, fever, etc.',
                                  isNumeric: false,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildFormCard(
                            title: 'Department & Doctor',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Department *'),
                                _buildDropdown<String>(
                                  hint: '',
                                  value: _selectedDept,
                                  items: _departments,
                                  itemLabel: (s) => s,
                                  onChanged: (val) => setState(() {
                                    _selectedDept = val;
                                    _selectedDoctor = null;
                                  }),
                                ),
                                if (_selectedDept != null) ...[
                                  const SizedBox(height: 24),
                                  _buildFieldLabel('Select Doctor *'),
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
                                        ? const Center(
                                            child: Text(
                                              'No doctors available in this department',
                                              style: TextStyle(
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
                                              final isSelected =
                                                  _selectedDoctor?.fullname ==
                                                  doc.fullname;
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
                            title: 'Date & Time',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Appointment Date *'),
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
                                  _buildFieldLabel('Available Time Slots *'),
                                  const SizedBox(height: 8),
                                  () {
                                    final filteredSlots =
                                        _getFilteredTimeSlots();
                                    if (_selectedDoctor == null) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 20,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Please select a doctor to see available time slots',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    if (filteredSlots.isEmpty) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 20,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'No more slots available for today',
                                            style: TextStyle(
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
                            const Text(
                              'Appointment Summary',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),

                            if (_selectedPatient != null)
                              _buildSummaryItem(
                                Icons.person_outline,
                                'Patient',
                                _selectedPatient!.name,
                              ),

                            if (_selectedDoctor != null)
                              _buildSummaryItem(
                                Icons.medical_services_outlined,
                                'Doctor',
                                _selectedDoctor!.fullname,
                                subtitle: _selectedDept,
                              ),

                            if (_bookingDate != null)
                              _buildSummaryItem(
                                Icons.calendar_month_outlined,
                                'Date',
                                DateFormat(
                                  'dd/MM/yyyy',
                                ).format(_bookingDate!),
                              ),

                            if (_selectedTime != null)
                              _buildSummaryItem(
                                Icons.access_time,
                                'Time',
                                _selectedTime!,
                              ),

                            _buildSummaryItem(
                              Icons.info_outline,
                              'Type',
                              _selectedApptType,
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
                                          const SnackBar(
                                            content: Text(
                                              'Appointment Booked Successfully!',
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
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Book Appointment',
                                    style: TextStyle(
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
                  FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                  LengthLimitingTextInputFormatter(100),
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
      {'key': 'Table', 'label': 'Table View'},
      {'key': 'Hospital', 'label': 'Hospital View'},
      {'key': 'Doctor', 'label': 'Doctor View'},
      {'key': 'Both', 'label': 'Both View'},
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
          const Text(
            'Appointments',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage and schedule patient appointments',
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildViewSwitcher(),
          ),
          const SizedBox(height: 12),
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
            label: const Text('Book Appointment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
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
                const Text(
                  'Appointments',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage and schedule patient appointments',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
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
              label: const Text('Book Appointment'),
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
        double cardWidth = (constraints.maxWidth - (16 * 2)) / 3;
        if (isMobile) {
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildStatCard(
                'Total Today',
                total.toString(),
                icon: Icons.calendar_today_rounded,
                accentColor: const Color(0xFF005691),
              ),
              _buildStatCard(
                'Confirmed',
                confirmed.toString(),
                icon: Icons.check_circle_rounded,
                accentColor: const Color(0xFF16A34A),
              ),
              _buildStatCard(
                'Cancelled',
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
              'Total Today',
              total.toString(),
              icon: Icons.calendar_today_rounded,
              accentColor: const Color(0xFF005691),
              width: cardWidth,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Confirmed',
              confirmed.toString(),
              icon: Icons.check_circle_rounded,
              accentColor: const Color(0xFF16A34A),
              width: cardWidth,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Cancelled',
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            size: 20,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _apptSearchController,
              onChanged: (v) => setState(() {
                _searchQuery = v;
                _currentPage = 0;
              }),
              decoration: const InputDecoration(
                hintText: 'Search appointments by patient, doctor, or department...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
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
            dropdownItems: const ['All Status', 'Confirmed', 'Cancelled'],
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
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Color(0xFF64748B),
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
                        style: const TextStyle(fontSize: 14),
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
                dropdownItems: const ['All Status', 'Confirmed', 'Cancelled'],
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
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Color(0xFF64748B),
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
                        style: const TextStyle(fontSize: 14),
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
      if (_selectedStatus != 'All Status' && a.status != _selectedStatus) {
        return false;
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
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
                        appt.patientName,
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
                  appt.status,
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
                appt.department,
                style: const TextStyle(fontSize: 13, color: Color(0xFF3B82F6)),
              ),
              const Spacer(),
              Text(
                appt.appointmentType,
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
              child: const Text(
                'Rescheduled',
                style: TextStyle(
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
                      label: const Text('View Details', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    if (appt.status == 'Confirmed') ...[
                      if (!hasVitals)
                        ElevatedButton.icon(
                          onPressed: () => _openVitalsEntryDialog(context, appt),
                          icon: const Icon(Icons.monitor_heart, size: 12, color: Colors.white),
                          label: const Text('Add Vitals', style: TextStyle(fontSize: 11)),
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
                            builder: (context) {
                              final ctrl = TextEditingController();
                              return AlertDialog(
                                title: const Text('Cancel Appointment'),
                                content: TextField(
                                  controller: ctrl,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter cancellation reason (required)',
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (ctrl.text.trim().isNotEmpty) {
                                        cancelReason = ctrl.text.trim();
                                        Navigator.pop(context);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Reason is required')),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.only(left: leftPadding),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
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
                    isToday ? 'Today' : _formatDate(date),
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
                    child: const Text(
                      'Resched',
                      style: TextStyle(
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
                        patientName,
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
                department,
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
                type,
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
                status,
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
                    'View',
                    const Color(0xFF3182CE),
                    onTap: () => _openViewDetailsDialog(context, appt),
                  ),
                  if (status == 'Confirmed') ...[
                    if (!hasVitals) ...[
                      _buildActionLabel(
                        Icons.monitor_heart_outlined,
                        'Add Vitals',
                        const Color(0xFF0F766E),
                        onTap: () => _openVitalsEntryDialog(context, appt),
                      ),
                    ],
                    _buildActionLabel(
                      Icons.cancel_outlined,
                      'Cancel',
                      Colors.redAccent,
                      onTap: () async {
                        String? cancelReason;
                        await showDialog(
                          context: context,
                          builder: (context) {
                            final ctrl = TextEditingController();
                            return AlertDialog(
                              title: const Text('Cancel Appointment'),
                              content: TextField(
                                controller: ctrl,
                                decoration: const InputDecoration(
                                  hintText: 'Enter cancellation reason (required)',
                                ),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
                                ElevatedButton(
                                  onPressed: () {
                                    if (ctrl.text.trim().isNotEmpty) {
                                      cancelReason = ctrl.text.trim();
                                      Navigator.pop(context);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Reason is required')),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  child: const Text('Cancel'),
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
