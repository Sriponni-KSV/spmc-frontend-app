import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../models/appointment_model.dart';
import '../controllers/appointment_controller.dart';
import '../utils/date_formatter.dart';

class CheckInVitalsDialog extends StatefulWidget {
  final AppointmentModel appointment;
  final VoidCallback? onCompleted;

  const CheckInVitalsDialog({
    super.key,
    required this.appointment,
    this.onCompleted,
  });

  @override
  State<CheckInVitalsDialog> createState() => _CheckInVitalsDialogState();
}

class _CheckInVitalsDialogState extends State<CheckInVitalsDialog> {
  final _formKey = GlobalKey<FormState>();
  final AppointmentController _appointmentController = AppointmentController();

  late TextEditingController _systolicCtrl;
  late TextEditingController _diastolicCtrl;
  late TextEditingController _pulseCtrl;
  late TextEditingController _spo2Ctrl;
  late TextEditingController _tempCtrl;
  late TextEditingController _sugarCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _complaintsCtrl;
  late TextEditingController _triageNotesCtrl;

  int _painScore = 0;
  String _triageCategory = 'Non-Urgent';
  bool _isSubmitting = false;
  bool _validateForWaiting = false;

  final List<String> _quickComplaintTags = [
    'Fever',
    'Cough & Cold',
    'Chest Pain',
    'Shortness of Breath',
    'Headache',
    'Abdominal Pain',
    'Vomiting / Diarrhea',
    'Trauma / Injury',
    'Generalized Weakness',
    'Routine Follow-up',
  ];

  double? get _calculatedBmi {
    final h = double.tryParse(_heightCtrl.text.trim());
    final w = double.tryParse(_weightCtrl.text.trim());
    if (h != null && w != null && h > 0 && w > 0) {
      final hInMeters = h / 100.0;
      return w / (hInMeters * hInMeters);
    }
    return null;
  }

  void _onBmiChanged() {
    if (mounted) setState(() {});
  }

  bool get _isFutureAppointment {
    final apptDate = DateFormatter.toDateTime(widget.appointment.appointmentDate);
    if (apptDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final apptDay = DateTime(apptDate.year, apptDate.month, apptDate.day);
    return apptDay.isAfter(today);
  }

  @override
  void initState() {
    super.initState();
    _systolicCtrl = TextEditingController(
      text: widget.appointment.bloodPressureSystolic?.toString() ?? '',
    );
    _diastolicCtrl = TextEditingController(
      text: widget.appointment.bloodPressureDiastolic?.toString() ?? '',
    );
    _pulseCtrl = TextEditingController(
      text: widget.appointment.pulse?.toString() ?? '',
    );
    _spo2Ctrl = TextEditingController(
      text: widget.appointment.spo2?.toString() ?? '',
    );
    _tempCtrl = TextEditingController(
      text: widget.appointment.temperature?.toString() ?? '',
    );
    _sugarCtrl = TextEditingController(
      text: widget.appointment.sugarLevel?.toString() ?? '',
    );
    _heightCtrl = TextEditingController(
      text: widget.appointment.height?.toString() ?? '',
    );
    _weightCtrl = TextEditingController(
      text: widget.appointment.weight?.toString() ?? '',
    );
    _complaintsCtrl = TextEditingController(
      text: widget.appointment.reasonForVisit ?? '',
    );
    _triageNotesCtrl = TextEditingController(
      text: widget.appointment.triageNotes ?? '',
    );
    _painScore = widget.appointment.painScore ?? 0;
    _triageCategory = widget.appointment.triageCategory ?? 'Non-Urgent';

    _heightCtrl.addListener(_onBmiChanged);
    _weightCtrl.addListener(_onBmiChanged);
  }

  @override
  void dispose() {
    _heightCtrl.removeListener(_onBmiChanged);
    _weightCtrl.removeListener(_onBmiChanged);
    _systolicCtrl.dispose();
    _diastolicCtrl.dispose();
    _pulseCtrl.dispose();
    _spo2Ctrl.dispose();
    _tempCtrl.dispose();
    _sugarCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _complaintsCtrl.dispose();
    _triageNotesCtrl.dispose();
    super.dispose();
  }

  Widget _buildLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
          children: isRequired
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: AppTheme.dangerColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    String? suffixText,
    bool isRequired = false,
    List<TextInputFormatter>? formatters,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isRequired: isRequired),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimaryColor),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
            errorStyle: const TextStyle(
              color: AppTheme.dangerColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            suffixText: suffixText,
            suffixStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor,
            ),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.dangerColor, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.dangerColor, width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  // Quick check-in without vitals -> status: Checked In
  Future<void> _handleQuickCheckIn() async {
    if (_isFutureAppointment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot check in before the appointment date.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _appointmentController.updateStatus(widget.appointment.id!, 'Checked In');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.appointment.patientName} marked as Checked In.'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
        Navigator.pop(context, true);
        if (widget.onCompleted != null) widget.onCompleted!();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during check-in: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Save vitals & update status to Waiting
  Future<void> _handleSaveVitalsAndWaiting() async {
    if (_isFutureAppointment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vitals cannot be entered or saved for future-dated appointments.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    setState(() {
      _validateForWaiting = true;
    });

    if (!_formKey.currentState!.validate()) return;

    final sysText = _systolicCtrl.text.trim();
    final tempText = _tempCtrl.text.trim();
    if (sysText.isEmpty || tempText.isEmpty) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final vitalsData = {
        'blood_pressure_systolic': sysText.isNotEmpty ? int.parse(sysText) : null,
        'blood_pressure_diastolic': _diastolicCtrl.text.trim().isNotEmpty
            ? int.parse(_diastolicCtrl.text.trim())
            : null,
        'pulse': _pulseCtrl.text.trim().isNotEmpty ? int.parse(_pulseCtrl.text.trim()) : null,
        'spo2': _spo2Ctrl.text.trim().isNotEmpty ? int.parse(_spo2Ctrl.text.trim()) : null,
        'sugar_level': _sugarCtrl.text.trim().isNotEmpty
            ? double.parse(_sugarCtrl.text.trim())
            : null,
        'temperature': tempText.isNotEmpty ? double.parse(tempText) : null,
        'height': _heightCtrl.text.trim().isNotEmpty ? double.parse(_heightCtrl.text.trim()) : null,
        'weight': _weightCtrl.text.trim().isNotEmpty ? double.parse(_weightCtrl.text.trim()) : null,
        'reason_for_visit': _complaintsCtrl.text.trim(),
        'pain_score': _painScore,
        'triage_category': _triageCategory,
        'triage_notes': _triageNotesCtrl.text.trim().isNotEmpty ? _triageNotesCtrl.text.trim() : null,
      };

      await _appointmentController.updateVitals(widget.appointment.id!, vitalsData);
      await _appointmentController.updateStatus(widget.appointment.id!, 'Waiting');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.appointment.patientName} checked in with vitals and added to Waiting queue!',
            ),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
        Navigator.pop(context, true);
        if (widget.onCompleted != null) widget.onCompleted!();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save vitals: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 700;
    final token = widget.appointment.tokenNumber;
    final isAlreadyCheckedIn = widget.appointment.status == 'Checked In';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 850),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.06),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.how_to_reg,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isAlreadyCheckedIn ? 'Pre-Consultation Vitals' : 'Patient Check-In & Vitals',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (token != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Token #$token',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.appointment.patientName} (${widget.appointment.patientDisplayId ?? "ID #${widget.appointment.patientId}"}) • Dr. ${widget.appointment.doctorName}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondaryColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Patient & Appointment Info Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: const Color(0xFFF8FAFC),
              child: Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _buildMetaItem(Icons.calendar_today, 'Date', widget.appointment.appointmentDate),
                  _buildMetaItem(Icons.access_time, 'Time', widget.appointment.appointmentTime),
                  _buildMetaItem(Icons.medical_services_outlined, 'Dept', widget.appointment.department),
                  _buildMetaItem(Icons.info_outline, 'Status', widget.appointment.status),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.tips_and_updates_outlined, color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Recording pre-consultation vitals will directly transition the patient to the "Waiting" queue for the doctor.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF1E3A8A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Vitals Header
                      const Text(
                        'Pre-Consultation Vitals',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Row 1: BP Systolic & Diastolic
                      if (isDesktop)
                        Row(
                          children: [
                            Expanded(child: _buildSystolicField()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildDiastolicField()),
                          ],
                        )
                      else ...[
                        _buildSystolicField(),
                        const SizedBox(height: 14),
                        _buildDiastolicField(),
                      ],
                      const SizedBox(height: 14),

                      // Row 2: Temperature & Pulse
                      if (isDesktop)
                        Row(
                          children: [
                            Expanded(child: _buildTempField()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildPulseField()),
                          ],
                        )
                      else ...[
                        _buildTempField(),
                        const SizedBox(height: 14),
                        _buildPulseField(),
                      ],
                      const SizedBox(height: 14),

                      // Row 3: SpO2 & Blood Sugar
                      if (isDesktop)
                        Row(
                          children: [
                            Expanded(child: _buildSpo2Field()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildSugarField()),
                          ],
                        )
                      else ...[
                        _buildSpo2Field(),
                        const SizedBox(height: 14),
                        _buildSugarField(),
                      ],
                      const SizedBox(height: 14),

                      // Row 4: Height & Weight
                      if (isDesktop)
                        Row(
                          children: [
                            Expanded(child: _buildHeightField()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildWeightField()),
                          ],
                        )
                      else ...[
                        _buildHeightField(),
                        const SizedBox(height: 14),
                        _buildWeightField(),
                      ],
                      const SizedBox(height: 12),

                      // Dynamic BMI Card
                      _buildBmiCard(),

                      const SizedBox(height: 22),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 16),

                      // Nurse Triage Assessment Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.health_and_safety_outlined,
                              color: AppTheme.secondaryColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nurse Triage & Initial Assessment',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                                Text(
                                  'Initial complaints, Wong-Baker pain score, and priority categorization',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Initial Complaint Quick Chips
                      _buildComplaintChips(),
                      const SizedBox(height: 14),

                      // Chief Complaint / Reason for visit
                      _buildInputField(
                        controller: _complaintsCtrl,
                        label: 'Reason for Visit / Chief Complaint',
                        hintText: 'Enter brief chief complaint or clinical reason...',
                        maxLines: 2,
                        formatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]')),
                          LengthLimitingTextInputFormatter(500),
                        ],
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            if (!RegExp(r'[a-zA-Z]').hasMatch(val)) {
                              return 'Must contain at least one letter';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Pain Score (0-10 Wong-Baker FACES)
                      _buildPainScoreSelector(),
                      const SizedBox(height: 18),

                      // Triage Acuity (Non-Urgent / Urgent / Emergency)
                      _buildTriagePrioritySelector(),
                      const SizedBox(height: 18),

                      // Nurse Triage Notes
                      _buildTriageNotesField(),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  // Cancel
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondaryColor,
                      side: const BorderSide(color: AppTheme.borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),

                  // Quick Check-in (only if not already checked in)
                  if (!isAlreadyCheckedIn)
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _handleQuickCheckIn,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Quick Check-In (Vitals Later)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),

                  // Save Vitals & Move to Waiting
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _handleSaveVitalsAndWaiting,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.queue, size: 18),
                    label: Text(
                      isAlreadyCheckedIn ? 'Save Vitals & Move to Waiting' : 'Check-In & Move to Waiting',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
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

  Widget _buildMetaItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.primaryColor),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor),
        ),
      ],
    );
  }

  Widget _buildSystolicField() {
    return _buildInputField(
      controller: _systolicCtrl,
      label: 'Systolic BP',
      hintText: 'e.g. 120',
      suffixText: 'mmHg',
      isRequired: true,
      keyboardType: TextInputType.number,
      formatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      validator: (val) {
        final text = val?.trim() ?? '';
        if (_validateForWaiting && text.isEmpty) {
          return 'Systolic BP is required to move to Waiting';
        }
        if (text.isEmpty) return null;
        final n = int.tryParse(text);
        if (n == null || n < 90 || n > 300) {
          return 'Valid: 90 - 300 mmHg';
        }
        return null;
      },
    );
  }

  Widget _buildDiastolicField() {
    return _buildInputField(
      controller: _diastolicCtrl,
      label: 'Diastolic BP',
      hintText: 'e.g. 80',
      suffixText: 'mmHg',
      keyboardType: TextInputType.number,
      formatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      validator: (val) {
        if (val == null || val.trim().isEmpty) return null;
        final n = int.tryParse(val.trim());
        if (n == null || n < 50 || n > 180) {
          return 'Valid: 50 - 180 mmHg';
        }
        return null;
      },
    );
  }

  Widget _buildTempField() {
    return _buildInputField(
      controller: _tempCtrl,
      label: 'Temperature',
      hintText: 'e.g. 98.6',
      suffixText: '°F',
      isRequired: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      formatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        LengthLimitingTextInputFormatter(5),
      ],
      validator: (val) {
        final text = val?.trim() ?? '';
        if (_validateForWaiting && text.isEmpty) {
          return 'Temperature is required to move to Waiting';
        }
        if (text.isEmpty) return null;
        final n = double.tryParse(text);
        if (n == null || n < 90 || n > 115) {
          return 'Valid: 90.0 - 115.0 °F';
        }
        return null;
      },
    );
  }

  Widget _buildPulseField() {
    return _buildInputField(
      controller: _pulseCtrl,
      label: 'Pulse Rate',
      hintText: 'e.g. 72',
      suffixText: 'bpm',
      keyboardType: TextInputType.number,
      formatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      validator: (val) {
        if (val == null || val.trim().isEmpty) return null;
        final n = int.tryParse(val.trim());
        if (n == null || n < 40 || n > 200) {
          return 'Valid: 40 - 200 bpm';
        }
        return null;
      },
    );
  }

  Widget _buildSpo2Field() {
    return _buildInputField(
      controller: _spo2Ctrl,
      label: 'SpO₂ Level',
      hintText: 'e.g. 98',
      suffixText: '%',
      keyboardType: TextInputType.number,
      formatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      validator: (val) {
        if (val == null || val.trim().isEmpty) return null;
        final n = int.tryParse(val.trim());
        if (n == null || n < 50 || n > 100) {
          return 'Valid: 50 - 100 %';
        }
        return null;
      },
    );
  }

  Widget _buildSugarField() {
    return _buildInputField(
      controller: _sugarCtrl,
      label: 'Sugar Level',
      hintText: 'e.g. 110',
      suffixText: 'mg/dL',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      formatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        LengthLimitingTextInputFormatter(5),
      ],
      validator: (val) {
        if (val == null || val.trim().isEmpty) return null;
        final n = double.tryParse(val.trim());
        if (n == null || n < 30 || n > 600) {
          return 'Valid: 30 - 600 mg/dL';
        }
        return null;
      },
    );
  }

  Widget _buildHeightField() {
    return _buildInputField(
      controller: _heightCtrl,
      label: 'Height',
      hintText: 'e.g. 170',
      suffixText: 'cm',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      formatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        LengthLimitingTextInputFormatter(5),
      ],
      validator: (val) {
        if (val == null || val.trim().isEmpty) return null;
        final n = double.tryParse(val.trim());
        if (n == null || n < 30 || n > 300) {
          return 'Valid: 30 - 300 cm';
        }
        return null;
      },
    );
  }

  Widget _buildWeightField() {
    return _buildInputField(
      controller: _weightCtrl,
      label: 'Weight',
      hintText: 'e.g. 68.5',
      suffixText: 'kg',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      formatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        LengthLimitingTextInputFormatter(5),
      ],
      validator: (val) {
        if (val == null || val.trim().isEmpty) return null;
        final n = double.tryParse(val.trim());
        if (n == null || n < 0.5 || n > 500) {
          return 'Valid: 0.5 - 500 kg';
        }
        return null;
      },
    );
  }

  Widget _buildBmiCard() {
    final bmi = _calculatedBmi;
    if (bmi == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.monitor_weight_outlined, size: 18, color: AppTheme.textSecondaryColor),
            SizedBox(width: 8),
            Text(
              'Enter Height & Weight to calculate BMI automatically.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
            ),
          ],
        ),
      );
    }

    String category;
    Color categoryColor;
    if (bmi < 18.5) {
      category = 'Underweight';
      categoryColor = const Color(0xFF0284C7);
    } else if (bmi < 25.0) {
      category = 'Normal Weight';
      categoryColor = AppTheme.secondaryColor;
    } else if (bmi < 30.0) {
      category = 'Overweight';
      categoryColor = const Color(0xFFD97706);
    } else {
      category = 'Obese';
      categoryColor = AppTheme.dangerColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: categoryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.speed, color: categoryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'BMI: ${bmi.toStringAsFixed(1)} kg/m²',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: categoryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Healthy range: 18.5 – 24.9 kg/m²',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: categoryColor.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Quick Initial Complaints (Tap to add)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickComplaintTags.map((tag) {
            final isAdded = _complaintsCtrl.text.contains(tag);
            final isHighPriorityTag = tag == 'Chest Pain' || tag == 'Shortness of Breath';
            return ActionChip(
              avatar: isHighPriorityTag
                  ? const Icon(Icons.priority_high, size: 14, color: AppTheme.dangerColor)
                  : null,
              label: Text(
                tag,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isAdded ? FontWeight.bold : FontWeight.w500,
                  color: isAdded
                      ? (isHighPriorityTag ? AppTheme.dangerColor : AppTheme.primaryColor)
                      : AppTheme.textPrimaryColor,
                ),
              ),
              backgroundColor: isAdded
                  ? (isHighPriorityTag
                      ? AppTheme.dangerColor.withOpacity(0.12)
                      : AppTheme.primaryColor.withOpacity(0.12))
                  : const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isAdded
                      ? (isHighPriorityTag ? AppTheme.dangerColor : AppTheme.primaryColor)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              onPressed: () {
                final currentText = _complaintsCtrl.text.trim();
                if (currentText.isEmpty) {
                  _complaintsCtrl.text = tag;
                } else if (!currentText.contains(tag)) {
                  _complaintsCtrl.text = '$currentText, $tag';
                }
                if (isHighPriorityTag && _triageCategory == 'Non-Urgent') {
                  setState(() {
                    _triageCategory = 'Urgent';
                  });
                } else {
                  setState(() {});
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPainScoreSelector() {
    final faces = [
      {'score': 0, 'emoji': '😊', 'label': 'No Pain'},
      {'score': 2, 'emoji': '🙂', 'label': 'Mild'},
      {'score': 4, 'emoji': '😐', 'label': 'Moderate'},
      {'score': 6, 'emoji': '😣', 'label': 'Severe'},
      {'score': 8, 'emoji': '😫', 'label': 'Very Severe'},
      {'score': 10, 'emoji': '😭', 'label': 'Worst Pain'},
    ];

    Color getScoreColor(int s) {
      if (s == 0) return AppTheme.secondaryColor;
      if (s <= 3) return const Color(0xFF84CC16);
      if (s <= 6) return const Color(0xFFF59E0B);
      if (s <= 8) return const Color(0xFFEA580C);
      return AppTheme.dangerColor;
    }

    String getPainLabel(int s) {
      if (s == 0) return '0 - No Pain';
      if (s <= 3) return '$s - Mild Discomfort';
      if (s <= 6) return '$s - Moderate Pain';
      if (s <= 8) return '$s - Severe Pain';
      return '$s - Worst Possible Pain';
    }

    final currentColor = getScoreColor(_painScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('Pain Score (Wong-Baker FACES Scale: 0–10)'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: currentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: currentColor.withOpacity(0.4)),
              ),
              child: Text(
                getPainLabel(_painScore),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: currentColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Wong-Baker FACES Quick Selectors
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: faces.map((f) {
                  final score = f['score'] as int;
                  final isSelected = (_painScore == score) ||
                      (_painScore > score - 2 && _painScore < score + 2 && score > 0 && score < 10);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _painScore = score;
                        if (_painScore >= 8 && _triageCategory == 'Non-Urgent') {
                          _triageCategory = 'Urgent';
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? getScoreColor(score).withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: getScoreColor(score), width: 1.5)
                            : Border.all(color: Colors.transparent),
                      ),
                      child: Column(
                        children: [
                          Text(
                            f['emoji'] as String,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$score',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? getScoreColor(score) : AppTheme.textPrimaryColor,
                            ),
                          ),
                          Text(
                            f['label'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected ? getScoreColor(score) : AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              // Discrete 0-10 chips row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(11, (i) {
                    final selected = _painScore == i;
                    final col = getScoreColor(i);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: Text('$i'),
                        selected: selected,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: selected ? Colors.white : AppTheme.textPrimaryColor,
                        ),
                        selectedColor: col,
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (_) {
                          setState(() {
                            _painScore = i;
                            if (_painScore >= 8 && _triageCategory == 'Non-Urgent') {
                              _triageCategory = 'Urgent';
                            }
                          });
                        },
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTriagePrioritySelector() {
    final options = [
      {
        'value': 'Non-Urgent',
        'label': 'Non-Urgent',
        'desc': 'Routine OPD care, stable vitals',
        'color': AppTheme.secondaryColor,
        'icon': Icons.check_circle_outline,
      },
      {
        'value': 'Urgent',
        'label': 'Urgent',
        'desc': 'Elevated pain/vitals, prompt review',
        'color': const Color(0xFFD97706),
        'icon': Icons.warning_amber_rounded,
      },
      {
        'value': 'Emergency',
        'label': 'Emergency',
        'desc': 'Critical symptoms, immediate doctor alert',
        'color': AppTheme.dangerColor,
        'icon': Icons.emergency,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Triage Acuity / Priority Categorization', isRequired: true),
        Row(
          children: options.map((opt) {
            final val = opt['value'] as String;
            final isSelected = _triageCategory == val;
            final color = opt['color'] as Color;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => setState(() => _triageCategory = val),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.12) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(opt['icon'] as IconData, color: color, size: 24),
                        const SizedBox(height: 6),
                        Text(
                          opt['label'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? color : AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          opt['desc'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.textSecondaryColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTriageNotesField() {
    return _buildInputField(
      controller: _triageNotesCtrl,
      label: 'Nurse Triage Observations / Notes (Optional)',
      hintText: 'e.g. Patient conscious & oriented, walking with support, mild distress...',
      maxLines: 2,
      formatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]')),
        LengthLimitingTextInputFormatter(500),
      ],
    );
  }
}
