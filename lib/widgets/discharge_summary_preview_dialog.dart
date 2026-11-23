import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../utils/receipt_printer.dart';

/// In-page, high-fidelity print preview dialog for IPD Discharge Summary.
/// Renders an authentic A4 printable page preview directly within the existing view,
/// without opening new browser tabs, and provides immediate single-click printing.
class DischargeSummaryPreviewDialog extends StatelessWidget {
  final Map<String, dynamic> admission;
  final String finalDiagnosis;
  final String treatmentSummary;
  final String medicationPlan;
  final String? dischargeInstructions;
  final String? followUpDate;

  const DischargeSummaryPreviewDialog({
    super.key,
    required this.admission,
    required this.finalDiagnosis,
    required this.treatmentSummary,
    required this.medicationPlan,
    this.dischargeInstructions,
    this.followUpDate,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> admission,
    required String finalDiagnosis,
    required String treatmentSummary,
    required String medicationPlan,
    String? dischargeInstructions,
    String? followUpDate,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DischargeSummaryPreviewDialog(
        admission: admission,
        finalDiagnosis: finalDiagnosis,
        treatmentSummary: treatmentSummary,
        medicationPlan: medicationPlan,
        dischargeInstructions: dischargeInstructions,
        followUpDate: followUpDate,
      ),
    );
  }

  void _triggerPrint(BuildContext context) {
    triggerDischargeSummaryHtmlPrint(
      context: context,
      admission: admission,
      finalDiagnosis: finalDiagnosis,
      treatmentSummary: treatmentSummary,
      medicationPlan: medicationPlan,
      dischargeInstructions: dischargeInstructions,
      followUpDate: followUpDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final patientName = (admission['patient_name'] ?? 'Patient').toString();
    final patientDisplayId = (admission['patient_display_id'] ?? admission['patient_id'] ?? '--').toString();
    final age = admission['patient_age'] != null ? '${admission['patient_age']} Yrs' : '--';
    final gender = (admission['patient_gender'] ?? '--').toString();
    final doctor = (admission['doctor_name'] ?? 'Attending Consultant').toString();
    final bedNum = (admission['bed_number'] ?? '--').toString();
    final ward = (admission['ward_type'] ?? 'General Ward').toString();

    String admDate = '--';
    if (admission['admission_date'] != null) {
      final parsed = DateTime.tryParse(admission['admission_date'].toString());
      if (parsed != null) {
        admDate = DateFormat('dd/MM/yyyy hh:mm a').format(parsed.toLocal());
      } else {
        admDate = admission['admission_date'].toString();
      }
    }
    final dischDate = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());

    final cleanDiagnosis = finalDiagnosis.trim().isNotEmpty ? finalDiagnosis.trim() : 'Under Investigation / Clinical Review';
    final cleanTreatment = treatmentSummary.trim().isNotEmpty
        ? treatmentSummary.trim()
        : 'Patient received in-hospital supportive and medical management as per clinical protocol.';
    final cleanMeds = medicationPlan.trim().isNotEmpty ? medicationPlan.trim() : 'Continue current prescribed oral medications.';
    final cleanInstructions = (dischargeInstructions != null && dischargeInstructions!.trim().isNotEmpty)
        ? dischargeInstructions!.trim()
        : 'Take adequate rest and maintain hydration. Avoid heavy physical activity for 7 days. Return to emergency if fever or severe pain develops.';
    final cleanFollowUp = (followUpDate != null && followUpDate!.trim().isNotEmpty) ? followUpDate!.trim() : 'Review after 5-7 days or SOS.';

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 32,
        vertical: isCompact ? 16 : 24,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 920),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Toolbar / Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.print_outlined, color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discharge Summary - Print Preview',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Official Inpatient Record • Sri Ponni Medical Center',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _triggerPrint(context),
                    icon: const Icon(Icons.print, size: 16, color: Colors.white),
                    label: const Text(
                      'Print Document',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Scrollable Print Document Canvas
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 28,
                  vertical: 20,
                ),
                child: Center(
                  child: Container(
                    width: 780,
                    padding: EdgeInsets.all(isCompact ? 16 : 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hospital Header Table/Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/image/full_logo.png',
                              height: 52,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.local_hospital,
                                size: 48,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SRI PONNI MEDICAL CENTER',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF065D96),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Inpatient Department • Comprehensive Discharge Summary',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF475569),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Govt Reg No: SPMC-TN-2026 • 24x7 Helpline: +91 44 2833 4455',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: const Text(
                                'DISCHARGE SUMMARY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF166534),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        const Divider(thickness: 2, color: Color(0xFF065D96)),
                        const SizedBox(height: 14),

                        // Demographics Box
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Wrap(
                            spacing: 24,
                            runSpacing: 10,
                            children: [
                              _buildMetaItem('Patient Name', patientName, width: 220),
                              _buildMetaItem('UHID / ID', patientDisplayId, width: 220),
                              _buildMetaItem('Age / Gender', '$age / $gender', width: 220),
                              _buildMetaItem('Admission Date', admDate, width: 220),
                              _buildMetaItem('Discharge Date', dischDate, width: 220),
                              _buildMetaItem('Consultant', 'Dr. $doctor', width: 220),
                              _buildMetaItem('Ward / Bed', '$ward (Bed $bedNum)', width: 220),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Section 1: Final Diagnosis
                        _buildSectionHeader('1. Final Diagnosis'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Text(
                            cleanDiagnosis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB91C1C),
                              height: 1.4,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Section 2: Hospital Course & Treatment Summary
                        _buildSectionHeader('2. Hospital Course & Treatment Summary'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Text(
                            cleanTreatment,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF1E293B),
                              height: 1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Section 3: Medication Plan
                        _buildSectionHeader('3. Discharge Medication Plan'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Text(
                            cleanMeds,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF14532D),
                              height: 1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Section 4: Discharge Instructions
                        _buildSectionHeader('4. Discharge Instructions & Warning Signs'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Text(
                            cleanInstructions,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF1E293B),
                              height: 1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Section 5: Follow-Up Plan
                        _buildSectionHeader('5. Follow-Up Plan and Review'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Text(
                            cleanFollowUp,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                              height: 1.4,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Footer / Signatures
                        Container(
                          padding: const EdgeInsets.only(top: 16),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Color(0xFFCBD5E1), style: BorderStyle.solid)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• This document serves as the official inpatient discharge summary.',
                                      style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '• In case of acute medical emergencies, report immediately to our 24x7 Casualty.',
                                      style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 200,
                                child: Column(
                                  children: [
                                    Container(
                                      height: 1,
                                      color: const Color(0xFF0F172A),
                                      margin: const EdgeInsets.only(bottom: 6),
                                    ),
                                    Text(
                                      'Dr. $doctor',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const Text(
                                      'Consultant Physician / Surgeon',
                                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 4),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF065D96),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, {double? width}) {
    final content = RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: content);
    }
    return content;
  }
}
