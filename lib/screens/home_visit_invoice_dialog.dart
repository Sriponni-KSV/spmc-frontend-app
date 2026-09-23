import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/home_visit_model.dart';
import '../utils/app_localizations.dart';
import '../utils/tamil_transliteration_helper.dart';

class HomeVisitInvoiceDialog extends StatelessWidget {
  final Map<String, dynamic> invoiceData;
  final HomeVisitModel visit;
  final VoidCallback? onCloseAndComplete;

  const HomeVisitInvoiceDialog({
    super.key,
    required this.invoiceData,
    required this.visit,
    this.onCloseAndComplete,
  });

  String _getTranslatedStatus(BuildContext context, String status) {
    final s = status.toLowerCase().trim();
    if (s == 'paid') return context.tr('paid', fallback: 'Paid');
    if (s == 'unpaid') return context.tr('unpaid', fallback: 'Unpaid');
    if (s == 'pending') return context.tr('pending', fallback: 'Pending');
    return status;
  }

  String _translateFrequency(String freq) {
    final lower = freq.toLowerCase().trim();
    if (lower == 'once daily' || lower == '1 time daily' || lower == '1 - 0 - 0' || lower == 'od') {
      return 'தினமும் ஒரு முறை (Once Daily)';
    }
    if (lower == 'twice daily' || lower == '2 times daily' || lower == '1 - 0 - 1' || lower == 'bd') {
      return 'தினமும் இரு முறை (Twice Daily)';
    }
    if (lower == 'three times daily' || lower == '3 times daily' || lower == '1 - 1 - 1' || lower == 'tds') {
      return 'தினமும் மூன்று முறை (TDS)';
    }
    if (lower == 'four times daily' || lower == 'qid') {
      return 'தினமும் 4 முறை (QID)';
    }
    if (lower == 'as needed' || lower == 'sos') {
      return 'தேவைப்படும் போது (SOS)';
    }
    if (lower == 'stat' || lower == 'immediately') {
      return 'உடனடியாக (STAT)';
    }
    return freq;
  }

  String _translateItemName(BuildContext context, String name) {
    if (Localizations.localeOf(context).languageCode != 'ta') {
      return name;
    }
    final trimmed = name.trim();
    final lower = trimmed.toLowerCase();

    // 1. Home visit base consultation & nursing care fee
    if (lower.contains('home visit consultation') ||
        (lower.contains('basic nursing care') && lower.contains('fee')) ||
        lower == 'home visit consultation & basic nursing care fee') {
      return 'வீட்டுப் பராமரிப்பு ஆலோசனை & அடிப்படை நர்சிங் கட்டணம் (Home Visit Fee)';
    }

    // 2. Nail Trimming & Hygiene Care Activity
    if (lower.contains('nail trimming')) {
      return 'நகங்கள் வெட்டுதல் & சுகாதார பராமரிப்பு (Nail Trimming & Hygiene Care)';
    }

    // 3. Dressing Procedure with details
    if (lower.startsWith('dressing procedure')) {
      final parenMatch = RegExp(r'dressing procedure\s*(\(.*\))?', caseSensitive: false).firstMatch(trimmed);
      if (parenMatch != null && parenMatch.group(1) != null) {
        return 'கட்டு கட்டும் செயல்முறை ${parenMatch.group(1)}';
      }
      return 'கட்டு கட்டும் செயல்முறை (Dressing Procedure)';
    }

    // 4. Procedure: <Proc Name> (<Frequency>)
    if (lower.startsWith('procedure:')) {
      final content = trimmed.substring('procedure:'.length).trim();
      final match = RegExp(r'^(.*?)(?:\s*\((.*?)\))?$').firstMatch(content);
      if (match != null) {
        final rawProcName = match.group(1)?.trim() ?? content;
        final rawFreq = match.group(2)?.trim();
        final translatedProc = context.translateProcedure(rawProcName);
        if (rawFreq != null && rawFreq.isNotEmpty) {
          final translatedFreq = _translateFrequency(rawFreq);
          return 'செயல்முறை: $translatedProc ($translatedFreq)';
        }
        return 'செயல்முறை: $translatedProc';
      }
      return 'செயல்முறை: ${context.translateProcedure(content)}';
    }

    // 5. Medicine: <Med Name> (<Dosage>)
    if (lower.startsWith('medicine:')) {
      final content = trimmed.substring('medicine:'.length).trim();
      final match = RegExp(r'^(.*?)(?:\s*\((.*?)\))?$').firstMatch(content);
      if (match != null) {
        final rawMedName = match.group(1)?.trim() ?? content;
        final rawDosage = match.group(2)?.trim();
        final translatedMed = context.translateMedicine(rawMedName);
        if (rawDosage != null && rawDosage.isNotEmpty) {
          return 'மருந்து: $translatedMed ($rawDosage)';
        }
        return 'மருந்து: $translatedMed';
      }
      return 'மருந்து: ${context.translateMedicine(content)}';
    }

    // 6. Consumable: <Item Name>
    if (lower.startsWith('consumable:')) {
      final content = trimmed.substring('consumable:'.length).trim();
      return 'உபயோகப் பொருள்: ${context.translateConsumable(content)}';
    }

    // 7. General Fallbacks
    final cName = context.translateConsumable(trimmed);
    if (cName != trimmed) return cName;
    final pName = context.translateProcedure(trimmed);
    if (pName != trimmed) return pName;
    final mName = context.translateMedicine(trimmed);
    if (mName != trimmed) return mName;

    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = Localizations.localeOf(context).languageCode == 'ta';
    final Map<String, dynamic> invoice = (invoiceData['invoice'] is Map)
        ? Map<String, dynamic>.from(invoiceData['invoice'])
        : Map<String, dynamic>.from(invoiceData);
    final List<dynamic> items = (invoice['items'] as List<dynamic>?) ??
        (invoiceData['items'] as List<dynamic>?) ??
        [];
    final String invoiceNumber = invoice['invoice_number'] ?? 'INV-HV-0000';
    final double totalAmount = (invoice['total_amount'] != null)
        ? double.tryParse(invoice['total_amount'].toString()) ?? 0.0
        : 0.0;
    final String status = invoice['payment_status'] ?? 'Unpaid';

    final patientDisplayName = TamilTransliterationHelper.formatName(
      visit.patientName ?? 'N/A',
      isTamil: isTamil,
    );
    final attenderDisplayName = TamilTransliterationHelper.formatName(
      visit.attenderName ?? 'Attender',
      isTamil: isTamil,
    );
    final nurseDisplayName = TamilTransliterationHelper.formatName(
      visit.nurseName ?? 'Nurse',
      isTamil: isTamil,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 700),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('home_visit_billing_invoice', fallback: 'Home Visit Billing Invoice'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Text(
                          '${context.tr('invoice_num_label', fallback: 'Invoice #:')} $invoiceNumber',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getTranslatedStatus(context, status),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // Patient & Attender Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _infoColumn(context.tr('patient_name_label', fallback: 'Patient Name'), patientDisplayName)),
                      Expanded(child: _infoColumn(context.tr('patient_id_label', fallback: 'Patient ID'), visit.patientDisplayId ?? 'N/A')),
                      Expanded(child: _infoColumn(context.tr('scheduled_date_label', fallback: 'Scheduled Date'), visit.scheduledDate)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _infoColumn(context.tr('verified_attender_label', fallback: 'Verified Attender'), attenderDisplayName)),
                      Expanded(child: _infoColumn(context.tr('attender_relation_label', fallback: 'Attender Relation'), visit.attenderRelation ?? 'Attender')),
                      Expanded(child: _infoColumn(context.tr('assigned_nurse_label', fallback: 'Assigned Nurse'), nurseDisplayName)),
                    ],
                  ),
                  if ((visit.feedback != null && visit.feedback!.trim().isNotEmpty) ||
                      (invoiceData['visit'] is Map && invoiceData['visit']['feedback'] != null && invoiceData['visit']['feedback'].toString().trim().isNotEmpty)) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.record_voice_over_outlined, size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('visit_attender_feedback', fallback: 'Visit & Attender Feedback'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (visit.feedback != null && visit.feedback!.trim().isNotEmpty)
                                    ? visit.feedback!
                                    : invoiceData['visit']['feedback'].toString(),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF334155),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              context.tr('itemized_service_care_charges', fallback: 'Itemized Service & Care Charges:'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),

            // Itemized Items Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEDF2F7),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(context.tr('service_item_description', fallback: 'Service / Item Description'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Expanded(flex: 1, child: Text(context.tr('qty_label', fallback: 'Qty'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Expanded(flex: 1, child: Text(context.tr('unit_price', fallback: 'Unit Price'), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Expanded(flex: 1, child: Text(context.tr('subtotal_header', fallback: 'Subtotal'), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = items[idx];
                          final qty = item['quantity'] ?? 1;
                          final unitPrice = (item['unit_price'] != null)
                              ? double.tryParse(item['unit_price'].toString()) ?? 0.0
                              : 0.0;
                          final subtotal = (item['subtotal'] != null)
                              ? double.tryParse(item['subtotal'].toString()) ?? 0.0
                              : (qty * unitPrice);

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    _translateItemName(context, item['item_name'] ?? 'Item'),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '$qty',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '₹${unitPrice.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '₹${subtotal.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Total Amount Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('net_total_bill_amount', fallback: 'Net Total Bill Amount:'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Text(
                    '₹${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Dialog Close Button (52px high per Style Guide)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: AppTheme.dangerButton,
                onPressed: () {
                  Navigator.of(context).pop();
                  if (onCloseAndComplete != null) {
                    onCloseAndComplete!();
                  }
                },
                child: Text(context.tr('close_and_complete', fallback: 'Close & Complete'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }
}
