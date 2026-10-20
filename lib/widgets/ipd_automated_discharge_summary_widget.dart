import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../utils/app_theme.dart';

/// Automated Inpatient Discharge Summary Generator & Clinical Report Widget
class IpdAutomatedDischargeSummaryWidget extends StatefulWidget {
  final Map<String, dynamic> admission;
  final bool isMobile;
  final bool isAlreadyDischarged;
  final Future<Map<String, dynamic>> Function() onFetchDischargeData;
  final Future<void> Function({
    required String finalDiagnosis,
    required String treatmentSummary,
    required String medicationPlan,
    String? dischargeInstructions,
    String? followUpDate,
  }) onFinalizeDischarge;

  const IpdAutomatedDischargeSummaryWidget({
    super.key,
    required this.admission,
    required this.isMobile,
    required this.isAlreadyDischarged,
    required this.onFetchDischargeData,
    required this.onFinalizeDischarge,
  });

  @override
  State<IpdAutomatedDischargeSummaryWidget> createState() => _IpdAutomatedDischargeSummaryWidgetState();
}

class _IpdAutomatedDischargeSummaryWidgetState extends State<IpdAutomatedDischargeSummaryWidget> {
  final _formKey = GlobalKey<FormState>();
  final _finalDiagCtrl = TextEditingController();
  final _treatmentSumCtrl = TextEditingController();
  final _medPlanCtrl = TextEditingController();
  final _followUpCtrl = TextEditingController();

  bool _isGenerating = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _aggregatedData;

  @override
  void initState() {
    super.initState();
    _loadInitialOrSavedSummary();
  }

  void _loadInitialOrSavedSummary() {
    final adm = widget.admission;
    _finalDiagCtrl.text = adm['final_diagnosis'] ?? adm['diagnosis'] ?? '';
    _treatmentSumCtrl.text = adm['treatment_summary'] ?? adm['discharge_summary'] ?? '';
    _medPlanCtrl.text = adm['medication_plan'] ?? '';
    _followUpCtrl.text = adm['discharge_instructions'] ?? '';
  }

  Future<void> _handleAutoGenerate() async {
    setState(() => _isGenerating = true);
    try {
      final data = await widget.onFetchDischargeData();
      setState(() {
        _aggregatedData = data;
        final suggested = data['suggested'] as Map<String, dynamic>? ?? {};

        if (suggested['final_diagnosis'] != null && suggested['final_diagnosis'].toString().isNotEmpty) {
          _finalDiagCtrl.text = suggested['final_diagnosis'];
        }
        if (suggested['treatment_summary'] != null && suggested['treatment_summary'].toString().isNotEmpty) {
          _treatmentSumCtrl.text = suggested['treatment_summary'];
        }
        if (suggested['medication_plan'] != null && suggested['medication_plan'].toString().isNotEmpty) {
          _medPlanCtrl.text = suggested['medication_plan'];
        }
        if (suggested['follow_up_instructions'] != null && suggested['follow_up_instructions'].toString().isNotEmpty) {
          _followUpCtrl.text = suggested['follow_up_instructions'];
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Discharge summary successfully auto-generated from all clinical records!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating summary: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header & Generator Action ───────────────────────────────
              _buildTopHeader(),
              const SizedBox(height: 20),

              // ─── Form Card ───────────────────────────────────────────────
              _buildDischargeFormCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Top Header ──────────────────────────────────────────────────────────

  Widget _buildTopHeader() {
    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (widget.isAlreadyDischarged ? Colors.grey : AppTheme.primaryColor).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.isAlreadyDischarged ? Icons.verified_outlined : Icons.auto_awesome,
                  color: widget.isAlreadyDischarged ? Colors.grey.shade700 : AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isAlreadyDischarged
                          ? 'Inpatient Discharge Summary (Finalized)'
                          : 'Automated Inpatient Discharge Summary Generator',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Aggregates admission history, daily SOAP rounds, completed investigations, procedures & medications into a certified summary.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (!widget.isAlreadyDischarged)
                ElevatedButton.icon(
                  icon: _isGenerating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(_isGenerating ? 'Generating...' : 'Auto-Generate Summary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isGenerating ? null : _handleAutoGenerate,
                ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.print_outlined, size: 16),
                label: const Text('Preview & Print'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showPrintableReportDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Main Form Card ──────────────────────────────────────────────────────

  Widget _buildDischargeFormCard() {
    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 18 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.isAlreadyDischarged ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isAlreadyDischarged ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isAlreadyDischarged ? Icons.check_circle_outline : Icons.info_outline,
                    color: widget.isAlreadyDischarged ? const Color(0xFF059669) : Colors.orange.shade800,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.isAlreadyDischarged
                          ? 'This patient has been formally discharged. All clinical records and discharge summaries are preserved in history.'
                          : 'Review and verify the auto-generated clinical content below before confirming discharge. Finalizing discharge releases the allocated bed.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.isAlreadyDischarged ? const Color(0xFF065F46) : Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 1. FINAL DIAGNOSIS
            _buildFieldHeader('1. Final Diagnosis at Discharge *', Icons.medical_services_outlined),
            const SizedBox(height: 8),
            TextFormField(
              controller: _finalDiagCtrl,
              maxLines: 2,
              enabled: !widget.isAlreadyDischarged,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                hintText: 'Enter confirmed primary diagnosis and key comorbidities...',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Final diagnosis is required' : null,
            ),
            const SizedBox(height: 22),

            // 2. HOSPITAL COURSE & TREATMENT SUMMARY
            _buildFieldHeader('2. Hospital Course & Treatment Summary *', Icons.healing_outlined),
            const SizedBox(height: 8),
            TextFormField(
              controller: _treatmentSumCtrl,
              maxLines: 6,
              enabled: !widget.isAlreadyDischarged,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                hintText: 'Clinical course during admission, procedures performed, response to therapy, lab progression, and vitals stability at discharge...',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Treatment summary is required' : null,
            ),
            const SizedBox(height: 22),

            // 3. DISCHARGE MEDICATIONS & FOLLOW-UP ADVICE
            _buildFieldHeader('3. Discharge Medications, Diet & Instructions *', Icons.medication_outlined),
            const SizedBox(height: 8),
            TextFormField(
              controller: _medPlanCtrl,
              maxLines: 6,
              enabled: !widget.isAlreadyDischarged,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                hintText: 'Take-home medications (Dosage, Frequency, Duration), Dietary instructions, wound care advice, and emergency warning signs...',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Medication plan and instructions are required' : null,
            ),
            const SizedBox(height: 22),

            // 4. FOLLOW-UP REVIEW INSTRUCTIONS
            _buildFieldHeader('4. Follow-Up Plan & Review Date', Icons.event_repeat_rounded),
            const SizedBox(height: 8),
            TextFormField(
              controller: _followUpCtrl,
              maxLines: 2,
              enabled: !widget.isAlreadyDischarged,
              decoration: InputDecoration(
                hintText: 'e.g. Review in OPD on Monday with Dr. Attending Consultant for suture removal / checkup...',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 30),

            // Action Buttons
            if (!widget.isAlreadyDischarged)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset Form'),
                    style: AppTheme.cancelButton,
                    onPressed: () {
                      _finalDiagCtrl.clear();
                      _treatmentSumCtrl.clear();
                      _medPlanCtrl.clear();
                      _followUpCtrl.clear();
                    },
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.logout, color: Colors.white, size: 16),
                    label: Text(_isSubmitting ? 'Finalizing...' : 'Finalize & Discharge Patient'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.dangerColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSubmitting ? null : _submitFinalDischarge,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
        ),
      ],
    );
  }

  Future<void> _submitFinalDischarge() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Patient Discharge?'),
        content: const Text(
          'This will finalize the discharge summary, mark the inpatient admission as Discharged, and release the allocated bed to Cleaning/Available status.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Discharge', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.onFinalizeDischarge(
        finalDiagnosis: _finalDiagCtrl.text.trim(),
        treatmentSummary: _treatmentSumCtrl.text.trim(),
        medicationPlan: _medPlanCtrl.text.trim(),
        dischargeInstructions: _followUpCtrl.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Discharge error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Printable Summary Report Sheet ──────────────────────────────────────

  void _showPrintableReportDialog() {
    final adm = widget.admission;
    final patientName = (adm['patient_name'] ?? 'Patient').toString();
    final patientDisplayId = (adm['patient_display_id'] ?? adm['patient_id'] ?? '--').toString();
    final ageGender = '${adm['patient_age'] ?? '--'} yrs / ${adm['patient_gender'] ?? '--'}';
    final admDate = adm['admission_date'] != null
        ? DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.parse(adm['admission_date']).toLocal())
        : '--';
    final dischDate = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());
    final doctor = (adm['doctor_name'] ?? 'Consultant').toString();
    final bedNum = (adm['bed_number'] ?? '--').toString();
    final ward = (adm['ward_type'] ?? 'General Ward').toString();

    showDialog(
      context: context,
      builder: (modalCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 800,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                // Modal Top Bar
                Row(
                  children: [
                    const Text('Official Discharge Summary Document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Print Document'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sent to clinic printer / browser print dialog')),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalCtx)),
                  ],
                ),
                const Divider(height: 20),

                // Printable Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hospital Letterhead
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  'SRI PONNI MULTISPECIALITY CLINIC',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor, letterSpacing: 1.1),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Inpatient Department • Comprehensive Discharge Summary',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Govt Reg No: SPMC-TN-2026 • Phone: +91 44 2833 4455',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 24, thickness: 1.5),

                          // Patient Demographics Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _buildDocCell('Patient Name:', patientName, flex: 2),
                                    _buildDocCell('UHID / ID:', patientDisplayId, flex: 1),
                                    _buildDocCell('Age / Sex:', ageGender, flex: 1),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildDocCell('Admission Date:', admDate, flex: 2),
                                    _buildDocCell('Discharge Date:', dischDate, flex: 2),
                                    _buildDocCell('Bed / Ward:', 'Bed $bedNum ($ward)', flex: 1),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildDocCell('Attending Consultant:', 'Dr. $doctor', flex: 2),
                                    _buildDocCell('Department:', adm['department'] ?? 'General Medicine', flex: 2),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Document Sections
                          _buildReportSectionTitle('FINAL DIAGNOSIS'),
                          Text(_finalDiagCtrl.text.isNotEmpty ? _finalDiagCtrl.text : '--', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 14),

                          _buildReportSectionTitle('HOSPITAL COURSE & CLINICAL SUMMARY'),
                          Text(_treatmentSumCtrl.text.isNotEmpty ? _treatmentSumCtrl.text : '--', style: const TextStyle(fontSize: 12, height: 1.45)),
                          const SizedBox(height: 14),

                          _buildReportSectionTitle('DISCHARGE MEDICATIONS & INSTRUCTIONS'),
                          Text(_medPlanCtrl.text.isNotEmpty ? _medPlanCtrl.text : '--', style: const TextStyle(fontSize: 12, height: 1.45)),
                          const SizedBox(height: 14),

                          if (_followUpCtrl.text.isNotEmpty) ...[
                            _buildReportSectionTitle('FOLLOW-UP ADVICE'),
                            Text(_followUpCtrl.text, style: const TextStyle(fontSize: 12, height: 1.45)),
                            const SizedBox(height: 14),
                          ],

                          if (_aggregatedData != null) ...[
                            _buildReportSectionTitle('CLINICAL RECORDS SYNTHESIZED'),
                            Text(
                              'Synthesized from ${(_aggregatedData!['progress_notes'] ?? _aggregatedData!['soap_rounds'])?.length ?? 0} Daily Doctor Rounds, ${_aggregatedData!['lab_orders']?.length ?? 0} Laboratory Investigations, ${(_aggregatedData!['ot_cases'] ?? _aggregatedData!['surgical_cases'])?.length ?? 0} Surgical Cases, and Inpatient MAR records.',
                              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 14),
                          ],

                          const SizedBox(height: 30),
                          const Divider(height: 1),
                          const SizedBox(height: 20),

                          // Doctor Signature Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Prepared by: Clinical Nursing Team', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  Text('Hospital Seal & Verification', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Dr. $doctor', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text('Attending Inpatient Physician', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  const SizedBox(height: 2),
                                  Text('Signature & Registration Stamp', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocCell(String label, String value, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: RichText(
        text: TextSpan(
          text: '$label ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade700),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor, letterSpacing: 0.5),
      ),
    );
  }
}
