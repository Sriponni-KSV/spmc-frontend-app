import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../models/appointment_model.dart';
import '../controllers/appointment_controller.dart';

class AppointmentDetailsDialog extends StatefulWidget {
  final AppointmentModel appointment;
  final bool editVitalsOnly;
  final VoidCallback? onRefresh;

  const AppointmentDetailsDialog({
    super.key,
    required this.appointment,
    this.editVitalsOnly = false,
    this.onRefresh,
  });

  @override
  State<AppointmentDetailsDialog> createState() => _AppointmentDetailsDialogState();
}

class _AppointmentDetailsDialogState extends State<AppointmentDetailsDialog> {
  final _appointmentController = AppointmentController();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _systolicCtrl;
  late TextEditingController _diastolicCtrl;
  late TextEditingController _sugarCtrl;
  late TextEditingController _tempCtrl;
  late TextEditingController _complaintsCtrl;
  
  bool _isSaving = false;
  late bool _editingVitalsMode;

  @override
  void initState() {
    super.initState();
    _editingVitalsMode = widget.editVitalsOnly;
    
    _systolicCtrl = TextEditingController(text: widget.appointment.bloodPressureSystolic?.toString() ?? '');
    _diastolicCtrl = TextEditingController(text: widget.appointment.bloodPressureDiastolic?.toString() ?? '');
    _sugarCtrl = TextEditingController(text: widget.appointment.sugarLevel?.toString() ?? '');
    _tempCtrl = TextEditingController(text: widget.appointment.temperature?.toString() ?? '');
    _complaintsCtrl = TextEditingController(text: widget.appointment.reasonForVisit ?? '');
  }

  @override
  void dispose() {
    _systolicCtrl.dispose();
    _diastolicCtrl.dispose();
    _sugarCtrl.dispose();
    _tempCtrl.dispose();
    _complaintsCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> parseTimeline() {
    final List<Map<String, dynamic>> timeline = [];
    final changes = widget.appointment.changesLog;
    if (changes is Map) {
      changes.forEach((key, value) {
        if (value is Map && value.containsKey('status')) {
          final statusVal = value['status'];
          if (statusVal is Map && statusVal.containsKey('to')) {
            final toStatus = statusVal['to'];
            try {
              final dt = DateTime.parse(key.toString()).toLocal();
              timeline.add({
                'status': toStatus,
                'timestamp': dt,
              });
            } catch (_) {}
          }
        }
      });
    }

    // Sort timeline chronologically (ascending)
    timeline.sort((a, b) => (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));

    // If timeline is empty, fall back to initial state (Confirmed) at creation time
    if (timeline.isEmpty) {
      DateTime dt = DateTime.now();
      if (widget.appointment.createdAt != null) {
        try {
          dt = DateTime.parse(widget.appointment.createdAt!).toLocal();
        } catch (_) {}
      }
      timeline.add({
        'status': 'Confirmed',
        'timestamp': dt,
      });
    }

    return timeline;
  }

  Future<void> _saveVitals() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final vitalsData = {
        'blood_pressure_systolic': _systolicCtrl.text.trim().isNotEmpty ? int.parse(_systolicCtrl.text.trim()) : null,
        'blood_pressure_diastolic': _diastolicCtrl.text.trim().isNotEmpty ? int.parse(_diastolicCtrl.text.trim()) : null,
        'sugar_level': _sugarCtrl.text.trim().isNotEmpty ? double.parse(_sugarCtrl.text.trim()) : null,
        'temperature': _tempCtrl.text.trim().isNotEmpty ? double.parse(_tempCtrl.text.trim()) : null,
        'reason_for_visit': _complaintsCtrl.text.trim(),
      };

      await _appointmentController.updateVitals(widget.appointment.id!, vitalsData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vitals updated successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to trigger refresh
        if (widget.onRefresh != null) widget.onRefresh!();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving vitals: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 24,
      backgroundColor: Colors.white,
      child: Container(
        width: isMobile ? double.infinity : 640,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dialog Header
            _buildHeader(isMobile),
            const Divider(height: 1),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Patient Details
                      _buildSectionHeader('Patient Details', Icons.person_outline),
                      _buildPatientDetailsCard(isMobile),
                      const SizedBox(height: 24),

                      // 2. Appointment Details
                      _buildSectionHeader('Appointment Details', Icons.calendar_today_outlined),
                      _buildAppointmentDetailsCard(isMobile),
                      const SizedBox(height: 24),

                      // 3. Doctor Details
                      _buildSectionHeader('Doctor Details', Icons.medical_services_outlined),
                      _buildDoctorDetailsCard(isMobile),
                      const SizedBox(height: 24),

                      // 4. Vital Details
                      _buildSectionHeader(
                        _editingVitalsMode ? 'Enter Vital Details' : 'Vital Details',
                        Icons.monitor_heart_outlined,
                        trailing: !_editingVitalsMode && widget.appointment.status == 'Confirmed'
                            ? TextButton.icon(
                                onPressed: () => setState(() => _editingVitalsMode = true),
                                icon: const Icon(Icons.edit, size: 14),
                                label: const Text('Add/Edit Vitals', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                            : null,
                      ),
                      _buildVitalsCard(isMobile),
                      const SizedBox(height: 24),

                      // 5. Status Timeline
                      _buildSectionHeader('Status Timeline', Icons.history),
                      _buildTimelineSection(),
                      const SizedBox(height: 24),

                      // 6. Cancellation Details (only when Cancelled)
                      if (widget.appointment.status == 'Cancelled') ...[
                        _buildCancellationSection(),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),

            // Dialog Actions
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (_editingVitalsMode ? const Color(0xFF0F766E) : AppTheme.primaryColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _editingVitalsMode ? Icons.monitor_heart : Icons.visibility_outlined,
              color: _editingVitalsMode ? const Color(0xFF0F766E) : AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editingVitalsMode ? 'Add Patient Vitals' : 'Appointment Information',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                if (_editingVitalsMode)
                  const Text(
                    'Fill vitals below. Other fields are locked.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing,
          ]
        ],
      ),
    );
  }

  Widget _buildPatientDetailsCard(bool isMobile) {
    final patientName = widget.appointment.patientName.trim().isNotEmpty
        ? widget.appointment.patientName
        : 'N/A';
    final patientId = widget.appointment.patientDisplayId?.trim().isNotEmpty == true
        ? widget.appointment.patientDisplayId!
        : 'N/A';
    final mobileNumber = widget.appointment.patientPhone?.trim().isNotEmpty == true
        ? widget.appointment.patientPhone!
        : 'N/A';
    final gender = widget.appointment.patientGender?.trim().isNotEmpty == true
        ? widget.appointment.patientGender!
        : 'N/A';

    return _buildCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Full Name',
                  patientName,
                  icon: Icons.person_outline,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  'ID',
                  patientId,
                  icon: Icons.badge_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Mobile Number',
                  mobileNumber,
                  icon: Icons.phone_outlined,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  'Gender',
                  gender,
                  icon: Icons.transgender_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentDetailsCard(bool isMobile) {
    final status = widget.appointment.status;
    final statusColor = AppTheme.getStatusTextColor(status);
    final statusBg = AppTheme.getStatusBgColor(status);

    return _buildCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Date',
                  widget.appointment.appointmentDate,
                  icon: Icons.calendar_today_outlined,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  'Time Slot',
                  widget.appointment.appointmentTime,
                  icon: Icons.access_time,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Type',
                  widget.appointment.appointmentType,
                  icon: Icons.merge_type_outlined,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withOpacity(0.2)),
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
                        if (widget.appointment.isRescheduled) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF9333EA).withOpacity(0.2)),
                            ),
                            child: const Text(
                              'Rescheduled',
                              style: TextStyle(
                                color: Color(0xFF9333EA),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ]
                      ],
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

  Widget _buildDoctorDetailsCard(bool isMobile) {
    return _buildCard(
      child: Row(
        children: [
          Expanded(
            child: _buildInfoItem(
              'Doctor Name',
              widget.appointment.doctorName,
              icon: Icons.person_outline,
            ),
          ),
          Expanded(
            child: _buildInfoItem(
              'Department',
              widget.appointment.department,
              icon: Icons.business_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsCard(bool isMobile) {
    if (_editingVitalsMode) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildVitalInputField(
                    controller: _systolicCtrl,
                    label: 'BP Systolic (mmHg) *',
                    hint: 'e.g. 120',
                    isNumeric: true,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Required';
                      final num = int.tryParse(val.trim());
                      if (num == null) return 'Must be integer';
                      if (num < 40 || num > 250) return 'Invalid systolic';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildVitalInputField(
                    controller: _diastolicCtrl,
                    label: 'BP Diastolic (mmHg) *',
                    hint: 'e.g. 80',
                    isNumeric: true,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Required';
                      final num = int.tryParse(val.trim());
                      if (num == null) return 'Must be integer';
                      if (num < 30 || num > 180) return 'Invalid diastolic';
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
                  child: _buildVitalInputField(
                    controller: _sugarCtrl,
                    label: 'Sugar Level (mg/dL)',
                    hint: 'e.g. 95',
                    isNumeric: true,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return null;
                      final num = double.tryParse(val.trim());
                      if (num == null) return 'Invalid sugar';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildVitalInputField(
                    controller: _tempCtrl,
                    label: 'Temperature (°F) *',
                    hint: 'e.g. 98.6',
                    isNumeric: true,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Required';
                      final num = double.tryParse(val.trim());
                      if (num == null) return 'Must be decimal';
                      if (num < 90 || num > 115) return 'Invalid temp';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildVitalInputField(
              controller: _complaintsCtrl,
              label: 'Reason for Visit / Complaints *',
              hint: 'Describe patient complaints...',
              maxLines: 3,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Required';
                return null;
              },
            ),
          ],
        ),
      );
    }

    final bpSystolic = widget.appointment.bloodPressureSystolic;
    final bpDiastolic = widget.appointment.bloodPressureDiastolic;
    final sugar = widget.appointment.sugarLevel;
    final temp = widget.appointment.temperature;
    final complaints = widget.appointment.reasonForVisit;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Blood Pressure',
                  (bpSystolic != null && bpDiastolic != null) ? '$bpSystolic / $bpDiastolic mmHg' : 'Not Entered',
                  icon: Icons.speed,
                  textColor: (bpSystolic == null) ? const Color(0xFF94A3B8) : null,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  'Sugar Level',
                  sugar != null ? '$sugar mg/dL' : 'Not Entered',
                  icon: Icons.bloodtype_outlined,
                  textColor: sugar == null ? const Color(0xFF94A3B8) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Temperature',
                  temp != null ? '$temp °F' : 'Not Entered',
                  icon: Icons.thermostat_outlined,
                  textColor: temp == null ? const Color(0xFF94A3B8) : null,
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          const Text(
            'Reason for Visit / Complaints',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          Text(
            complaints?.isNotEmpty == true ? complaints! : 'None provided.',
            style: TextStyle(
              fontSize: 13,
              color: complaints?.isNotEmpty == true ? AppTheme.textPrimaryColor : const Color(0xFF94A3B8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isNumeric = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            errorStyle: const TextStyle(fontSize: 10, color: Colors.red),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildTimelineSection() {
    // 1. Get parsed logged timeline states
    final timeline = parseTimeline();
    final Map<String, DateTime> completedStates = {};
    for (var item in timeline) {
      completedStates[item['status']] = item['timestamp'] as DateTime;
    }

    // Happy path order
    final happyPath = ['Confirmed', 'Waiting', 'In Consultation', 'Completed'];
    
    // Determine the sequence of states to display
    final currentStatus = widget.appointment.status;
    final List<String> statesToShow = [];
    final bool isHappyPath = happyPath.contains(currentStatus);

    if (isHappyPath) {
      statesToShow.addAll(happyPath);
    } else {
      // For Cancelled or No Show, show the history of what actually occurred
      statesToShow.add('Confirmed');
      for (var item in timeline) {
        if (item['status'] != 'Confirmed' && !statesToShow.contains(item['status'])) {
          statesToShow.add(item['status']);
        }
      }
      if (!statesToShow.contains(currentStatus)) {
        statesToShow.add(currentStatus);
      }
    }

    // Helper to find if state is completed or passed
    bool isStateCompleted(String state) {
      if (state == currentStatus) return true;
      if (completedStates.containsKey(state)) return true;
      if (isHappyPath && happyPath.contains(state)) {
        final stateIdx = happyPath.indexOf(state);
        final currentIdx = happyPath.indexOf(currentStatus);
        return stateIdx <= currentIdx;
      }
      return state == 'Confirmed';
    }

    // Helper to get fallback timestamp for completed state if not in logs
    DateTime getFallbackTimestamp(String state) {
      if (completedStates.containsKey(state)) {
        return completedStates[state]!;
      }
      // Prioritize overrideAt for terminal states
      if (state == 'Cancelled' || state == 'No-Show' || state == 'No Show') {
        if (widget.appointment.overrideAt != null) {
          try {
            return DateTime.parse(widget.appointment.overrideAt!).toLocal();
          } catch (_) {}
        }
      }
      // Use appointment creation time as Confirmed fallback, update time for others
      if (state == 'Confirmed' && widget.appointment.createdAt != null) {
        try {
          return DateTime.parse(widget.appointment.createdAt!).toLocal();
        } catch (_) {}
      }
      if (widget.appointment.updatedAt != null) {
        try {
          return DateTime.parse(widget.appointment.updatedAt!).toLocal();
        } catch (_) {}
      }
      return DateTime.now();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(statesToShow.length, (index) {
          final String status = statesToShow[index];
          final bool isCompleted = isStateCompleted(status);
          final bool isCurrent = status == currentStatus;
          final isLast = index == statesToShow.length - 1;

          // Determine circle color and shadow
          Color circleColor;
          List<BoxShadow>? circleShadow;

          if (isCurrent) {
            circleColor = AppTheme.primaryColor;
            circleShadow = [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.4),
                blurRadius: 4,
                spreadRadius: 2,
              )
            ];
          } else if (isCompleted) {
            circleColor = AppTheme.secondaryColor;
            circleShadow = null;
          } else {
            circleColor = const Color(0xFFCBD5E1);
            circleShadow = null;
          }

          // Determine line color
          // Line is green if this state and the next state are both completed
          Color lineColor = const Color(0xFFCBD5E1);
          if (!isLast) {
            final nextStatus = statesToShow[index + 1];
            if (isCompleted && isStateCompleted(nextStatus)) {
              lineColor = AppTheme.secondaryColor;
            }
          }

          String timeStr = '';
          String dateStr = '';
          if (isCompleted) {
            final dt = getFallbackTimestamp(status);
            timeStr = DateFormat('hh:mm a').format(dt);
            dateStr = DateFormat('dd/MM/yyyy').format(dt);
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: circleColor,
                      shape: BoxShape.circle,
                      boxShadow: circleShadow,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 32,
                      color: lineColor,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          status,
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : (isCompleted ? FontWeight.w600 : FontWeight.normal),
                            fontSize: 12,
                            color: isCurrent 
                                ? AppTheme.textPrimaryColor 
                                : (isCompleted ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                          ),
                        ),
                        const Spacer(),
                        if (isCompleted)
                          Text(
                            '$timeStr, $dateStr',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          )
                        else
                          const Text(
                            'Pending',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCancellationSection() {
    final cancelledByName = widget.appointment.overrideByName ?? 'Staff / Nurse';
    
    String cancelledAtStr = 'N/A';
    if (widget.appointment.overrideAt != null) {
      try {
        final dt = DateTime.parse(widget.appointment.overrideAt!).toLocal();
        cancelledAtStr = DateFormat('dd/MM/yyyy hh:mm a').format(dt);
      } catch (_) {}
    } else if (widget.appointment.updatedAt != null) {
      try {
        final dt = DateTime.parse(widget.appointment.updatedAt!).toLocal();
        cancelledAtStr = DateFormat('dd/MM/yyyy hh:mm a').format(dt);
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Text(
                'Cancellation Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.red.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('Cancelled By', cancelledByName, isCompact: true),
              ),
              Expanded(
                child: _buildInfoItem('Cancelled On', cancelledAtStr, isCompact: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Cancellation Reason',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Text(
              widget.appointment.cancellationReason?.isNotEmpty == true 
                  ? widget.appointment.cancellationReason!
                  : 'No cancellation reason logged.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF7F1D1D),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  Widget _buildInfoItem(String label, String value, {IconData? icon, Color? textColor, bool isCompact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isCompact ? 10 : 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: isCompact ? 12 : 13,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? AppTheme.textPrimaryColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
            ),
          ),
          if (_editingVitalsMode) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveVitals,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Save Vitals',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
