import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../models/patient_model.dart';
import '../models/user_model.dart';
import '../models/appointment_model.dart';
import '../controllers/patient_controller.dart';
import '../controllers/admin_controller.dart';
import '../controllers/appointment_controller.dart';
import '../widgets/custom_dropdown_search.dart';
import '../widgets/appointment_details_dialog.dart';

class MocDocAppointmentsView extends StatefulWidget {
  const MocDocAppointmentsView({Key? key}) : super(key: key);

  @override
  State<MocDocAppointmentsView> createState() => _MocDocAppointmentsViewState();
}

class _MocDocAppointmentsViewState extends State<MocDocAppointmentsView> {
  // Navigation tabs: Doctor View, Hospital View, Combo View
  String _currentViewMode = 'Doctor View';

  // Filters
  DateTime _filterDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Selected doctor for "Doctor View"
  UserModel? _selectedFilterDoctor;

  // Controllers
  final PatientController _patientController = PatientController();
  final AdminController _adminController = AdminController();
  final AppointmentController _appointmentController = AppointmentController();

  // Local Data State
  List<PatientModel> _patients = [];
  List<UserModel> _doctors = [];
  List<AppointmentModel> _appointments = [];
  List<String> _departments = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Selected Booking Details (when booking a slot)
  UserModel? _bookingDoctor;
  String? _bookingTime;
  PatientModel? _bookingPatient;
  String _bookingApptType = 'Routine';
  final List<String> _apptTypes = [
    'Routine',
    'Follow Up',
    'New Visit',
    'Scheduled',
    'Emergency',
  ];

  // Booking Form controllers
  final TextEditingController _bpSystolicController = TextEditingController();
  final TextEditingController _bpDiastolicController = TextEditingController();
  final TextEditingController _sugarController = TextEditingController();
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _sugarController.dispose();
    _tempController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final patients = await _patientController.fetchPatients();
      final doctors = await _adminController.fetchStaff(role: 'Doctor');
      final appointments = await _appointmentController.fetchAppointments();
      final specializations = await _adminController.fetchSpecializations();

      final activeDoctors = doctors.where((d) {
        if (d.status.toLowerCase() != 'active') return false;
        final dp = d.doctorProfile;
        if (dp == null) return false;
        if (dp.slotStartTime == null || dp.slotStartTime!.trim().isEmpty)
          return false;
        if (dp.slotEndTime == null || dp.slotEndTime!.trim().isEmpty)
          return false;
        if (dp.slotDuration == null || dp.slotDuration!.trim().isEmpty)
          return false;
        if (dp.availableDays == null || dp.availableDays!.isEmpty) return false;
        return true;
      }).toList();

      activeDoctors.sort((a, b) => a.fullname.compareTo(b.fullname));

      if (!mounted) return;
      setState(() {
        _patients = patients;
        _doctors = activeDoctors;
        _appointments = appointments;

        final activeDocSpecializations = _doctors
            .map((d) => d.specialization)
            .where((s) => s != null)
            .toSet();
        _departments = specializations
            .map((e) => e['name'].toString())
            .where((name) => activeDocSpecializations.contains(name))
            .toList();

        // Restore selection if doctor still exists after reload
        if (_selectedFilterDoctor != null) {
          final stillExists = _doctors
              .where((d) => d.id == _selectedFilterDoctor!.id)
              .toList();
          if (stillExists.isNotEmpty) {
            _selectedFilterDoctor = stillExists.first;
          } else {
            _selectedFilterDoctor = null;
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // --- SLOT GENERATOR LOGIC ---
  List<String> _generateSlotsForDoctor(UserModel doctor) {
    if (doctor.slotStartTime == null || doctor.slotEndTime == null) {
      return _generateDefaultSlots();
    }

    int duration = 30; // default 30 mins
    if (doctor.slotDuration != null) {
      duration = int.tryParse(doctor.slotDuration!.split(' ')[0]) ?? 30;
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
      return _generateDefaultSlots();
    }
  }

  List<String> _generateDefaultSlots() {
    List<String> slots = [];
    DateTime start = DateTime(2026, 1, 1, 9, 0); // 09:00 AM
    DateTime end = DateTime(2026, 1, 1, 17, 0); // 05:00 PM
    while (start.isBefore(end)) {
      slots.add(DateFormat('hh:mm a').format(start));
      start = start.add(const Duration(minutes: 30));
    }
    return slots;
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

  bool _isDoctorAvailableOnDate(UserModel doctor, DateTime date) {
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = weekDays[date.weekday - 1];
    final dateStr = DateFormat('dd/MM/yyyy').format(date);

    if (doctor.availableDays == null ||
        !doctor.availableDays!.contains(dayName)) {
      return false;
    }
    if (doctor.weeklyOffDays != null &&
        doctor.weeklyOffDays!.contains(dayName)) {
      return false;
    }
    if (doctor.specificLeaveDates != null &&
        doctor.specificLeaveDates!.contains(dateStr)) {
      return false;
    }
    return true;
  }

  // Find appointment in a specific slot
  AppointmentModel? _getAppointmentInSlot(
    UserModel doctor,
    String slotTime,
    DateTime date,
  ) {
    final dateStr = DateFormat('dd/MM/yyyy').format(date);
    final match = _appointments.where((a) {
      return a.doctorName == doctor.fullname &&
          a.appointmentDate == dateStr &&
          a.appointmentTime == slotTime &&
          a.status != 'Cancelled' &&
          a.status.toLowerCase() != 'admitted';
    }).toList();
    return match.isNotEmpty ? match.first : null;
  }

  // --- ACTIONS ---
  void _openBookingDialog(UserModel doctor, String slotTime) {
    setState(() {
      _bookingDoctor = doctor;
      _bookingTime = slotTime;
      _bookingPatient = null;
      _bookingApptType = 'Routine';
      _bpSystolicController.clear();
      _bpDiastolicController.clear();
      _sugarController.clear();
      _tempController.clear();
      _reasonController.clear();
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Book Appointment Slot',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dr. ${doctor.fullname} | $slotTime',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: Container(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Select Patient *'),
                    _buildDropdown<PatientModel>(
                      hint: 'Search patient...',
                      value: _bookingPatient,
                      items: _patients,
                      itemLabel: (p) => '${p.name} (${p.patientId ?? "N/A"})',
                      onChanged: (val) {
                        setDialogState(() {
                          _bookingPatient = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Appointment Type *'),
                    _buildDropdown<String>(
                      hint: 'Type',
                      value: _bookingApptType,
                      items: _apptTypes,
                      itemLabel: (s) => s,
                      onChanged: (val) {
                        setDialogState(() {
                          _bookingApptType = val ?? 'Routine';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Reason for Visit *'),
                    _buildTextField(
                      controller: _reasonController,
                      hint: 'Fever, checkup, etc.',
                      isNumeric: false,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Vitals (Optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('BP (Systolic)'),
                              _buildTextField(
                                controller: _bpSystolicController,
                                hint: 'e.g. 120',
                                maxLength: 3,
                                validator: (val) {
                                  final text = val?.trim() ?? '';
                                  if (text.isEmpty) return null;
                                  final num = int.tryParse(text);
                                  if (num == null || num < 90 || num > 300)
                                    return '90 - 300';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('BP (Diastolic)'),
                              _buildTextField(
                                controller: _bpDiastolicController,
                                hint: 'e.g. 80',
                                maxLength: 3,
                                validator: (val) {
                                  final text = val?.trim() ?? '';
                                  if (text.isEmpty) return null;
                                  final num = int.tryParse(text);
                                  if (num == null || num < 50 || num > 180)
                                    return '50 - 180';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Sugar Level (mg/dL)'),
                              _buildTextField(
                                controller: _sugarController,
                                hint: 'e.g. 100',
                                maxLength: 6,
                                validator: (val) {
                                  final text = val?.trim() ?? '';
                                  if (text.isEmpty) return null;
                                  final num = double.tryParse(text);
                                  if (num == null || num < 30 || num > 600)
                                    return '30 - 600';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Temperature (°F)'),
                              _buildTextField(
                                controller: _tempController,
                                hint: 'e.g. 98.6',
                                maxLength: 5,
                                validator: (val) {
                                  final text = val?.trim() ?? '';
                                  if (text.isEmpty) return null;
                                  final num = double.tryParse(text);
                                  if (num == null || num < 90 || num > 115)
                                    return '90 - 115';
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
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed:
                    (_bookingPatient == null ||
                        _reasonController.text.trim().isEmpty)
                    ? null
                    : () async {
                        try {
                          _validateForm();
                          final hasVitals =
                              _bpSystolicController.text.trim().isNotEmpty &&
                              _tempController.text.trim().isNotEmpty;

                          final newAppt = AppointmentModel(
                            patientId: _bookingPatient!.id!,
                            patientName: _bookingPatient!.name,
                            department: doctor.specialization ?? 'General',
                            doctorName: doctor.fullname,
                            appointmentDate: DateFormat(
                              'dd/MM/yyyy',
                            ).format(_filterDate),
                            appointmentTime: _bookingTime!,
                            appointmentType: _bookingApptType,
                            bloodPressureSystolic: int.tryParse(
                              _bpSystolicController.text,
                            ),
                            bloodPressureDiastolic: int.tryParse(
                              _bpDiastolicController.text,
                            ),
                            sugarLevel: double.tryParse(_sugarController.text),
                            temperature: double.tryParse(_tempController.text),
                            reasonForVisit: _reasonController.text,
                            status: hasVitals ? 'Waiting' : 'Confirmed',
                          );

                          await _appointmentController.bookAppointment(newAppt);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Appointment booked successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _fetchData();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.dangerColor,
                  disabledBackgroundColor: AppTheme.dangerColor.withOpacity(
                    0.4,
                  ),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white.withOpacity(0.7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  minimumSize: const Size(130, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text('Confirm Booking'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _validateForm() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      throw 'Please enter reason for visit';
    }

    final sys = _bpSystolicController.text.trim();
    final dia = _bpDiastolicController.text.trim();
    final sugar = _sugarController.text.trim();
    final temp = _tempController.text.trim();

    if (sys.isNotEmpty) {
      final val = int.tryParse(sys);
      if (val == null || val < 90 || val > 300)
        throw 'BP Systolic must be 90 - 300 mmHg';
    }
    if (dia.isNotEmpty) {
      final val = int.tryParse(dia);
      if (val == null || val < 50 || val > 180)
        throw 'BP Diastolic must be 50 - 180 mmHg';
    }
    if (sugar.isNotEmpty) {
      final val = double.tryParse(sugar);
      if (val == null || val < 30 || val > 600)
        throw 'Sugar Level must be 30 - 600 mg/dL';
    }
    if (temp.isNotEmpty) {
      final val = double.tryParse(temp);
      if (val == null || val < 90 || val > 115)
        throw 'Temperature must be 90 - 115 °F';
    }
  }

  Color getDarkStatusBg(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'booked':
        return const Color(0xFF1E40AF); // Dark Blue
      case 'arrived':
      case 'checked-in':
      case 'waiting':
        return const Color(0xFF0F766E); // Dark Teal
      case 'in consultation':
        return const Color(0xFFB45309); // Dark Amber
      case 'completed':
        return const Color(0xFF15803D); // Dark Green
      case 'cancelled':
        return const Color(0xFFB91C1C); // Dark Red
      default:
        return const Color(0xFF475569); // Dark Slate
    }
  }

  void _showMoreAppointmentsDialog(
    DateTime date,
    List<AppointmentModel> appts,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.event_note,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Appointments - ${DateFormat('dd MMM yyyy').format(date)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: Container(
            width: 480,
            constraints: const BoxConstraints(maxHeight: 450),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: appts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final a = appts[index];
                final statusColor = AppTheme.getStatusTextColor(a.status);
                final statusBg = AppTheme.getStatusBgColor(a.status);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.borderColor.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Text(
                          a.patientName.isNotEmpty
                              ? a.patientName[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.patientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: AppTheme.textSecondaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  a.appointmentTime,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    a.status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.visibility_outlined, size: 14),
                        label: const Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _openViewDetailsDialog(a);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _openViewDetailsDialog(AppointmentModel appt) {
    showDialog(
      context: context,
      builder: (context) => AppointmentDetailsDialog(
        appointment: appt,
        editVitalsOnly: false,
        onRefresh: _fetchData,
      ),
    );
  }

  void _openVitalsEntryDialog(AppointmentModel appt) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppointmentDetailsDialog(
        appointment: appt,
        editVitalsOnly: true,
        onRefresh: _fetchData,
      ),
    );
  }

  void _cancelAppointment(AppointmentModel appt) async {
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- REUSABLE UI BUILDERS ---
  Widget _buildLabel(String label) {
    final bool hasStar = label.endsWith(' *');
    final String baseText = hasStar
        ? label.substring(0, label.length - 2)
        : label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(
        text: TextSpan(
          text: baseText,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontFamily: AppTheme.fontFamily,
          ),
          children: [
            if (hasStar)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
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
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        isDense: true,
        counterText: '',
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 1.4,
          ),
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
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
      maxLength: maxLength,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
    );
  }

  Widget _buildDropdown<T>({
    required String hint,
    T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required Function(T?) onChanged,
    Color? fillColor,
    Color? borderColor,
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
      label: '',
      hint: hint,
      value: selectedIndexString,
      dropdownMap: map,
      fillColor: fillColor,
      borderColor: borderColor,
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

  // --- VIEW RENDERING DECIDER ---
  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header
          _buildTopHeader(isMobile),

          // Search & Mode Switcher Row
          _buildFiltersRow(isMobile),

          // Active View Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? _buildErrorView()
                : _buildSelectedView(isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppTheme.dangerColor,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: AppTheme.dangerColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildTopHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        24,
        isMobile ? 16 : 24,
        8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
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
                  'Hospital metrics, and departmental view',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow(bool isMobile) {
    final switcherWidget = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Doctor View', 'Hospital View', 'Combo View'].map((mode) {
          final isSel = _currentViewMode == mode;
          return InkWell(
            onTap: () => setState(() => _currentViewMode = mode),
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
                mode,
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

    final searchWidget = Container(
      width: isMobile ? double.infinity : 250,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            size: 16,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(
                hintText: 'Search patients...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
              child: const Icon(
                Icons.clear,
                size: 16,
                color: AppTheme.textSecondaryColor,
              ),
            ),
        ],
      ),
    );

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: switcherWidget,
            ),
            const SizedBox(height: 10),
            searchWidget,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: switcherWidget,
          ),
          const Spacer(),
          searchWidget,
        ],
      ),
    );
  }

  Widget _buildSelectedView(bool isMobile) {
    switch (_currentViewMode) {
      case 'Doctor View':
        return _buildDoctorView(isMobile);
      case 'Hospital View':
        return _buildHospitalView(isMobile);
      case 'Combo View':
        return _buildComboView(isMobile);
      default:
        return _buildDoctorView(isMobile);
    }
  }

  // --- 1. DOCTOR VIEW MODE ---
  Widget _buildDoctorView(bool isMobile) {
    if (_doctors.isEmpty) {
      return const Center(
        child: Text(
          'No doctors available.',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
      );
    }

    // No doctor selected yet — show prompt
    if (_selectedFilterDoctor == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDoctorSelectorBar(isMobile),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search,
                      size: 56,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select a Doctor to View Schedule',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use the search bar above to find and select a doctor.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final slots = _generateSlotsForDoctor(_selectedFilterDoctor!);
    final bool isDocAvailable = _isDoctorAvailableOnDate(
      _selectedFilterDoctor!,
      _filterDate,
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDoctorSelectorBar(isMobile),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMonthlyCalendar(_selectedFilterDoctor!),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: AppTheme.borderColor),
                  const SizedBox(height: 12),
                  _buildSlotsPanel(isMobile, slots, isDocAvailable),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDoctorSelectorBar(isMobile),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 16, 24),
                  child: _buildMonthlyCalendar(_selectedFilterDoctor!),
                ),
              ),
              Container(
                width: 440,
                padding: const EdgeInsets.fromLTRB(16, 0, 24, 24),
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: AppTheme.borderColor)),
                ),
                child: _buildSlotsPanel(isMobile, slots, isDocAvailable),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorSelectorBar(bool isMobile) {
    final dropdownWidget = _buildDropdown<UserModel>(
      hint: 'Search/Select Doctor',
      value: _selectedFilterDoctor,
      items: _doctors,
      itemLabel: (doc) =>
          '${doc.fullname} (${doc.staffUniqueId ?? "N/A"}) - ${doc.specialization ?? "General"}',
      fillColor: Colors.white,
      borderColor: AppTheme.borderColor,
      onChanged: (val) {
        if (val != null) {
          setState(() => _selectedFilterDoctor = val);
        }
      },
    );

    Widget? doctorCard;
    if (_selectedFilterDoctor != null) {
      doctorCard = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Dr. ${_selectedFilterDoctor!.fullname}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'ID: ${_selectedFilterDoctor!.staffUniqueId ?? "N/A"}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        '|',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                      Text(
                        'Specialization: ${_selectedFilterDoctor!.specialization ?? "General"}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
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

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: double.infinity,
              child: dropdownWidget,
            ),
            if (doctorCard != null) ...[
              const SizedBox(height: 10),
              doctorCard,
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 380,
            child: dropdownWidget,
          ),
          const SizedBox(width: 24),
          if (doctorCard != null)
            Expanded(
              child: doctorCard,
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCalendar(UserModel doctor) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final paddingCells = firstDay.weekday % 7;

    final totalCells = paddingCells + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    final weekdayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month - 1,
                    );
                  });
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month + 1,
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: weekdayNames
                .map(
                  (w) => Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          w,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.8,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: rowCount * 7,
            itemBuilder: (context, index) {
              if (index < paddingCells || index >= paddingCells + daysInMonth) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300, width: 1.2),
                  ),
                );
              }

              final dayNum = index - paddingCells + 1;
              final cellDate = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                dayNum,
              );
              final isToday =
                  cellDate.year == DateTime.now().year &&
                  cellDate.month == DateTime.now().month &&
                  cellDate.day == DateTime.now().day;
              final isSelected =
                  cellDate.year == _filterDate.year &&
                  cellDate.month == _filterDate.month &&
                  cellDate.day == _filterDate.day;

              final dateStr = DateFormat('dd/MM/yyyy').format(cellDate);
              final dayAppts = _appointments.where((a) {
                return a.doctorName == doctor.fullname &&
                    a.appointmentDate == dateStr &&
                    a.status != 'Cancelled' &&
                    a.status.toLowerCase() != 'admitted';
              }).toList();

              return InkWell(
                onTap: () {
                  setState(() {
                    _filterDate = cellDate;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(0.04)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : isToday
                          ? AppTheme.secondaryColor
                          : Colors.grey.shade400,
                      width: isSelected || isToday ? 2.0 : 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 3, 4, 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dayNum.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : isToday
                                    ? AppTheme.secondaryColor
                                    : AppTheme.textPrimaryColor,
                              ),
                            ),
                            if (dayAppts.isNotEmpty)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${dayAppts.length}',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: dayAppts.length > 3
                                ? 4
                                : dayAppts.length,
                            itemBuilder: (context, aIdx) {
                              if (dayAppts.length > 3 && aIdx == 3) {
                                return InkWell(
                                  onTap: () => _showMoreAppointmentsDialog(
                                    cellDate,
                                    dayAppts,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '+${dayAppts.length - 3} More',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final a = dayAppts[aIdx];
                              final statusColor = AppTheme.getStatusTextColor(
                                a.status,
                              );
                              final darkBg = getDarkStatusBg(a.status);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: darkBg,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: RichText(
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            '${a.appointmentTime.split(' ')[0]} ',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: AppTheme.fontFamily,
                                        ),
                                      ),
                                      TextSpan(
                                        text: a.patientName,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                          fontFamily: AppTheme.fontFamily,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
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

  bool _isSlotInPast(String slotTime, DateTime date) {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final filterDay = DateTime(date.year, date.month, date.day);

    if (filterDay.isBefore(todayDate)) {
      return true;
    }
    if (filterDay.isAfter(todayDate)) {
      return false;
    }

    try {
      final timeParts = slotTime.split(' ');
      final hms = timeParts[0].split(':');
      int hour = int.parse(hms[0]);
      int minute = hms.length > 1 ? int.parse(hms[1]) : 0;
      if (timeParts.length > 1) {
        if (timeParts[1].toUpperCase() == 'PM' && hour < 12) hour += 12;
        if (timeParts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
      }

      final slotDateTime = DateTime(now.year, now.month, now.day, hour, minute);
      return slotDateTime.isBefore(now);
    } catch (e) {
      return false;
    }
  }

  Widget _buildSlotsPanel(
    bool isMobile,
    List<String> slots,
    bool isDocAvailable,
  ) {
    if (!isDocAvailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.event_busy_outlined,
                size: 56,
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              Text(
                'Dr. ${_selectedFilterDoctor?.fullname ?? ""} is on leave or not available on ${DateFormat('dd/MM/yyyy').format(_filterDate)}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (slots.isEmpty) {
      return const Center(child: Text('No slots configured for this doctor.'));
    }

    final displaySlots = slots.where((s) {
      final appt = _getAppointmentInSlot(
        _selectedFilterDoctor!,
        s,
        _filterDate,
      );
      return appt != null || !_isSlotInPast(s, _filterDate);
    }).toList();

    final slotsContent = displaySlots.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                'No slots available.',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        : GridView.builder(
            shrinkWrap: isMobile,
            physics: isMobile
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 8,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.35,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: displaySlots.length,
            itemBuilder: (context, idx) {
              final slot = displaySlots[idx];
              final appt = _getAppointmentInSlot(
                _selectedFilterDoctor!,
                slot,
                _filterDate,
              );

              if (_searchQuery.isNotEmpty && appt != null) {
                final match =
                    appt.patientName.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    (appt.patientDisplayId?.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ??
                        false);
                if (!match) return const SizedBox.shrink();
              }

              if (appt != null) {
                return _buildBookedSlotCard(appt);
              } else {
                return _buildAvailableSlotCard(
                  _selectedFilterDoctor!,
                  slot,
                );
              }
            },
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              const Icon(
                Icons.access_time_filled,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Slots for ${DateFormat('dd MMM yyyy').format(_filterDate)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        if (isMobile)
          slotsContent
        else
          Expanded(child: slotsContent),
      ],
    );
  }

  Widget _buildBookedSlotCard(AppointmentModel appt) {
    final statusColor = AppTheme.getStatusTextColor(appt.status);
    final statusBg = AppTheme.getStatusBgColor(appt.status);
    final isRescheduled = appt.isRescheduled;
    final bool hasVitals =
        appt.bloodPressureSystolic != null && appt.temperature != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header with Slot Time and Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppTheme.textPrimaryColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          appt.appointmentTime,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: AppTheme.textPrimaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    appt.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Card Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            appt.patientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.textPrimaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRescheduled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'Resched',
                              style: TextStyle(
                                color: Color(0xFF9333EA),
                                fontSize: 8,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appt.patientDisplayId ?? 'ID: ${appt.patientId}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondaryColor,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (appt.patientPhone != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        appt.patientPhone!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMutedColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Action Toolbar at Bottom
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildCardAction(
                  Icons.visibility_outlined,
                  'View',
                  const Color(0xFF065D96),
                  () {
                    _openViewDetailsDialog(appt);
                  },
                ),
                const SizedBox(width: 8),
                if (appt.status == 'Confirmed') ...[
                  if (!hasVitals)
                    _buildCardAction(
                      Icons.monitor_heart_outlined,
                      'Vitals',
                      const Color(0xFF79B649),
                      () {
                        _openVitalsEntryDialog(appt);
                      },
                    ),
                  const SizedBox(width: 8),
                  _buildCardAction(
                    Icons.cancel_outlined,
                    'Cancel',
                    const Color(0xFFE53E3E),
                    () {
                      _cancelAppointment(appt);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableSlotCard(UserModel doctor, String slotTime) {
    return InkWell(
      onTap: () => _openBookingDialog(doctor, slotTime),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.shade200,
            style: BorderStyle.solid,
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  slotTime,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 12, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Available',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
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

  // --- 2. HOSPITAL VIEW MODE ---
  Widget _buildHospitalView(bool isMobile) {
    if (_doctors.isEmpty) {
      return const Center(
        child: Text(
          'No active doctors.',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 3,
        childAspectRatio: isMobile ? 1.5 : 1.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _doctors.length,
      itemBuilder: (context, idx) {
        final doc = _doctors[idx];
        final slots = _generateSlotsForDoctor(doc);
        final bool isAvailable = _isDoctorAvailableOnDate(doc, _filterDate);

        // Calculate stats
        int total = slots.length;
        int booked = 0;
        for (var s in slots) {
          if (_getAppointmentInSlot(doc, s, _filterDate) != null) booked++;
        }
        int available = total - booked;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.borderColor.withOpacity(0.8)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      radius: 20,
                      child: Text(
                        doc.fullname[0].toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.fullname,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.textPrimaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            doc.specialization ?? 'General Medicine',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Timing: ${doc.slotStartTime ?? "--"} - ${doc.slotEndTime ?? "--"}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (!isAvailable) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        'Unavailable Today',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniStat(
                        'Total Slots',
                        total.toString(),
                        Colors.blue,
                      ),
                      _buildMiniStat(
                        'Booked',
                        booked.toString(),
                        Colors.orange,
                      ),
                      _buildMiniStat(
                        'Available',
                        available.toString(),
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: total > 0 ? (booked / total) : 0,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor.withOpacity(0.8),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedFilterDoctor = doc;
                            _currentViewMode = 'Doctor View';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: AppTheme.primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'View Schedule',
                          style: TextStyle(
                            fontSize: 11,
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
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: AppTheme.textMutedColor),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // --- 3. COMBO VIEW MODE ---
  Widget _buildComboView(bool isMobile) {
    // Group appointments by department for the selected date
    final dateStr1 = DateFormat('dd/MM/yyyy').format(_filterDate);
    final dateStr2 = DateFormat('yyyy-MM-dd').format(_filterDate);

    final targetAppts = _appointments.where((a) {
      if (a.status.toLowerCase() == 'admitted') return false;
      String apptDate = a.appointmentDate;
      if (apptDate.contains('T')) {
        apptDate = apptDate.split('T')[0];
      }
      final dateMatch = apptDate == dateStr1 || apptDate == dateStr2;
      if (!dateMatch) return false;

      if (_searchQuery.isNotEmpty) {
        return a.patientName.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            (a.patientDisplayId?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false);
      }
      return true;
    }).toList();

    if (targetAppts.isEmpty) {
      return const Center(
        child: Text(
          'No appointments found.',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
      );
    }

    // Grouping
    final Map<String, List<AppointmentModel>> grouped = {};
    for (var a in targetAppts) {
      final dept = a.department.isEmpty ? 'General' : a.department;
      grouped.putIfAbsent(dept, () => []).add(a);
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: grouped.entries.map((entry) {
        final dept = entry.key;
        final list = entry.value;

        return Card(
          margin: const EdgeInsets.only(bottom: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: AppTheme.primaryColor.withOpacity(0.04),
                child: Row(
                  children: [
                    const Icon(
                      Icons.business,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$dept (${list.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final a = list[idx];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Row(
                      children: [
                        Text(
                          a.patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${a.patientDisplayId ?? "ID: " + a.patientId.toString()})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Time: ${a.appointmentTime} | Doctor: Dr. ${a.doctorName} | Type: ${a.appointmentType}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMutedColor,
                        ),
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.getStatusBgColor(a.status),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        a.status,
                        style: TextStyle(
                          color: AppTheme.getStatusTextColor(a.status),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
