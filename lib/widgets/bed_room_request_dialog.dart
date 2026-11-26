import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_notification.dart';
import '../controllers/ipd_controller.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_dropdown_search.dart';

/// Modal dialog allowing a Nurse or Doctor to raise an emergency or standard Bed/Room Request
/// for a patient and attach all necessary patient, clinical, and bed/room information.
class BedRoomRequestDialog extends StatefulWidget {
  final Map<String, dynamic>? initialPatient;
  final int? patientId;
  final String? patientName;
  final String? patientDisplayId;
  final String? patientGender;
  final dynamic patientAge;
  final String? patientPhone;
  final List<Map<String, dynamic>>? availablePatients;
  final VoidCallback? onSuccess;

  const BedRoomRequestDialog({
    Key? key,
    this.initialPatient,
    this.patientId,
    this.patientName,
    this.patientDisplayId,
    this.patientGender,
    this.patientAge,
    this.patientPhone,
    this.availablePatients,
    this.onSuccess,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? initialPatient,
    int? patientId,
    String? patientName,
    String? patientDisplayId,
    String? patientGender,
    dynamic patientAge,
    String? patientPhone,
    List<Map<String, dynamic>>? availablePatients,
    VoidCallback? onSuccess,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BedRoomRequestDialog(
        initialPatient: initialPatient,
        patientId: patientId,
        patientName: patientName,
        patientDisplayId: patientDisplayId,
        patientGender: patientGender,
        patientAge: patientAge,
        patientPhone: patientPhone,
        availablePatients: availablePatients,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<BedRoomRequestDialog> createState() => _BedRoomRequestDialogState();
}

class _BedRoomRequestDialogState extends State<BedRoomRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ipdController = IpdController();

  int? _selectedPatientId;
  String _selectedPatientName = '';
  String _selectedPatientDisplayId = '';
  String _selectedPatientGender = '';
  String _selectedPatientAge = '';
  String _selectedPatientPhone = '';

  String _selectedWardType = 'General';
  String _selectedBedType = 'Standard Bed';
  bool _isEmergency = false;

  final TextEditingController _emergencyDetailsController =
      TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  final List<String> _wardOptions = [
    'General',
    'Semi-Private',
    'Private',
    'ICU',
  ];

  final List<String> _bedTypeOptions = [
    'Standard Bed',
    'Oxygen Support Bed',
    'ICU / Critical Care Bed',
    'Ventilator Bed',
    'Cardiac Monitor Bed',
    'Isolation Bed',
    'Deluxe / Suite Bed',
  ];

  @override
  void initState() {
    super.initState();
    _initPatientData();
  }

  void _initPatientData() {
    if (widget.initialPatient != null) {
      final p = widget.initialPatient!;
      _selectedPatientId = int.tryParse(p['id']?.toString() ?? p['patient_id']?.toString() ?? '');
      _selectedPatientName = (p['name'] ?? p['patient_name'] ?? '').toString();
      _selectedPatientDisplayId = (p['patient_id'] ?? p['patient_display_id'] ?? '').toString();
      _selectedPatientGender = (p['gender'] ?? p['patient_gender'] ?? '').toString();
      _selectedPatientAge = (p['age'] ?? p['patient_age'] ?? '').toString();
      _selectedPatientPhone = (p['phone'] ?? p['patient_phone'] ?? '').toString();
    } else if (widget.patientId != null) {
      _selectedPatientId = widget.patientId;
      _selectedPatientName = widget.patientName ?? '';
      _selectedPatientDisplayId = widget.patientDisplayId ?? '';
      _selectedPatientGender = widget.patientGender ?? '';
      _selectedPatientAge = widget.patientAge?.toString() ?? '';
      _selectedPatientPhone = widget.patientPhone ?? '';
    }
  }

  @override
  void dispose() {
    _emergencyDetailsController.dispose();
    _diagnosisController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() {
    if (!_formKey.currentState!.validate()) {
      return Future.value();
    }

    if (_selectedPatientId == null) {
      setState(() => _errorMessage = 'Please select a patient to raise the bed/room request.');
      return Future.value();
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final requesterName = authProvider.user?.fullname ?? 'Clinician';
    final userRole = authProvider.user?.role ?? 'Doctor';

    final String emgDetails = _emergencyDetailsController.text.trim();
    String reason = _reasonController.text.trim();
    if (_isEmergency) {
      final prefix = emgDetails.isNotEmpty ? '[EMERGENCY: $emgDetails]' : '[EMERGENCY]';
      reason = reason.isNotEmpty ? '$prefix $reason' : prefix;
    }

    return _ipdController.createPendingAdmission({
      'patient_id': _selectedPatientId,
      'doctor_name': userRole.toLowerCase().contains('nurse')
          ? 'Nurse $requesterName'
          : (requesterName.startsWith('Dr.') ? requesterName : 'Dr. $requesterName'),
      'bed_type_requirement': _selectedWardType,
      'bed_type': _selectedBedType,
      'is_emergency': _isEmergency,
      'priority': _isEmergency ? 'Emergency' : 'Normal',
      'triage_priority': _isEmergency ? 'Emergency' : 'Normal',
      'emergency_details': _isEmergency ? (emgDetails.isNotEmpty ? emgDetails : 'Urgent bed allocation required') : null,
      'diagnosis': _diagnosisController.text.trim(),
      'reason_for_admission': reason,
    }).then((_) {
      if (!mounted) return;
      Navigator.of(context).pop(true);
      final msg = _isEmergency
          ? 'Emergency Bed/Room request submitted successfully. Priority flagged for Admission Counter.'
          : 'Bed/Room request submitted successfully. Sent to Admission Counter.';
      AppNotification.showSuccess(context, msg, atTop: true);
      widget.onSuccess?.call();
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        String rawErr = e.toString().replaceAll('Exception: ', '').trim();
        if (rawErr.toLowerCase().contains('violates') || rawErr.toLowerCase().contains('constraint')) {
          rawErr = 'Unable to create bed request. Please verify the patient details and try again.';
        }
        _errorMessage = rawErr;
      });
      AppNotification.showError(context, _errorMessage ?? 'Error submitting request', atTop: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.user?.role ?? 'Clinician';
    final staffName = authProvider.user?.fullname ?? 'Staff';

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? screenWidth * 0.95 : 560,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: BoxDecoration(
                color: _isEmergency ? const Color(0xFFC0392B) : AppTheme.primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isEmergency ? Icons.warning_amber_rounded : Icons.hotel_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEmergency ? 'Emergency Bed / Room Request' : 'Bed / Room Request',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _isEmergency
                              ? 'High priority bed request for urgent admission'
                              : 'Raise bed or room allocation request to Front Desk',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (_isEmergency)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'EMERGENCY',
                        style: TextStyle(
                          color: Color(0xFFC0392B),
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emergency Toggle Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isEmergency ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isEmergency ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                            width: _isEmergency ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isEmergency ? Icons.emergency : Icons.priority_high,
                              color: _isEmergency ? const Color(0xFFDC2626) : AppTheme.textSecondaryColor,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mark as Emergency Request',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _isEmergency ? const Color(0xFF991B1B) : AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                  Text(
                                    _isEmergency
                                        ? 'Prioritized at top of queue for expedited bed allocation.'
                                        : 'Toggle if patient requires immediate, urgent bed placement.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _isEmergency ? const Color(0xFFB91C1C) : AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isEmergency,
                              activeColor: const Color(0xFFDC2626),
                              onChanged: (val) {
                                setState(() {
                                  _isEmergency = val;
                                  if (val && _selectedWardType != 'ICU') {
                                    _selectedWardType = 'ICU';
                                    _selectedBedType = 'ICU / Critical Care Bed';
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Attached Patient Details Banner
                      const Text(
                        'Patient Information',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedPatientName.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F7FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                                child: Text(
                                  _selectedPatientName.isNotEmpty ? _selectedPatientName[0].toUpperCase() : 'P',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedPatientName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'ID: ${_selectedPatientDisplayId.isNotEmpty ? _selectedPatientDisplayId : _selectedPatientId} • ${_selectedPatientGender.isNotEmpty ? _selectedPatientGender : 'N/A'} • ${_selectedPatientAge.isNotEmpty ? "${_selectedPatientAge}y" : 'N/A'}${_selectedPatientPhone.isNotEmpty ? " • Tel: $_selectedPatientPhone" : ""}',
                                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryColor),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 12, color: Colors.green),
                                    SizedBox(width: 4),
                                    Text('Attached', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Select patient dropdown if not pre-populated
                        CustomDropdownSearch(
                          label: 'Select Patient',
                          hint: 'Search & select patient',
                          dropdownMap: {
                            for (var p in (widget.availablePatients ?? []))
                              p['id'].toString(): '${p['name']} (${p['patient_id'] ?? p['id']})',
                          },
                          onChanged: (val) {
                            if (val != null && widget.availablePatients != null) {
                              final match = widget.availablePatients!.firstWhere(
                                (p) => p['id'].toString() == val,
                                orElse: () => {},
                              );
                              if (match.isNotEmpty) {
                                setState(() {
                                  _selectedPatientId = int.tryParse(val);
                                  _selectedPatientName = match['name']?.toString() ?? '';
                                  _selectedPatientDisplayId = match['patient_id']?.toString() ?? val;
                                  _selectedPatientGender = match['gender']?.toString() ?? '';
                                  _selectedPatientAge = match['age']?.toString() ?? '';
                                  _selectedPatientPhone = match['phone']?.toString() ?? '';
                                });
                              }
                            }
                          },
                          validator: (val) => _selectedPatientId == null ? 'Please select a patient' : null,
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Bed / Room Specifications Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ward / Room Type
                          Expanded(
                            child: CustomDropdownSearch(
                              label: 'Required Ward / Room',
                              requiredMark: true,
                              hint: 'Select Ward / Room',
                              value: _selectedWardType,
                              dropdownMap: {
                                for (var w in _wardOptions) w: '$w Ward',
                              },
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedWardType = val);
                              },
                              validator: (val) =>
                                  (val == null || val.isEmpty) ? 'Please select ward / room' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Bed Type
                          Expanded(
                            child: CustomDropdownSearch(
                              label: 'Required Bed Type',
                              requiredMark: true,
                              hint: 'Select Bed Type',
                              value: _selectedBedType,
                              dropdownItems: _bedTypeOptions,
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedBedType = val);
                              },
                              validator: (val) =>
                                  (val == null || val.isEmpty) ? 'Please select bed type' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Emergency details (if emergency)
                      if (_isEmergency) ...[
                        const Text.rich(
                          TextSpan(
                            text: 'Emergency Details / Clinical Urgency',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC0392B)),
                            children: [
                              TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emergencyDetailsController,
                          maxLines: 2,
                          maxLength: 150,
                          decoration: _inputDecoration(
                            'Describe emergency urgency (e.g. SpO2 < 85%, critical respiratory distress, cardiac emergency)...',
                            isEmergencyBorder: true,
                          ),
                          validator: (val) {
                            if (_isEmergency && (val == null || val.trim().isEmpty)) {
                              return 'Please describe the emergency details for priority processing';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Diagnosis
                      const Text.rich(
                        TextSpan(
                          text: 'Provisional Diagnosis / Condition',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _diagnosisController,
                        maxLength: 100,
                        decoration: _inputDecoration('e.g. Acute Coronary Syndrome, Dengue with warning signs...'),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter the provisional diagnosis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Reason / Justification
                      const Text.rich(
                        TextSpan(
                          text: 'Clinical Reason & Justification for Request',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        maxLength: 200,
                        decoration: _inputDecoration('Enter medical justification, nursing observations, or required equipment...'),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter the medical reason for admission / bed request';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Requester tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.badge_outlined, size: 16, color: Colors.blueGrey.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Requesting Clinician: $staffName ($userRole)',
                              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade800, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.dangerColor.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppTheme.dangerColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.dangerColor),
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
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    style: AppTheme.cancelButton,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(_isEmergency ? Icons.warning_rounded : Icons.send_rounded, size: 16, color: Colors.white),
                    label: Text(
                      _isSubmitting
                          ? 'Submitting...'
                          : (_isEmergency ? 'Submit Emergency Request' : 'Submit Bed Request'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEmergency ? const Color(0xFFDC2626) : AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  InputDecoration _inputDecoration(String hint, {bool isEmergencyBorder = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
      counterText: '',
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isEmergencyBorder ? const Color(0xFFF87171) : const Color(0xFFCBD5E1),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isEmergencyBorder ? const Color(0xFFF87171) : const Color(0xFFCBD5E1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isEmergencyBorder ? const Color(0xFFDC2626) : AppTheme.primaryColor,
          width: 1.5,
        ),
      ),
    );
  }
}
