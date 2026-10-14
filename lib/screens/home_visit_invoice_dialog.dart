import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../models/home_visit_model.dart';
import '../utils/app_localizations.dart';
import '../utils/tamil_transliteration_helper.dart';
import '../utils/modal_history_helper.dart';
import '../utils/app_notification.dart';
import '../services/home_visit_service.dart';
import '../controllers/home_visit_controller.dart';

class HomeVisitInvoiceDialog extends StatefulWidget {
  final Map<String, dynamic> invoiceData;
  final HomeVisitModel visit;
  final VoidCallback? onCloseAndComplete;

  const HomeVisitInvoiceDialog({
    super.key,
    required this.invoiceData,
    required this.visit,
    this.onCloseAndComplete,
  });

  @override
  State<HomeVisitInvoiceDialog> createState() => _HomeVisitInvoiceDialogState();
}

class _HomeVisitInvoiceDialogState extends State<HomeVisitInvoiceDialog> {
  late Map<String, dynamic> _invoiceData;
  bool _isUpdatingFee = false;

  @override
  void initState() {
    super.initState();
    _invoiceData = Map<String, dynamic>.from(widget.invoiceData);
  }

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
      return 'வீட்டுப் பராமரிப்பு ஆலோசனை & அடிப்படை செவிலியர் கட்டணம் (Home Visit Fee)';
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

  bool _isConsultationFeeItem(String itemName) {
    final lower = itemName.toLowerCase();
    return lower.contains('consultation') && (lower.contains('fee') || lower.contains('care'));
  }

  Future<void> _showEditFeeDialog(BuildContext context, double currentFee) async {
    final feeCtrl = TextEditingController(
      text: currentFee > 0 ? currentFee.toStringAsFixed(0) : '500',
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: !_isUpdatingFee,
      builder: (editCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                editCtx.tr('edit_consultation_fee', fallback: 'Edit Consultation Fee'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editCtx.tr('consultation_fee_label', fallback: 'Home Visit Consultation & Basic Nursing Care Fee'),
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: feeCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: editCtx.tr('fee_amount_label', fallback: 'Fee Amount (₹)'),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      widthFactor: 0.0,
                      child: Text(
                        '₹',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return editCtx.tr('fee_required', fallback: 'Please enter consultation fee');
                  }
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed < 0 || parsed > 50000) {
                    return editCtx.tr('enter_valid_fee', fallback: 'Please enter a valid amount (₹0 - ₹50,000)');
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(editCtx).pop(),
            child: Text(editCtx.tr('cancel', fallback: 'Cancel')),
          ),
          ElevatedButton(
            style: AppTheme.primaryButton,
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              final newFee = double.tryParse(feeCtrl.text.trim()) ?? 500.0;
              Navigator.of(editCtx).pop();

              setState(() => _isUpdatingFee = true);
              try {
                final updatedData = await HomeVisitService().updateInvoiceConsultationFee(widget.visit.id, newFee);
                if (!mounted) return;
                setState(() {
                  _invoiceData = Map<String, dynamic>.from(updatedData);
                  _isUpdatingFee = false;
                });
                try {
                  final ctrl = Provider.of<HomeVisitController>(this.context, listen: false);
                  ctrl.fetchVisitDetails(widget.visit.id);
                  ctrl.fetchVisits();
                } catch (_) {}
                AppNotification.showSuccess(
                  this.context,
                  this.context.tr('fee_updated_success', fallback: 'Consultation fee updated successfully'),
                );
              } catch (e) {
                if (!mounted) return;
                setState(() => _isUpdatingFee = false);
                AppNotification.showError(
                  this.context,
                  e.toString().replaceAll('Exception: ', ''),
                );
              }
            },
            child: Text(editCtx.tr('save', fallback: 'Save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = Localizations.localeOf(context).languageCode == 'ta';
    final Map<String, dynamic> invoice = (_invoiceData['invoice'] is Map)
        ? Map<String, dynamic>.from(_invoiceData['invoice'])
        : Map<String, dynamic>.from(_invoiceData);
    final List<dynamic> items = (invoice['items'] as List<dynamic>?) ??
        (_invoiceData['items'] as List<dynamic>?) ??
        [];
    final String invoiceNumber = invoice['invoice_number'] ?? 'INV-HV-0000';
    final double totalAmount = (invoice['total_amount'] != null)
        ? double.tryParse(invoice['total_amount'].toString()) ?? 0.0
        : items.fold<double>(0.0, (acc, item) {
            final st = item['subtotal'] ?? ((item['quantity'] ?? 1) * (item['unit_price'] ?? 0.0));
            return acc + (double.tryParse(st.toString()) ?? 0.0);
          });
    final String status = invoice['payment_status'] ?? 'Unpaid';

    final patientDisplayName = TamilTransliterationHelper.formatName(
      widget.visit.patientName ?? 'N/A',
      isTamil: isTamil,
    );
    final attenderDisplayName = TamilTransliterationHelper.formatName(
      widget.visit.attenderName ?? 'Attender',
      isTamil: isTamil,
    );
    final nurseDisplayName = TamilTransliterationHelper.formatName(
      widget.visit.nurseName ?? 'Nurse',
      isTamil: isTamil,
    );

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      insetPadding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 650,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('home_visit_billing_invoice', fallback: 'Home Visit Billing Invoice'),
                        style: TextStyle(
                          fontSize: isMobile ? 15 : 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${context.tr('invoice_num_label', fallback: 'Invoice #:')} $invoiceNumber',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getTranslatedStatus(context, status),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: isMobile ? 24 : 32),

            // Patient & Attender Summary Card
            Container(
              padding: const EdgeInsets.all(14),
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
                      Expanded(child: _infoColumn(context.tr('patient_id_label', fallback: 'Patient ID'), widget.visit.patientDisplayId ?? 'N/A')),
                      Expanded(child: _infoColumn(context.tr('scheduled_date_label', fallback: 'Scheduled Date'), widget.visit.scheduledDate)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _infoColumn(context.tr('verified_attender_label', fallback: 'Verified Attender'), attenderDisplayName)),
                      Expanded(child: _infoColumn(context.tr('attender_relation_label', fallback: 'Attender Relation'), widget.visit.attenderRelation ?? 'Attender')),
                      Expanded(child: _infoColumn(context.tr('assigned_nurse_label', fallback: 'Assigned Nurse'), nurseDisplayName)),
                    ],
                  ),
                  if ((widget.visit.feedback != null && widget.visit.feedback!.trim().isNotEmpty) ||
                      (_invoiceData['visit'] is Map && _invoiceData['visit']['feedback'] != null && _invoiceData['visit']['feedback'].toString().trim().isNotEmpty)) ...[
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
                                (widget.visit.feedback != null && widget.visit.feedback!.trim().isNotEmpty)
                                    ? widget.visit.feedback!
                                    : _invoiceData['visit']['feedback'].toString(),
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

            // Itemized Charges Header with Edit Fee Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('itemized_service_care_charges', fallback: 'Itemized Service & Care Charges:'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.primaryColor,
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: Text(
                    context.tr('edit_consultation_fee', fallback: 'Edit Fee'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    double currentFee = 500.0;
                    for (final it in items) {
                      final itName = it['item_name']?.toString() ?? '';
                      if (_isConsultationFeeItem(itName)) {
                        currentFee = (it['unit_price'] != null)
                            ? double.tryParse(it['unit_price'].toString()) ?? 500.0
                            : 500.0;
                        break;
                      }
                    }
                    _showEditFeeDialog(context, currentFee);
                  },
                ),
              ],
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEDF2F7),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 5, child: Text(context.tr('service_item_description', fallback: 'Service / Item Description'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text(context.tr('qty_label', fallback: 'Qty'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 3, child: Text(context.tr('unit_price', fallback: 'Unit Price'), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                          Expanded(flex: 3, child: Text(context.tr('subtotal_header', fallback: 'Subtotal'), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = items[idx];
                          final itemName = item['item_name']?.toString() ?? 'Item';
                          final isFeeItem = _isConsultationFeeItem(itemName);
                          final qty = item['quantity'] ?? 1;
                          final unitPrice = (item['unit_price'] != null)
                              ? double.tryParse(item['unit_price'].toString()) ?? 0.0
                              : 0.0;
                          final subtotal = (item['subtotal'] != null)
                              ? double.tryParse(item['subtotal'].toString()) ?? 0.0
                              : (qty * unitPrice);

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _translateItemName(context, itemName),
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      if (isFeeItem)
                                        Tooltip(
                                          message: context.tr('edit_consultation_fee', fallback: 'Edit Fee'),
                                          child: InkWell(
                                            onTap: () => _showEditFeeDialog(context, unitPrice),
                                            borderRadius: BorderRadius.circular(4),
                                            child: Container(
                                              margin: const EdgeInsets.only(left: 6),
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Icon(
                                                Icons.edit_outlined,
                                                size: 14,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '$qty',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '₹${unitPrice.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '₹${subtotal.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
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
            const SizedBox(height: 14),

            // Total Amount Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('net_total_bill_amount', fallback: 'Net Total Bill Amount:'),
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dialog Close Button (52px high per Style Guide)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: AppTheme.dangerButton,
                onPressed: () {
                  ModalHistoryHelper.skipNextHistoryBack();
                  Navigator.of(context).pop();
                  if (widget.onCloseAndComplete != null) {
                    widget.onCloseAndComplete!();
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
