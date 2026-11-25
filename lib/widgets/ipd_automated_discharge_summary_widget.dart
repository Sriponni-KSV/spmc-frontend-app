import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../utils/app_theme.dart';
import '../utils/receipt_printer.dart';

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
          LayoutBuilder(
            builder: (context, constraints) {
              final Widget titleSection = Row(
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
                ],
              );

              final List<Widget> actionButtons = [
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
              ];

              if (widget.isMobile || constraints.maxWidth < 680) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: actionButtons,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleSection),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: actionButtons,
                  ),
                ],
              );
            },
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
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 10,
                children: [
                  if (!widget.isAlreadyDischarged) ...[
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
                    OutlinedButton.icon(
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Preview & Print'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _showPrintableReportDialog,
                    ),
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
                  ] else ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Preview & Print'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _showPrintableReportDialog,
                    ),
                  ],
                ],
              ),
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
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
          ),
        ),
      ],
    );
  }

  Future<void> _submitFinalDischarge() async {
    if (!_formKey.validateAndScroll()) return;

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
    printDischargeSummary(
      context: context,
      admission: widget.admission,
      finalDiagnosis: _finalDiagCtrl.text,
      treatmentSummary: _treatmentSumCtrl.text,
      medicationPlan: _medPlanCtrl.text,
      dischargeInstructions: _followUpCtrl.text,
      followUpDate: _followUpCtrl.text,
    );
  }
}
