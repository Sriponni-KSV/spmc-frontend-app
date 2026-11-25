import 'package:flutter/material.dart';
import '../widgets/discharge_summary_preview_dialog.dart';

void printHospitalReceipt({
  required BuildContext context,
  required Map<String, dynamic> invoice,
  required List<dynamic> items,
  required List<dynamic> payments,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Printing is only supported on Web / Desktop at this time.'),
    ),
  );
}

void printDischargeSummary({
  required BuildContext context,
  required Map<String, dynamic> admission,
  required String finalDiagnosis,
  required String treatmentSummary,
  required String medicationPlan,
  String? dischargeInstructions,
  String? followUpDate,
}) {
  DischargeSummaryPreviewDialog.show(
    context,
    admission: admission,
    finalDiagnosis: finalDiagnosis,
    treatmentSummary: treatmentSummary,
    medicationPlan: medicationPlan,
    dischargeInstructions: dischargeInstructions,
    followUpDate: followUpDate,
  );
}

void triggerDischargeSummaryHtmlPrint({
  required BuildContext context,
  required Map<String, dynamic> admission,
  required String finalDiagnosis,
  required String treatmentSummary,
  required String medicationPlan,
  String? dischargeInstructions,
  String? followUpDate,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Printing is only supported on Web / Desktop at this time.'),
    ),
  );
}
