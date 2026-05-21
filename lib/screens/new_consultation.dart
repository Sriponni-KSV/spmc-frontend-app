import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../models/appointment_model.dart';
import '../controllers/patient_controller.dart';
import '../controllers/appointment_controller.dart';

class NewConsultationView extends StatefulWidget {
  final AppointmentModel appointment;
  final Map<String, dynamic>? initialConsultation;
  final VoidCallback onBack;

  const NewConsultationView({
    Key? key,
    required this.appointment,
    required this.onBack,
    this.initialConsultation,
  }) : super(key: key);

  @override
  State<NewConsultationView> createState() => _NewConsultationViewState();
}

class _NewConsultationViewState extends State<NewConsultationView> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<Map<String, String>> _medications = [];
  
  final TextEditingController _medNameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _freqController = TextEditingController(text: '1-0-1');
  final TextEditingController _durController = TextEditingController();

  // Lab test state
  final Map<String, bool> _standardLabs = {
    'Complete Blood Count (CBC)': false,
    'Basic Metabolic Panel (BMP)': false,
    'Lipid Panel': false,
    'Thyroid Panel (TSH)': false,
    'Urinalysis': false,
    'Chest X-Ray': false,
    'ECG/EKG': false,
  };
  final List<String> _customLabs = [];
  final TextEditingController _customLabController = TextEditingController();

  final PatientController _patientController = PatientController();
  final AppointmentController _appointmentController = AppointmentController();
  
  late AppointmentModel _currentAppointment;
  bool _isLoadingVitals = true;
  bool _isLoadingHistory = true;
  bool _isSaving = false;
  int _currentStep = 0;
  List<Map<String, dynamic>> _previousConsultations = [];

  @override
  void initState() {
    super.initState();
    _currentAppointment = widget.appointment;
    _fetchLatestVitals();
    _fetchPreviousConsultations();
    _initializeData();
  }

  void _initializeData() {
    if (widget.initialConsultation != null) {
      _symptomsController.text = widget.initialConsultation!['symptoms'] ?? '';
      _diagnosisController.text = widget.initialConsultation!['diagnosis'] ?? '';
      _notesController.text = widget.initialConsultation!['notes'] ?? '';
      
      final meds = widget.initialConsultation!['medications'];
      if (meds is List) {
        for (var m in meds) {
          if (m is Map) {
            _medications.add({
              'name': m['name']?.toString() ?? '',
              'dosage': m['dosage']?.toString() ?? '',
              'frequency': m['frequency']?.toString() ?? '',
              'duration': m['duration']?.toString() ?? '',
            });
          }
        }
      }

      final labs = widget.initialConsultation!['lab_tests'];
      if (labs is List) {
        for (var l in labs) {
          final str = l.toString();
          if (_standardLabs.containsKey(str)) {
            _standardLabs[str] = true;
          } else {
            _customLabs.add(str);
          }
        }
      } else if (labs is String) {
        try {
          final decoded = jsonDecode(labs);
          if (decoded is List) {
            for (var l in decoded) {
              final str = l.toString();
              if (_standardLabs.containsKey(str)) {
                _standardLabs[str] = true;
              } else {
                _customLabs.add(str);
              }
            }
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _fetchLatestVitals() async {
    try {
      final vitals = await _patientController.fetchLatestVitals(
        widget.appointment.patientId,
        appointmentId: widget.appointment.id,
      );
      if (vitals != null && mounted) {
        setState(() {
          _currentAppointment = _currentAppointment.copyWith(
            bloodPressureSystolic: vitals['blood_pressure_systolic'],
            bloodPressureDiastolic: vitals['blood_pressure_diastolic'],
            sugarLevel: double.tryParse(vitals['sugar_level']?.toString() ?? ''),
            temperature: double.tryParse(vitals['temperature']?.toString() ?? ''),
            reasonForVisit: vitals['reason_for_visit'],
          );
          _isLoadingVitals = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingVitals = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingVitals = false);
    }
  }

  Future<void> _fetchPreviousConsultations() async {
    try {
      final history = await _appointmentController.fetchConsultationsByPatient(widget.appointment.patientId);
      if (mounted) {
        setState(() {
          // exclude current consultation if editing
          _previousConsultations = history.where((c) => c['appointment_id'] != widget.appointment.id).toList();
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _addMedication() {
    if (_medNameController.text.trim().isNotEmpty) {
      setState(() {
        _medications.add({
          'name': _medNameController.text.trim(),
          'dosage': _dosageController.text.trim(),
          'frequency': _freqController.text.isEmpty ? '1-0-1' : _freqController.text,
          'duration': _durController.text.trim(),
        });
        _medNameController.clear();
        _dosageController.clear();
        _freqController.text = '1-0-1';
        _durController.clear();
      });
    }
  }

  List<String> getFinalOrderedLabs() {
    final List<String> result = [];
    _standardLabs.forEach((key, val) {
      if (val) result.add(key);
    });
    result.addAll(_customLabs);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    Widget buildHeader() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button above title
          InkWell(
            onTap: widget.onBack,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, color: AppTheme.primaryColor, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Back to Queue',
                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Header Title
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.initialConsultation != null 
                      ? 'Edit Consultation: ${_currentAppointment.patientName}'
                      : 'Consultation: ${_currentAppointment.patientName}',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Appt Date: ${_currentAppointment.appointmentDate} • Status: ${_currentAppointment.status}',
                    style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    if (isMobile) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildHeader(),
                const SizedBox(height: 24),
                _buildPatientInfoSummary(),
                const SizedBox(height: 16),
                _buildClinicalHistoryCard(),
                const SizedBox(height: 24),
                _buildConsultationForm(),
              ],
            ),
          ),
        ),
      );
    }

    // Desktop split layout
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildHeader(),
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Vitals and History
                    SizedBox(
                      width: 320,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildPatientInfoSummary(),
                            const SizedBox(height: 16),
                            _buildClinicalHistoryCard(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right Column: Active Consult Form (Scrollable)
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildConsultationForm(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientInfoSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.monitor_heart, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text('Nurse Vitals Intake', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingVitals)
            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else ...[
            _buildVitalRow('Blood Pressure', '${_currentAppointment.bloodPressureSystolic ?? '--'}/${_currentAppointment.bloodPressureDiastolic ?? '--'} mmHg', Icons.speed, Colors.blue.shade700),
            const SizedBox(height: 12),
            _buildVitalRow('Sugar Level', '${_currentAppointment.sugarLevel ?? '--'} mg/dL', Icons.bloodtype_outlined, Colors.red.shade700),
            const SizedBox(height: 12),
            _buildVitalRow('Temperature', '${_currentAppointment.temperature ?? '--'} °F', Icons.thermostat_outlined, Colors.orange.shade700),
          ],
          const Divider(height: 24),
          const Text('Chief Complaint', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            _currentAppointment.reasonForVisit ?? 'No complaints registered',
            style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildClinicalHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text('Clinical History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingHistory)
            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else if (_previousConsultations.isEmpty)
            const Text('No previous consultations found.', style: TextStyle(color: Colors.grey, fontSize: 12))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _previousConsultations.length,
              itemBuilder: (c, idx) {
                final hist = _previousConsultations[idx];
                final dateStr = hist['created_at'] != null 
                    ? DateFormat('dd/MM/yyyy').format(DateTime.parse(hist['created_at']))
                    : 'Past Visit';
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
                  child: ExpansionTile(
                    title: Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    subtitle: Text(hist['diagnosis']?.toString() ?? 'No diagnosis recorded', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                    childrenPadding: const EdgeInsets.all(10),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hist['symptoms'] != null && hist['symptoms'].toString().isNotEmpty) ...[
                        const Text('Symptoms:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        Text(hist['symptoms'].toString(), style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 6),
                      ],
                      if (hist['notes'] != null && hist['notes'].toString().isNotEmpty) ...[
                        const Text('Recommendations:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        Text(hist['notes'].toString(), style: const TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _saveConsultation() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _currentStep = 0);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final finalLabs = getFinalOrderedLabs();
      final data = {
        'appointment_id': widget.appointment.id,
        'patient_id': widget.appointment.patientId,
        'symptoms': _symptomsController.text.trim(),
        'diagnosis': _diagnosisController.text.trim(),
        'medications': _medications,
        'lab_tests': finalLabs,
        'pharmacy_status': _medications.isNotEmpty ? 'Notified' : 'Pending',
        'notes': _notesController.text.trim(),
      };

      if (widget.initialConsultation != null) {
        final int consulId = widget.initialConsultation!['id'];
        await _appointmentController.updateConsultation(consulId, data);
      } else {
        await _appointmentController.saveConsultation(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.initialConsultation != null 
              ? 'Consultation Updated Successfully!' 
              : 'Consultation Completed & Saved!'), 
            backgroundColor: Colors.green
          ),
        );
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildConsultationForm() {
    // Clamp the step to prevent bounds errors on hot reload state preservation
    int safeStep = _currentStep;
    if (safeStep < 0) safeStep = 0;
    if (safeStep > 3) safeStep = 3;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.primaryColor),
        ),
        child: Stepper(
          physics: const ClampingScrollPhysics(),
          currentStep: safeStep,
          onStepTapped: (step) => setState(() => _currentStep = step),
          onStepContinue: () {
            if (_currentStep < 3) {
              setState(() => _currentStep += 1);
            } else {
              _saveConsultation();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            }
          },
          controlsBuilder: (BuildContext context, ControlsDetails details) {
            final isLastStep = safeStep == 3;
            return Container(
              margin: const EdgeInsets.only(top: 24),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _isSaving ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSaving && isLastStep
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isLastStep ? (widget.initialConsultation != null ? 'Update Consultation' : 'Complete & Submit') : 'Continue', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: _isSaving ? null : details.onStepCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Back', style: TextStyle(color: AppTheme.textSecondaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Step 1: Clinical Assessment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor)),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextArea('Subjective Symptoms', _symptomsController, 'Describe clinical history, symptoms reported by patient...', required: true),
                  const SizedBox(height: 16),
                  _buildTextArea('Diagnosis / Impression', _diagnosisController, 'Enter the diagnostic decision or impression...', required: true),
                ],
              ),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.editing,
            ),
            Step(
              title: const Text('Step 2: Prescription Flow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor)),
              subtitle: const Text('Automatically sent to Pharmacy upon submission', style: TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMedicationInput(),
                  const SizedBox(height: 12),
                  _buildMedicationList(),
                ],
              ),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.editing,
            ),
            Step(
              title: const Text('Step 3: Lab Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor)),
              subtitle: const Text('Lab receives order directly upon submission', style: TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
              content: _buildLabOrdersSection(),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.editing,
            ),
            Step(
              title: const Text('Step 4: Finalize & Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor)),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextArea('Additional Clinical Notes / Advice', _notesController, 'Internal advice, follow-up instructions, review notes...'),
                ],
              ),
              isActive: _currentStep >= 3,
              state: _currentStep == 3 ? StepState.editing : StepState.indexed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextArea(String label, TextEditingController controller, String hint, {bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
            if (required) const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: 3,
          validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null : null,
          decoration: InputDecoration(
            hintText: hint,
            fillColor: AppTheme.backgroundColor,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildSmallField('Medication Name', _medNameController, 'e.g. Paracetamol'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSmallField('Dosage', _dosageController, 'e.g. 500mg'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Frequency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
                    const SizedBox(height: 6),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _freqController.text.isEmpty ? '1-0-1' : _freqController.text,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 12, color: Colors.black),
                          items: ['1-0-1', '1-0-0', '0-0-1', '1-1-1', 'Once daily', 'Twice daily', 'Thrice daily', 'As needed (PRN)']
                              .map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _freqController.text = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSmallField('Duration', _durController, 'e.g. 5 days'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton.icon(
              onPressed: _addMedication,
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Add Drug', style: TextStyle(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            fillColor: Colors.white,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.borderColor)),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationList() {
    if (_medications.isEmpty) return const SizedBox.shrink();
    return Column(
      children: _medications.asMap().entries.map((entry) {
        int idx = entry.key;
        Map<String, String> med = entry.value;
        final durStr = med['duration'] != null && med['duration']!.isNotEmpty ? ' for ${med['duration']}' : '';
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.medication, color: AppTheme.primaryColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${med['name']} - ${med['dosage']} (${med['frequency']})$durStr',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                onPressed: () => setState(() => _medications.removeAt(idx)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLabOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Standard Investigations:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: _standardLabs.keys.map((test) {
                  return SizedBox(
                    width: 220,
                    child: CheckboxListTile(
                      title: Text(test, style: const TextStyle(fontSize: 12)),
                      value: _standardLabs[test],
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _standardLabs[test] = v);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildSmallField('Other Custom Lab Test', _customLabController, 'e.g. Liver Function Test (LFT)'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_customLabController.text.trim().isEmpty) return;
                      setState(() {
                        _customLabs.add(_customLabController.text.trim());
                        _customLabController.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      backgroundColor: AppTheme.secondaryColor,
                    ),
                    child: const Text('Add Test', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
              if (_customLabs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _customLabs.map((l) {
                    return Chip(
                      label: Text(l, style: const TextStyle(fontSize: 10)),
                      deleteIcon: const Icon(Icons.close, size: 10),
                      onDeleted: () {
                        setState(() => _customLabs.remove(l));
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
