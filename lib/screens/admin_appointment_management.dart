import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/custom_dropdown_search.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../utils/date_formatter.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../controllers/appointment_controller.dart';
import '../controllers/admin_controller.dart';
import '../providers/auth_provider.dart';
import '../widgets/appointment_details_dialog.dart';
import '../utils/unsaved_changes_helper.dart';
import '../utils/app_localizations.dart';

class AdminAppointmentManagement extends StatefulWidget {
  const AdminAppointmentManagement({Key? key}) : super(key: key);

  @override
  State<AdminAppointmentManagement> createState() =>
      _AdminAppointmentManagementState();
}

class _AdminAppointmentManagementState
    extends State<AdminAppointmentManagement> {
  final AppointmentController _apptCtrl = AppointmentController();
  final AdminController _adminCtrl = AdminController();

  List<AppointmentModel> _appointments = [];
  List<UserModel> _doctors = [];
  List<String> _departments = [];
  bool _isLoading = false;
  String? _errorMsg;

  // Filter state
  DateTime? _filterDate;
  String? _filterDoctor;
  String? _filterDepartment;
  String _filterStatus = 'All Status';
  String _searchQuery = '';
  bool _isFilterVisible = false;
  int _currentPage = 0;
  final int _itemsPerPage = 10;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statusOptions = [
    'All Status',
    'Confirmed',
    'Waiting',
    'In Consultation',
    'Completed',
    'No Show',
    'Cancelled',
  ];

  final ScrollController _vScroll = ScrollController();
  final ScrollController _hScroll = ScrollController();

  DateTime _parseTime(String timeStr) {
    try {
      final clean = timeStr.trim();
      final timeParts = clean.split(' ');
      final hms = timeParts[0].split(':');
      int hour = int.parse(hms[0]);
      int minute = hms.length > 1 ? int.parse(hms[1]) : 0;
      if (timeParts.length > 1) {
        if (timeParts[1].toUpperCase() == 'PM' && hour < 12) hour += 12;
        if (timeParts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
      }
      return DateTime(2026, 1, 1, hour, minute);
    } catch (_) {
      return DateTime(2026, 1, 1, 9, 0);
    }
  }

  String _cleanDoctorName(String? name) {
    if (name == null) return '';
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'^dr\.?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\s\u00A0]+'), ' ')
        .trim();
  }

  bool _isSameDoctor(String? d1, String? d2) {
    if (d1 == null || d2 == null) return false;
    final c1 = _cleanDoctorName(d1);
    final c2 = _cleanDoctorName(d2);
    if (c1.isEmpty || c2.isEmpty) return false;
    if (c1 == c2) return true;
    return c1.contains(c2) || c2.contains(c1);
  }

  bool _isSameDate(dynamic date1, dynamic date2) {
    final d1 = DateFormatter.toDateTime(date1);
    final d2 = DateFormatter.toDateTime(date2);
    if (d1 == null || d2 == null) return false;
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _normalizeTime(String timeStr) {
    String clean = timeStr.trim();
    if (clean.isEmpty) return '';
    clean = clean.replaceAll(RegExp(r'[\s\u00A0]+'), ' ');
    final matchAmPm = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AP]M)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (matchAmPm != null) {
      int hour = int.parse(matchAmPm.group(1)!);
      String min = matchAmPm.group(2)!;
      String period = matchAmPm.group(3)!.toUpperCase();
      if (hour == 0) hour = 12;
      return '${hour.toString().padLeft(2, '0')}:$min $period';
    }
    final match24 = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(clean);
    if (match24 != null) {
      int hour = int.parse(match24.group(1)!);
      String min = match24.group(2)!;
      String period = hour >= 12 ? 'PM' : 'AM';
      int h12 = hour % 12;
      if (h12 == 0) h12 = 12;
      return '${h12.toString().padLeft(2, '0')}:$min $period';
    }
    try {
      if (clean.toUpperCase().contains('AM') ||
          clean.toUpperCase().contains('PM')) {
        DateTime dt = DateFormat('h:mm a').parse(clean);
        return DateFormat('hh:mm a').format(dt);
      } else {
        DateTime dt = DateFormat('HH:mm').parse(clean);
        return DateFormat('hh:mm a').format(dt);
      }
    } catch (_) {
      return clean;
    }
  }

  List<String> _generateDefaultSlots() {
    List<String> slots = [];
    // Morning Session: 09:00 AM - 01:00 PM
    DateTime startM = DateTime(2026, 1, 1, 9, 0);
    DateTime endM = DateTime(2026, 1, 1, 13, 0);
    while (startM.isBefore(endM)) {
      slots.add(DateFormat('hh:mm a').format(startM));
      startM = startM.add(const Duration(minutes: 30));
    }
    // Afternoon Session: 02:00 PM - 05:00 PM
    DateTime startA = DateTime(2026, 1, 1, 14, 0);
    DateTime endA = DateTime(2026, 1, 1, 17, 0);
    while (startA.isBefore(endA)) {
      slots.add(DateFormat('hh:mm a').format(startA));
      startA = startA.add(const Duration(minutes: 30));
    }
    return slots;
  }

  List<String> _generateSlotsForDoctor(UserModel? doctor) {
    if (doctor == null ||
        doctor.slotStartTime == null ||
        doctor.slotStartTime!.trim().isEmpty ||
        doctor.slotEndTime == null ||
        doctor.slotEndTime!.trim().isEmpty) {
      return _generateDefaultSlots();
    }

    int duration = 30;
    if (doctor.slotDuration != null && doctor.slotDuration!.trim().isNotEmpty) {
      final digits = RegExp(r'\d+').firstMatch(doctor.slotDuration!)?.group(0);
      if (digits != null) {
        duration = int.tryParse(digits) ?? 30;
      }
    }
    if (duration <= 0) duration = 30;

    try {
      DateTime start = _parseTime(doctor.slotStartTime!);
      DateTime end = _parseTime(doctor.slotEndTime!);

      List<String> slots = [];
      DateTime current = start;
      while (current.isBefore(end)) {
        slots.add(DateFormat('hh:mm a').format(current));
        current = current.add(Duration(minutes: duration));
      }
      if (slots.isEmpty) {
        return _generateDefaultSlots();
      }
      return slots;
    } catch (e) {
      return _generateDefaultSlots();
    }
  }

  List<String> _getFilteredTimeSlots({
    required DateTime? date,
    required String? doctorName,
    required Set<String> occupiedSlots,
    String? currentSelectedTime,
  }) {
    if (date == null) return [];
    UserModel? doctor;
    if (doctorName != null && doctorName.trim().isNotEmpty) {
      try {
        doctor = _doctors.firstWhere(
          (d) => _isSameDoctor(d.fullname, doctorName),
        );
      } catch (_) {}
    }
    if (doctor == null) return [];

    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = weekDays[date.weekday - 1];
    final dateStr = DateFormat('dd/MM/yyyy').format(date);

    bool isAvailable = false;
    if (doctor.availableDays == null ||
        doctor.availableDays!.isEmpty ||
        doctor.availableDays!.contains(dayName)) {
      isAvailable = true;
    }

    if (doctor.weeklyOffDays != null &&
        doctor.weeklyOffDays!.contains(dayName)) {
      isAvailable = false;
    }

    if (doctor.specificLeaveDates != null &&
        doctor.specificLeaveDates!.contains(dateStr)) {
      isAvailable = false;
    }

    if (!isAvailable) {
      return [];
    }

    // Display all available time slots configured for the doctor on this date
    return _generateSlotsForDoctor(doctor);
  }

  @override
  void initState() {
    super.initState();
    UnsavedChangesHelper.setUnsavedChanges(true);
    _loadData();
  }

  @override
  void dispose() {
    UnsavedChangesHelper.setUnsavedChanges(false);
    _vScroll.dispose();
    _hScroll.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final String? dateStr = _filterDate != null
          ? DateFormat('yyyy-MM-dd').format(_filterDate!)
          : null;
      final results = await Future.wait([
        _apptCtrl.fetchAdminAppointments(
          date: dateStr,
          doctor: _filterDoctor,
          status: (_filterStatus == 'All' || _filterStatus == 'All Status')
              ? null
              : _filterStatus,
          department: _filterDepartment,
        ),
        _adminCtrl.fetchStaff(role: 'Doctor'),
        _adminCtrl.fetchSpecializations(),
      ]);
      if (!mounted) return;
      setState(() {
        _appointments = results[0] as List<AppointmentModel>;
        final fetchedDoctors = results[1] as List<UserModel>;
        fetchedDoctors.sort((a, b) => a.fullname.compareTo(b.fullname));
        _doctors = fetchedDoctors;
        final specs = results[2] as List<dynamic>;
        _departments = specs.map((e) => e['name'].toString()).toList();
        _departments.sort(); // Also sort departments alphabetically
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<AppointmentModel> get _filteredAppointments {
    final list = _appointments.where((a) => a.status.toLowerCase() != 'admitted').toList();
    if (_searchQuery.trim().isEmpty) return list;
    final query = _searchQuery.toLowerCase();
    return list.where((a) {
      return a.patientName.toLowerCase().contains(query) ||
          (a.patientDisplayId?.toLowerCase().contains(query) ?? false) ||
          (a.patientPhone?.toLowerCase().contains(query) ?? false) ||
          a.doctorName.toLowerCase().contains(query);
    }).toList();
  }

  Color _statusColor(String status) {
    return AppTheme.getStatusTextColor(status);
  }

  void _showOverrideDialog(AppointmentModel appt, {required String mode}) {
    if (mode == 'view') {
      showDialog(
        context: context,
        builder: (context) => AppointmentDetailsDialog(
          appointment: appt,
          editVitalsOnly: false,
          onRefresh: () {
            _loadData();
          },
        ),
      );
      return;
    }
    // mode: 'edit' | 'cancel' | 'reschedule' | 'view' | 'reopen'
    final bool isCompleted = appt.status == 'Completed';
    if (isCompleted && mode == 'reschedule') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completed appointments cannot be rescheduled.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final reasonCtrl = TextEditingController();
    String? selectedStatus = appt.status;
    String? selectedDoctor = appt.doctorName;
    try {
      final matchedDoc = _doctors.firstWhere(
        (d) => _isSameDoctor(d.fullname, selectedDoctor),
      );
      selectedDoctor = matchedDoc.fullname;
    } catch (_) {}
    DateTime? newDate;
    try {
      newDate = DateFormatter.toDateTime(appt.appointmentDate);
    } catch (e) {
      newDate = DateTime.now();
    }
    String? newTime = appt.appointmentTime;
    String? patientName = appt.patientName;
    String? department = appt.department;
    String? appointmentType = appt.appointmentType;
    bool isSaving = false;
    String? reasonError;
    String? validateReason(String? val) {
      if (val == null || val.trim().isEmpty) {
        return 'Override reason is required.';
      }
      final text = val.trim();
      if (text.length < 3) {
        return 'Override reason must be at least 3 characters.';
      }
      if (text.length > 100) {
        return 'Override reason cannot exceed 100 characters.';
      }
      if (!RegExp(r'[a-zA-Z]').hasMatch(text)) {
        return 'Override reason must contain at least one letter.';
      }
      if (!RegExp(r'^[a-zA-Z0-9\s.,/#\-\(\):;]+$').hasMatch(text)) {
        return 'Override reason contains invalid characters.';
      }
      return null;
    }
    Set<String> computeOccupiedFromMemory(DateTime? date, String? doctor) {
      if (date == null) return {};
      final Set<String> occupied = {};
      for (final a in _appointments) {
        if (a.id != null && a.id == appt.id) continue;
        if (a.status.toLowerCase() == 'cancelled') continue;
        if (doctor != null && doctor.trim().isNotEmpty) {
          if (!_isSameDoctor(a.doctorName, doctor)) continue;
        }
        if (_isSameDate(a.appointmentDate, date)) {
          occupied.add(_normalizeTime(a.appointmentTime));
        }
      }
      return occupied;
    }

    Set<String> occupiedSlots = computeOccupiedFromMemory(newDate, selectedDoctor);
    bool isLoadingSlots = false;
    String? slotConflictError;
    bool hasInitializedSlots = false;

    Future<void> loadOccupiedSlots(
      DateTime? date,
      String? doctor,
      void Function(void Function()) updateState,
    ) async {
      if (date == null) {
        updateState(() {
          occupiedSlots = {};
          isLoadingSlots = false;
        });
        return;
      }
      final initialOccupied = computeOccupiedFromMemory(date, doctor);
      updateState(() {
        occupiedSlots = initialOccupied;
        isLoadingSlots = true;
        slotConflictError = null;
      });
      try {
        final dateDb = DateFormat('yyyy-MM-dd').format(date);
        final appts = await _apptCtrl.fetchAdminAppointments(date: dateDb);
        final Set<String> occupied = Set<String>.from(initialOccupied);
        for (final a in appts) {
          if (a.id != null && a.id == appt.id) continue;
          if (a.status.toLowerCase() == 'cancelled') continue;
          if (doctor != null && doctor.trim().isNotEmpty) {
            if (!_isSameDoctor(a.doctorName, doctor)) {
              continue;
            }
          }
          if (_isSameDate(a.appointmentDate, date)) {
            occupied.add(_normalizeTime(a.appointmentTime));
          }
        }
        updateState(() {
          occupiedSlots = occupied;
          isLoadingSlots = false;
          if (newTime != null &&
              occupiedSlots.contains(_normalizeTime(newTime!))) {
            newTime = null;
          }
        });
      } catch (e) {
        updateState(() {
          occupiedSlots = initialOccupied;
          isLoadingSlots = false;
        });
      }
    }

    List<String> availableStatuses = [
      'Confirmed',
      'Waiting',
      'In Consultation',
      'Completed',
      'Cancelled',
    ];
    if (appt.status == 'Completed') {
      availableStatuses = ['Confirmed', 'Completed'];
    } else if (appt.status == 'Cancelled') {
      availableStatuses = ['Confirmed', 'Cancelled'];
    } else if (appt.status == 'No-Show') {
      availableStatuses = ['Confirmed', 'Completed'];
    }

    final List<String> apptTypes = [
      'Routine',
      'Follow Up',
      'New Visit',
      'Scheduled',
      'Emergency',
    ];

    // All eligible doctors (active, non-deleted doctors)
    List<String> getEligibleDoctors() {
      final List<String> list = _doctors
          .where((d) => d.status.toLowerCase() != 'inactive' && !d.isDeleted)
          .map((d) => d.fullname)
          .where((name) => name.trim().isNotEmpty)
          .toSet()
          .toList();
      if (list.isEmpty) {
        list.addAll(
          _doctors
              .map((d) => d.fullname)
              .where((name) => name.trim().isNotEmpty)
              .toSet(),
        );
      }
      if (list.isEmpty) {
        list.addAll(
          _appointments
              .map((a) => a.doctorName)
              .where((name) => name.trim().isNotEmpty)
              .toSet(),
        );
      }
      list.sort((a, b) => a.compareTo(b));
      if (selectedDoctor != null && selectedDoctor!.trim().isNotEmpty) {
        final existingMatch = list.firstWhere(
          (doc) => _isSameDoctor(doc, selectedDoctor),
          orElse: () => '',
        );
        if (existingMatch.isEmpty) {
          list.insert(0, selectedDoctor!);
        } else if (selectedDoctor != existingMatch) {
          selectedDoctor = existingMatch;
        }
      }
      return list;
    }

    if (_doctors.isEmpty) {
      _adminCtrl.fetchStaff(role: 'Doctor').then((docs) {
        if (docs.isNotEmpty && mounted) {
          setState(() {
            _doctors = docs;
          });
        }
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          if (!hasInitializedSlots &&
              (mode == 'edit' || mode == 'reschedule')) {
            hasInitializedSlots = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              loadOccupiedSlots(newDate, selectedDoctor, setS);
            });
          }

          Widget buildField(String label, Widget child) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 6),
              child,
              const SizedBox(height: 14),
            ],
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    mode == 'view'
                        ? Icons.visibility_outlined
                        : mode == 'cancel'
                        ? Icons.cancel_outlined
                        : mode == 'reschedule'
                        ? Icons.schedule_outlined
                        : mode == 'reopen'
                        ? Icons.restore_outlined
                        : Icons.edit_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  mode == 'view'
                      ? 'Appointment Detail'
                      : mode == 'cancel'
                      ? 'Cancel Appointment'
                      : mode == 'reschedule'
                      ? 'Reschedule Appointment'
                      : mode == 'reopen'
                      ? 'Change Status'
                      : 'Edit Appointment',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width > 520
                  ? 480
                  : MediaQuery.of(ctx).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        children: [
                          _infoRow(
                            'Patient',
                            appt.patientName,
                            Icons.person_outline,
                          ),
                          _infoRow(
                            'Doctor',
                            appt.doctorName,
                            Icons.medical_services_outlined,
                          ),
                          _infoRow(
                            'Date',
                            appt.appointmentDate,
                            Icons.calendar_today_outlined,
                          ),
                          _infoRow(
                            'Time',
                            appt.appointmentTime,
                            Icons.access_time_outlined,
                          ),
                          _infoRow('Status', appt.status, Icons.info_outline),
                          if (appt.reasonForVisit != null)
                            _infoRow(
                              'Reason',
                              appt.reasonForVisit!,
                              Icons.notes_outlined,
                            ),
                        ],
                      ),
                    ),

                    if (mode == 'view' && appt.overrideReason != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDBA74)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.shield_outlined,
                                  size: 14,
                                  color: Color(0xFFF97316),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Admin Correction by ${appt.overrideByName ?? "Unknown"}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Reason: ${appt.overrideReason}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (mode != 'view') ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        'Admin Correction',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Status field (edit/cancel/reopen)
                      if (mode == 'edit' ||
                          mode == 'cancel' ||
                          mode == 'reopen') ...[
                        buildField(
                          'Force Status Change',
                          CustomDropdownSearch(
                            label: '',
                            value: selectedStatus,
                            dropdownItems: availableStatuses,
                            onChanged: (v) {
                              if (v != null) {
                                setS(() => selectedStatus = v);
                              }
                            },
                          ),
                        ),
                      ],

                      // Appointment type & doctor (edit only)
                      if (mode == 'edit') ...[
                        buildField(
                          'Appointment Type',
                          CustomDropdownSearch(
                            label: '',
                            value: apptTypes.contains(appointmentType)
                                ? appointmentType
                                : null,
                            dropdownItems: apptTypes,
                            onChanged: (v) => setS(() => appointmentType = v),
                          ),
                        ),
                        Builder(
                          builder: (context) {
                            final eligibleDoctors = getEligibleDoctors();
                            return buildField(
                              'Reassign Doctor',
                              CustomDropdownSearch(
                                label: '',
                                hint: 'Select doctor',
                                value: eligibleDoctors.contains(selectedDoctor)
                                    ? selectedDoctor
                                    : null,
                                dropdownItems: eligibleDoctors,
                                onChanged: (v) {
                                  if (v == null) return;
                                  setS(() {
                                    selectedDoctor = v;
                                    newTime = null;
                                    try {
                                      final docModel = _doctors.firstWhere(
                                        (d) => _isSameDoctor(d.fullname, v),
                                      );
                                      if (docModel.specialization != null &&
                                          docModel.specialization!.trim().isNotEmpty) {
                                        department = docModel.specialization;
                                      }
                                    } catch (_) {}
                                    occupiedSlots = computeOccupiedFromMemory(newDate, v);
                                  });
                                  loadOccupiedSlots(newDate, v, setS);
                                },
                              ),
                            );
                          },
                        ),
                      ],

                      // Date/time (edit/reschedule)
                      if (isCompleted) ...[
                        buildField(
                          'Appointment Schedule',
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.lock_outline,
                                  size: 16,
                                  color: AppTheme.textSecondaryColor,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Completed appointments cannot be rescheduled.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (mode == 'edit' || mode == 'reschedule') ...[
                        buildField(
                          'New Date',
                          InkWell(
                            onTap: () async {
                              DateTime initDate = newDate ?? DateTime.now();
                              final now = DateTime.now();
                              final today = DateTime(
                                now.year,
                                now.month,
                                now.day,
                              );
                              if (initDate.isBefore(today)) initDate = today;

                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: initDate,
                                firstDate: today,
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (d != null) {
                                setS(() {
                                  newDate = d;
                                  newTime = null;
                                  occupiedSlots = computeOccupiedFromMemory(d, selectedDoctor);
                                });
                                loadOccupiedSlots(d, selectedDoctor, setS);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.borderColor),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    newDate != null
                                        ? DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(newDate!)
                                        : 'Pick a date',
                                    style: TextStyle(
                                      color: newDate != null
                                          ? AppTheme.textPrimaryColor
                                          : AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        buildField(
                          'New Time Slot',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isLoadingSlots) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: const [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Checking doctor schedule & booked slots...',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Builder(
                                builder: (context) {
                                  final availableSlots = _getFilteredTimeSlots(
                                    date: newDate,
                                    doctorName: selectedDoctor,
                                    occupiedSlots: occupiedSlots,
                                    currentSelectedTime: newTime,
                                  );

                                  if (availableSlots.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: Text(
                                        'No slots available for this doctor on this date.',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
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
                                      crossAxisCount: 3,
                                      childAspectRatio: 2.3,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                    itemCount: availableSlots.length,
                                    itemBuilder: (context, index) {
                                      final time = availableSlots[index];
                                      final isOccupied = occupiedSlots
                                          .contains(_normalizeTime(time));
                                      final isSelected = newTime != null &&
                                          _normalizeTime(newTime!) ==
                                              _normalizeTime(time);

                                      return InkWell(
                                        onTap: () {
                                          if (isOccupied) {
                                            setS(() {
                                              slotConflictError =
                                                  'Time slot $time is already occupied by another appointment. Selection is prevented.';
                                            });
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Time slot $time is already booked for Dr. ${selectedDoctor ?? "this doctor"}. The system prevents selecting occupied slots.',
                                                ),
                                                backgroundColor: Colors.red,
                                                duration:
                                                    const Duration(seconds: 2),
                                              ),
                                            );
                                            return;
                                          }
                                          setS(() {
                                            newTime = time;
                                            slotConflictError = null;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isOccupied
                                                ? const Color(0xFFF1F5F9)
                                                : isSelected
                                                    ? AppTheme.primaryColor
                                                    : Colors.white,
                                            border: Border.all(
                                              color: isOccupied
                                                  ? Colors.red.shade200
                                                  : isSelected
                                                      ? AppTheme.primaryColor
                                                      : AppTheme.borderColor,
                                              width: isSelected ? 1.5 : 1.0,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                time,
                                                style: TextStyle(
                                                  color: isOccupied
                                                      ? Colors.grey.shade600
                                                      : isSelected
                                                          ? Colors.white
                                                          : AppTheme
                                                              .textPrimaryColor,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  fontSize: 11,
                                                  decoration: isOccupied
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                                ),
                                              ),
                                              if (isOccupied) ...[
                                                const SizedBox(height: 2),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 4,
                                                    vertical: 1,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      4,
                                                    ),
                                                    border: Border.all(
                                                      color:
                                                          Colors.red.shade200,
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Booked',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.red.shade700,
                                                      fontSize: 8.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              if (newTime == null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Please select a time slot',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              if (slotConflictError != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  slotConflictError!,
                                  style: const TextStyle(
                                    color: AppTheme.dangerColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // Override reason (mandatory)
                      buildField(
                        'Override Reason',
                        TextFormField(
                          controller: reasonCtrl,
                          maxLines: 3,
                          maxLength: 100,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: validateReason,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]'),
                            ),
                            LengthLimitingTextInputFormatter(100),
                          ],
                          decoration: InputDecoration(
                            hintText: 'Enter reason for this override (max 100 characters)',
                            errorText: reasonError,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            fillColor: const Color(0xFFF1F5F9),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.borderColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.borderColor,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.dangerColor,
                                width: 1.5,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.dangerColor,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) => setS(() {
                            reasonError = validateReason(value);
                          }),
                        ),
                      ),

                      // Audit who
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDBA74)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 14,
                              color: Color(0xFFF97316),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Override by: ${user?.fullname ?? ''} (${user?.role ?? ''})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              if (mode != 'view')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.logoRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final reasonValidation = validateReason(reasonCtrl.text);
                          if (reasonValidation != null) {
                            setS(() {
                              reasonError = reasonValidation;
                            });
                            return;
                          }
                          if (isCompleted && mode == 'reschedule') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Completed appointments cannot be rescheduled.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (!isCompleted &&
                              (mode == 'edit' || mode == 'reschedule')) {
                            if (newDate == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a date.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            if (newTime == null || newTime!.trim().isEmpty) {
                              setS(() {
                                slotConflictError =
                                    'Please select an available time slot.';
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please select an available time slot.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            if (occupiedSlots.contains(
                              _normalizeTime(newTime!),
                            )) {
                              setS(() {
                                slotConflictError =
                                    'The selected time slot ($newTime) is already booked. Selection is prevented.';
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Time slot $newTime is already booked for Dr. ${selectedDoctor ?? "this doctor"}. The system prevents selecting occupied slots.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                          }
                          setS(() => isSaving = true);
                          try {
                            await _apptCtrl.adminOverrideAppointment(
                              id: appt.id!,
                              status: mode == 'cancel'
                                  ? 'Cancelled'
                                  : selectedStatus,
                              doctorName:
                                  (mode == 'edit' || mode == 'reschedule')
                                  ? selectedDoctor
                                  : null,
                              appointmentDate:
                                  !isCompleted &&
                                          (mode == 'reschedule' ||
                                              mode == 'edit') &&
                                          newDate != null
                                      ? DateFormat('yyyy-MM-dd').format(newDate!)
                                      : null,
                              appointmentTime:
                                  !isCompleted &&
                                          (mode == 'reschedule' ||
                                              mode == 'edit')
                                      ? newTime
                                      : null,
                              patientName: mode == 'edit' ? patientName : null,
                              department: mode == 'edit' ? department : null,
                              appointmentType: mode == 'edit'
                                  ? appointmentType
                                  : null,
                              overrideReason: reasonCtrl.text.trim(),
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Appointment updated successfully.',
                                  ),
                                  backgroundColor: Colors.green.shade600,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceAll('Exception: ', ''),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setS(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          mode == 'cancel'
                              ? 'Confirm Cancel'
                              : mode == 'reschedule'
                              ? 'Reschedule'
                              : mode == 'reopen'
                              ? 'Confirm Change'
                              : 'Save Override',
                        ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondaryColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 24,
            isMobile ? 16 : 24,
            isMobile ? 16 : 24,
            0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appointments',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'View, edit, cancel and reschedule appointments',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _loadData,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Search and Filter Toggle Row
        Container(
          margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildFilterToggle(isMobile),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 4, child: _buildSearchBar()),
                    const SizedBox(width: 16),
                    _buildFilterToggle(isMobile),
                  ],
                ),
        ),

        if (_isFilterVisible) ...[
          const SizedBox(height: 16),
          Container(
            margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                isMobile
                    ? Column(
                        children: [
                          _buildFilterDropdown(
                            'Appointment Date',
                            _filterDate != null
                                ? DateFormat('dd/MM/yyyy').format(_filterDate!)
                                : 'Any Date',
                            [],
                            (v) {},
                            isMobile: true,
                            isDate: true,
                          ),
                          const SizedBox(height: 14),
                          _buildFilterDropdown(
                            'Department',
                            _filterDepartment ?? 'All Departments',
                            ['All Departments', ..._departments],
                            (v) {
                              setState(
                                () => _filterDepartment = v == 'All Departments'
                                    ? null
                                    : v,
                              );
                              _loadData();
                            },
                            isMobile: true,
                          ),
                          const SizedBox(height: 14),
                          _buildFilterDropdown(
                            'Doctor',
                            _filterDoctor ?? 'All Doctors',
                            ['All Doctors', ..._doctors.map((d) => d.fullname)],
                            (v) {
                              setState(
                                () => _filterDoctor = v == 'All Doctors'
                                    ? null
                                    : v,
                              );
                              _loadData();
                            },
                            isMobile: true,
                          ),
                          const SizedBox(height: 14),
                          _buildFilterDropdown(
                            'Status',
                            _filterStatus,
                            _statusOptions,
                            (v) {
                              setState(
                                () => _filterStatus = v ?? 'All Status',
                              );
                              _loadData();
                            },
                            isMobile: true,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _buildFilterDropdown(
                              'Appointment Date',
                              _filterDate != null
                                  ? DateFormat(
                                      'dd-MM-yyyy',
                                    ).format(_filterDate!)
                                  : 'Any Date',
                              [],
                              (v) {},
                              isMobile: false,
                              isDate: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFilterDropdown(
                              'Department',
                              _filterDepartment ?? 'All Departments',
                              ['All Departments', ..._departments],
                              (v) {
                                setState(
                                  () => _filterDepartment =
                                      v == 'All Departments' ? null : v,
                                );
                                _loadData();
                              },
                              isMobile: false,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFilterDropdown(
                              'Doctor',
                              _filterDoctor ?? 'All Doctors',
                              [
                                'All Doctors',
                                ..._doctors.map((d) => d.fullname),
                              ],
                              (v) {
                                setState(
                                  () => _filterDoctor = v == 'All Doctors'
                                      ? null
                                      : v,
                                );
                                _loadData();
                              },
                              isMobile: false,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFilterDropdown(
                              'Status',
                              _filterStatus,
                              _statusOptions,
                              (v) {
                                setState(
                                  () => _filterStatus = v ?? 'All Status',
                                );
                                _loadData();
                              },
                              isMobile: false,
                            ),
                          ),
                        ],
                      ),
                if (_filterDate != null ||
                    _filterDoctor != null ||
                    (_filterStatus != 'All' && _filterStatus != 'All Status') ||
                    _filterDepartment != null) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _filterDate = null;
                          _filterDepartment = null;
                          _filterDoctor = null;
                          _filterStatus = 'All Status';
                        });
                        _loadData();
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset Filters'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Stats bar
        Container(
          margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
          child: isMobile
              ? Column(
                  children: [
                    Row(
                      children: [
                        for (final s in ['Confirmed', 'Completed'])
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _statusColor(s).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _statusColor(s).withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${_appointments.where((a) => a.status == s).length}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _statusColor(s),
                                    ),
                                  ),
                                  Text(
                                    s,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _statusColor(s),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        for (final s in ['Cancelled', 'No-Show'])
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _statusColor(s).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _statusColor(s).withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${_appointments.where((a) => a.status == s).length}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _statusColor(s),
                                    ),
                                  ),
                                  Text(
                                    s,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _statusColor(s),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    for (final s in [
                      'Confirmed',
                      'Completed',
                      'Cancelled',
                      'No-Show',
                    ])
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _statusColor(s).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _statusColor(s).withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${_appointments.where((a) => a.status == s).length}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _statusColor(s),
                                ),
                              ),
                              Text(
                                s,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _statusColor(s),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),

        const SizedBox(height: 16),

        // Table
        Expanded(child: _buildTable(isMobile)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
              controller: _searchController,
              onChanged: (v) => setState(() {
                _searchQuery = v;
                _currentPage = 0;
              }),
              decoration: const InputDecoration(
                hintText:
                    'Search by patient name, mobile number, or department...',
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
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _currentPage = 0;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterToggle(bool isMobile) {
    return ElevatedButton.icon(
      onPressed: () => setState(() => _isFilterVisible = !_isFilterVisible),
      icon: Icon(
        _isFilterVisible ? Icons.filter_list_off : Icons.filter_list,
        size: 18,
      ),
      label: const Text(
        'Filter',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimaryColor,
        minimumSize: Size(isMobile ? double.infinity : 120, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        elevation: 0,
        side: const BorderSide(color: AppTheme.borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    required bool isMobile,
    bool isDate = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        isDate
            ? InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _filterDate ?? DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) {
                    setState(() => _filterDate = d);
                    _loadData();
                  }
                },
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 14,
                            color: _filterDate != null
                                ? AppTheme.textPrimaryColor
                                : AppTheme.textSecondaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_filterDate != null)
                        GestureDetector(
                          onTap: () {
                            setState(() => _filterDate = null);
                            _loadData();
                          },
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : CustomDropdownSearch(
                label: '',
                value: value,
                dropdownItems: items,
                height: 48,
                onChanged: onChanged,
              ),
      ],
    );
  }

  Widget _buildTable(bool isMobile) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }
    final allFiltered = _filteredAppointments;
    final totalAppointments = allFiltered.length;
    final totalPages = (totalAppointments / _itemsPerPage).ceil();

    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
    if (_currentPage < 0) _currentPage = 0;

    final apps = allFiltered
        .skip(_currentPage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 56,
              color: AppTheme.textSecondaryColor.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'No appointments found',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try adjusting your filters',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, constraints) => Scrollbar(
                  controller: _vScroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _vScroll,
                    child: SingleChildScrollView(
                      controller: _hScroll,
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          horizontalMargin: 20,
                          columnSpacing: 24,
                          headingRowHeight: 52,
                          dataRowMinHeight: 58,
                          dataRowMaxHeight: 72,
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFEDF2F7),
                          ),
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                          columns: const [
                            DataColumn(label: Text('S.No')),
                            DataColumn(label: Text('Patient')),
                            DataColumn(label: Text('Doctor')),
                            DataColumn(label: Text('Doctor Department')),
                            DataColumn(label: Text('Date & Time')),
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Override')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: apps.asMap().entries.map((entry) {
                            final index = entry.key;
                            final appt = entry.value;
                      final sc = _statusColor(appt.status);
                      final hasOverride =
                          appt.overrideReason != null &&
                          appt.overrideReason!.isNotEmpty;
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '${(index + 1) + (_currentPage * _itemsPerPage)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appt.patientName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${appt.patientDisplayId ?? appt.patientId}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appt.doctorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Builder(
                                  builder: (context) {
                                    UserModel? docModel;
                                    try {
                                      docModel = _doctors.firstWhere(
                                        (d) => (appt.doctorId != null && d.id == appt.doctorId) || _isSameDoctor(d.fullname, appt.doctorName),
                                      );
                                    } catch (_) {}
                                    final docId = (appt.doctorDisplayId != null &&
                                            appt.doctorDisplayId!.isNotEmpty &&
                                            !appt.doctorDisplayId!.startsWith('SPMC-AN'))
                                        ? appt.doctorDisplayId!
                                        : (docModel?.staffUniqueId != null &&
                                                docModel!.staffUniqueId!.isNotEmpty &&
                                                !docModel.staffUniqueId!.startsWith('SPMC-AN')
                                            ? docModel.staffUniqueId!
                                            : '');
                                    if (docId.isEmpty) return const SizedBox.shrink();
                                    return Text(
                                      docId,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              appt.department,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appt.appointmentDate,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  appt.appointmentTime,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                                if (appt.isRescheduled)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E8FF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Rescheduled',
                                      style: TextStyle(
                                        color: Color(0xFF9333EA),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                appt.appointmentType,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: sc.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: sc,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    appt.status == 'Checked-in'
                                        ? 'Waiting'
                                        : appt.status,
                                    style: TextStyle(
                                      color: sc,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            hasOverride
                                ? Tooltip(
                                    message:
                                        'Correction applied: ${appt.overrideReason ?? ""}',
                                    child: Icon(
                                      Icons.admin_panel_settings_outlined,
                                      size: 16,
                                      color: const Color(0xFFF97316),
                                    ),
                                  )
                                : const Text(
                                    '—',
                                    style: TextStyle(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // View
                                _actionBtn(
                                  Icons.visibility_outlined,
                                  'View',
                                  const Color(0xFF6366F1),
                                  () => _showOverrideDialog(appt, mode: 'view'),
                                ),
                                // Edit
                                if (appt.status != 'Cancelled' &&
                                    appt.status != 'No-Show')
                                  _actionBtn(
                                    Icons.edit_outlined,
                                    'Edit',
                                    AppTheme.primaryColor,
                                    () =>
                                        _showOverrideDialog(appt, mode: 'edit'),
                                  ),
                                // Reschedule
                                if (appt.status == 'Confirmed' ||
                                    appt.status == 'Waiting' ||
                                    appt.status == 'Checked-in')
                                  _actionBtn(
                                    Icons.schedule_outlined,
                                    'Reschedule',
                                    const Color(0xFF8B5CF6),
                                    () => _showOverrideDialog(
                                      appt,
                                      mode: 'reschedule',
                                    ),
                                  ),
                                // Cancel
                                if (appt.status == 'Confirmed' ||
                                    appt.status == 'Waiting' ||
                                    appt.status == 'Checked-in')
                                  _actionBtn(
                                    Icons.cancel_outlined,
                                    'Cancel',
                                    Colors.redAccent,
                                    () => _showOverrideDialog(
                                      appt,
                                      mode: 'cancel',
                                    ),
                                  ),
                                // Reopen
                                if (appt.status == 'Cancelled' ||
                                    appt.status == 'No-Show')
                                  _actionBtn(
                                    Icons.restore_outlined,
                                    'Change Status',
                                    const Color(0xFF22C55E),
                                    () => _showOverrideDialog(
                                      appt,
                                      mode: 'reopen',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      if (totalPages > 1) const Divider(height: 1),
      _buildPaginationControls(totalPages, isMobile),
    ],
  ),
),
);
}

  Widget _actionBtn(
    IconData icon,
    String tooltip,
    Color color,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
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
            context.pageOfTotal(_currentPage + 1, totalPages),
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
              children: [
                const Icon(Icons.chevron_left, size: 18),
                Text(context.tr('prev', fallback: 'Prev')),
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
              children: [
                Text(context.tr('next', fallback: 'Next')),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
