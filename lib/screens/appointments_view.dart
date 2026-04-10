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

class AppointmentsView extends StatefulWidget {
  final bool startWithBookingForm;
  const AppointmentsView({super.key, this.startWithBookingForm = false});

  @override
  State<AppointmentsView> createState() => _AppointmentsViewState();
}

class _AppointmentsViewState extends State<AppointmentsView> {
  String _selectedStatus = 'All Status';
  DateTime _selectedTableDate = DateTime(2026, 3, 25);
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
    if (widget.startWithBookingForm) {
      _isBookingAppointment = true;
    }
    _fetchData();
    _reasonController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
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
      setState(() {
        _patients = patients;
        _doctors = doctors;
        _appointments = appointments;
        _departments = specializations
            .map((e) => e['name'].toString())
            .toList();
        _availableSlots = _generateAllTimeSlots();
        _isLoadingData = false;
      });
    } catch (e) {
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
      DateTime dt = DateFormat('yyyy-MM-dd').parse(cleanDate);
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

  // No longer needed: _deptDoctors map

  // Dynamic Time Slots Generator
  List<String> _generateAllTimeSlots() {
    List<String> slots = [];

    // Morning Session: 09:00 AM - 01:00 PM
    slots.addAll(_generateSlotsForSession(9, 0, 13, 0));

    // Afternoon Session: 02:00 PM - 05:00 PM
    slots.addAll(_generateSlotsForSession(14, 0, 17, 0));

    return slots;
  }

  List<String> _generateSlotsForSession(
    int startHour,
    int startMin,
    int endHour,
    int endMin,
  ) {
    List<String> sessionSlots = [];
    DateTime start = DateTime(2026, 1, 1, startHour, startMin);
    DateTime end = DateTime(2026, 1, 1, endHour, endMin);

    while (start.isBefore(end)) {
      sessionSlots.add(DateFormat('hh:mm a').format(start));
      start = start.add(Duration(minutes: _intervalMinutes));
    }
    return sessionSlots;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    if (_isBookingAppointment) {
      return _buildBookingForm(isMobile);
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Link
          InkWell(
            onTap: () => setState(() {
              _isBookingAppointment = false;
              _clearSelections();
            }),
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
          const SizedBox(height: 32),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Form Cards
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildFormCard(
                      title: 'Select Patient',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDropdown<PatientModel>(
                            hint: 'Select a patient',
                            value: _selectedPatient,
                            items: _patients,
                            itemLabel: (p) => p.name,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Blood Pressure'),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _bpSystolicController,
                                        hint: '120',
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Sugar Level'),
                                _buildTextField(
                                  controller: _sugarController,
                                  hint: '100 mg/dL',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Temperature'),
                                _buildTextField(
                                  controller: _tempController,
                                  hint: '98.6°F',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildFormCard(
                      title: 'Reason for Visit',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            hint: 'Select department',
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
                              height: 60,
                              child:
                                  _doctors
                                      .where(
                                        (d) =>
                                            d.specialization == _selectedDept,
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
                                          onTap: () => setState(
                                            () => _selectedDoctor = doc,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFFF0F7FF)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSelected
                                                    ? const Color(0xFF3B82F6)
                                                    : AppTheme.borderColor,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isSelected
                                                      ? Icons
                                                            .radio_button_checked
                                                      : Icons.radio_button_off,
                                                  size: 18,
                                                  color: isSelected
                                                      ? const Color(0xFF3B82F6)
                                                      : const Color(0xFF94A3B8),
                                                ),
                                                const SizedBox(width: 12),
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: const Color(
                                                    0xFF1E40AF,
                                                  ),
                                                  child: Text(
                                                    _getInitials(doc.fullname),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      doc.fullname,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                        color: Color(
                                                          0xFF2D3748,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      _selectedDept!,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(
                                                          0xFF64748B,
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
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _bookingDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setState(() {
                                  _bookingDate = picked;
                                  _dateController.text = DateFormat(
                                    'dd-MM-yyyy',
                                  ).format(picked);
                                  _selectedTime = null; // Reset time
                                });
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'dd-mm-yyyy',
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
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    childAspectRatio: 2.5,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount: _availableSlots.length,
                              itemBuilder: (context, index) {
                                final time = _availableSlots[index];
                                final isSelected = _selectedTime == time;
                                return InkWell(
                                  onTap: () =>
                                      setState(() => _selectedTime = time),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF3B82F6)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF3B82F6)
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
                                                : const Color(0xFF94A3B8),
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
                                                  : const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // Right Column: Summary
              Expanded(
                flex: 1,
                child: Column(
                  children: [
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
                              DateFormat(
                                'EEEE, MMMM d, yyyy',
                              ).format(_bookingDate!),
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
                                      final appointment = AppointmentModel(
                                        patientId: _selectedPatient!.id!,
                                        patientName: _selectedPatient!.name,
                                        department: _selectedDept!,
                                        doctorName: _selectedDoctor!.fullname,
                                        appointmentDate: DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(_bookingDate!),
                                        appointmentTime: _selectedTime!,
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
                                      );

                                      await _appointmentController
                                          .bookAppointment(appointment);

                                      setState(
                                        () => _isBookingAppointment = false,
                                      );

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
                              backgroundColor: const Color(0xFFE53E3E),
                              disabledBackgroundColor: const Color(
                                0xFFE53E3E,
                              ).withOpacity(0.5),
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Confirm Appointment',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
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
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4A5568),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isNumeric = true,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        isDense: true,
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
      ),
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF2D3748),
                ),
              ),
              if (headerExtra != null) headerExtra,
            ],
          ),
          const SizedBox(height: 20),
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
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(
                    itemLabel(e),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
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
          onPressed: () => setState(() => _isBookingAppointment = true),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Book Appointment'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53E3E),
            foregroundColor: Colors.white,
            minimumSize: const Size(180, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(bool isMobile) {
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Filter appointments for today
    final todayAppts = _appointments.where((a) {
      String apptDate = a.appointmentDate;
      if (apptDate.contains('T')) {
        apptDate = apptDate.split('T')[0];
      }
      return apptDate == todayStr;
    }).toList();

    int total = todayAppts.length;
    int confirmed = todayAppts.where((a) => a.status == 'Confirmed').length;
    int checkedIn = todayAppts.where((a) => a.status == 'Checked In').length;
    int checkedOut = todayAppts.where((a) => a.status == 'Checked Out').length;
    int cancelled = todayAppts.where((a) => a.status == 'Cancelled').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        double cardWidth = (constraints.maxWidth - (16 * 4)) / 5;
        if (isMobile) {
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildStatCard(
                'Total Today',
                total.toString(),
                Colors.grey.shade100,
                Colors.black87,
              ),
              _buildStatCard(
                'Confirmed',
                confirmed.toString(),
                const Color(0xFFEBF8FF),
                const Color(0xFF3182CE),
              ),
              _buildStatCard(
                'Checked In',
                checkedIn.toString(),
                const Color(0xFFF0FFF4),
                const Color(0xFF38A169),
              ),
              _buildStatCard(
                'Checked Out',
                checkedOut.toString(),
                const Color(0xFFFFFFF0),
                const Color(0xFFD69E2E),
              ),
              _buildStatCard(
                'Cancelled',
                cancelled.toString(),
                const Color(0xFFFFF5F5),
                const Color(0xFFE53E3E),
              ),
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatCard(
              'Total Today',
              total.toString(),
              Colors.white,
              Colors.black87,
              width: cardWidth,
            ),
            _buildStatCard(
              'Confirmed',
              confirmed.toString(),
              const Color(0xFFF0F7FF),
              const Color(0xFF3182CE),
              width: cardWidth,
            ),
            _buildStatCard(
              'Checked In',
              checkedIn.toString(),
              const Color(0xFFF0FFF4),
              const Color(0xFF38A169),
              width: cardWidth,
            ),
            _buildStatCard(
              'Checked Out',
              checkedOut.toString(),
              const Color(0xFFFFFEF0),
              const Color(0xFFD69E2E),
              width: cardWidth,
            ),
            _buildStatCard(
              'Cancelled',
              cancelled.toString(),
              const Color(0xFFFFF5F5),
              const Color(0xFFE53E3E),
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color bgColor,
    Color textColor, {
    double? width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isMobile) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 12),
              Text(
                DateFormat('dd-MM-yyyy').format(_selectedTableDate),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.calendar_month,
                size: 18,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedStatus,
              items:
                  [
                        'All Status',
                        'Confirmed',
                        'Checked In',
                        'Waiting',
                        'Cancelled',
                      ]
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e, style: const TextStyle(fontSize: 14)),
                        ),
                      )
                      .toList(),
              onChanged: (val) => setState(() => _selectedStatus = val!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentsTable(bool isMobile) {
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
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _buildTableHeader('Time', flex: 2),
                _buildTableHeader('Date', flex: 2),
                _buildTableHeader('Patient', flex: 3),
                _buildTableHeader('Doctor', flex: 3),
                _buildTableHeader('Department', flex: 2),
                _buildTableHeader('Reason', flex: 2),
                _buildTableHeader('Status', flex: 2),
                _buildTableHeader('Actions', flex: 3, leftPadding: 16),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_appointments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  'No appointments scheduled for this date.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._appointments
                .where((a) {
                  // Simple status filter for now
                  if (_selectedStatus != 'All Status' &&
                      a.status != _selectedStatus)
                    return false;
                  // Add date filter here if needed
                  return true;
                })
                .map(
                  (appt) => Column(
                    children: [
                      _buildAppointmentRow(
                        id: appt.id!,
                        time: appt.appointmentTime,
                        date: appt.appointmentDate,
                        patientName: appt.patientName,
                        patientInitials: _getInitials(appt.patientName),
                        doctorName: appt.doctorName,
                        department: appt.department,
                        reason: appt.reasonForVisit?.isNotEmpty == true
                            ? appt.reasonForVisit!
                            : 'N/A',
                        status: appt.status,
                        statusColor: appt.status == 'Confirmed'
                            ? const Color(0xFF3182CE)
                            : appt.status == 'Checked In'
                            ? const Color(0xFF38A169)
                            : const Color(0xFFE53E3E),
                        statusBg: appt.status == 'Confirmed'
                            ? const Color(0xFFEBF8FF)
                            : appt.status == 'Checked In'
                            ? const Color(0xFFF0FFF4)
                            : const Color(0xFFFFF5F5),
                      ),
                      const Divider(height: 1),
                    ],
                  ),
                )
                .toList(),
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

  Widget _buildAppointmentRow({
    required int id,
    required String time,
    required String date,
    required String patientName,
    required String patientInitials,
    required String doctorName,
    required String department,
    required String reason,
    required String status,
    required Color statusColor,
    required Color statusBg,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
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
                Text(
                  time.contains(' ') ? time.split(' ')[0] : time,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (time.contains(' ')) ...[
                  const SizedBox(width: 4),
                  Text(
                    time.split(' ')[1],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
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
                Text(
                  _formatDate(date),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF1E3A8A),
                  child: Text(
                    patientInitials,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  patientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
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
                  child: Text(
                    doctorName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              department,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
            flex: 3,
            child: Row(
              children: [
                const SizedBox(width: 16),
                if (status == 'Confirmed')
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _appointmentController.updateStatus(
                          id,
                          'Checked In',
                        );
                        setState(() {
                          final index = _appointments.indexWhere(
                            (a) => a.id == id,
                          );
                          if (index != -1) {
                            _appointments[index] = _appointments[index]
                                .copyWith(status: 'Checked In');
                          }
                        });
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
                      backgroundColor: const Color(0xFF048434),
                      minimumSize: const Size(80, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Check In',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () async {
                    try {
                      await _appointmentController.updateStatus(
                        id,
                        'Cancelled',
                      );
                      setState(() {
                        final index = _appointments.indexWhere(
                          (a) => a.id == id,
                        );
                        if (index != -1) {
                          _appointments[index] = _appointments[index].copyWith(
                            status: 'Cancelled',
                          );
                        }
                      });
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFFE53E3E),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
