import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../models/appointment_model.dart';
import '../widgets/nurse_widgets.dart';
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
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<Map<String, String>> _medications = [];
  
  final TextEditingController _medNameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _freqController = TextEditingController();

  final PatientController _patientController = PatientController();
  final AppointmentController _appointmentController = AppointmentController();
  late AppointmentModel _currentAppointment;
  bool _isLoadingVitals = true;

  @override
  void initState() {
    super.initState();
    _currentAppointment = widget.appointment;
    _fetchLatestVitals();
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
            });
          }
        }
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


  void _addMedication() {
    if (_medNameController.text.isNotEmpty) {
      setState(() {
        _medications.add({
          'name': _medNameController.text,
          'dosage': _dosageController.text,
          'frequency': _freqController.text,
        });
        _medNameController.clear();
        _dosageController.clear();
        _freqController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    if (isMobile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
                      'Back to Dashboard',
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
            const SizedBox(height: 16),

            // Header Title
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.initialConsultation != null 
                    ? 'Edit Consultation: ${_currentAppointment.patientName}'
                    : 'Consultation: ${_currentAppointment.patientName}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentAppointment.appointmentDate,
                  style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildPatientInfoSummary(),
            const SizedBox(height: 24),
            _buildConsultationForm(),
          ],
        ),
      );
    }

    // Desktop: Vitals stay fixed on the left, while findings form scrolls on the right
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
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
                    'Back to Dashboard',
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
          const SizedBox(height: 16),

          // Header Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialConsultation != null 
                  ? 'Edit Consultation: ${_currentAppointment.patientName}'
                  : 'Consultation: ${_currentAppointment.patientName}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 4),
              Text(
                _currentAppointment.appointmentDate,
                style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Main View Split Layout (Takes available height dynamically)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Vitals Card (Fixed)
                SizedBox(
                  width: 320,
                  child: _buildPatientInfoSummary(),
                ),
                const SizedBox(width: 24),
                // Clinical Findings Form (Scrollable)
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
    );
  }

  Widget _buildPatientInfoSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Patient Vitals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          if (_isLoadingVitals)
            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else ...[
            _buildVitalRow('Blood Pressure', '${_currentAppointment.bloodPressureSystolic ?? '--'}/${_currentAppointment.bloodPressureDiastolic ?? '--'} mmHg', Icons.speed),
            const SizedBox(height: 12),
            _buildVitalRow('Sugar Level', '${_currentAppointment.sugarLevel ?? '--'} mg/dL', Icons.bloodtype_outlined),
            const SizedBox(height: 12),
            _buildVitalRow('Temperature', '${_currentAppointment.temperature ?? '--'} °F', Icons.thermostat_outlined),
          ],
          const Divider(height: 32),
          const Text('Admission Reason', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            _currentAppointment.reasonForVisit ?? 'No reason specified',
            style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildConsultationForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Clinical Findings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
          const SizedBox(height: 24),
          _buildTextArea('Subjective Symptoms', _symptomsController, 'e.g. Headache for 2 days, chest pain...'),
          const SizedBox(height: 16),
          _buildTextArea('Diagnosis / Impression', _diagnosisController, 'e.g. Upper Respiratory Tract Infection'),
          const SizedBox(height: 32),
          
          const Text('Medications & Prescription', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
          const SizedBox(height: 16),
          _buildMedicationInput(),
          const SizedBox(height: 16),
          _buildMedicationList(),
          
          const SizedBox(height: 32),
          _buildTextArea('Additional Notes', _notesController, 'Internal notes or follow-up instructions...'),
          const SizedBox(height: 32),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () async {
                  // All fields are optional as per user request

                  setState(() => _isLoadingVitals = true);
                  try {
                    final data = {
                      'appointment_id': widget.appointment.id,
                      'patient_id': widget.appointment.patientId,
                      'symptoms': _symptomsController.text,
                      'diagnosis': _diagnosisController.text,
                      'medications': _medications,
                      'notes': _notesController.text,
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
                            : 'Consultation Saved Successfully!'), 
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
                    if (mounted) setState(() => _isLoadingVitals = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(200, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: _isLoadingVitals 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      widget.initialConsultation != null 
                        ? 'Update Consultation' 
                        : 'Complete Consultation & Save', 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
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
              Expanded(flex: 2, child: _buildSmallField('Medication Name', _medNameController)),
              const SizedBox(width: 8),
              Expanded(child: _buildSmallField('Dosage', _dosageController)),
              const SizedBox(width: 8),
              Expanded(child: _buildSmallField('Freq.', _freqController)),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: TextButton.icon(
              onPressed: _addMedication,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add to Prescription'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: label,
            isDense: true,
            fillColor: Colors.white,
            filled: true,
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
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.medication, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${med['name']} - ${med['dosage']} (${med['frequency']})',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () => setState(() => _medications.removeAt(idx)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
