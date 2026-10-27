import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../models/home_visit_model.dart';
import '../utils/modal_history_helper.dart';
import '../utils/app_notification.dart';
import '../services/home_visit_service.dart';
import '../controllers/home_visit_controller.dart';
import '../controllers/billing_controller.dart';
import '../utils/receipt_printer.dart';

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
  bool _isSyncing = false;
  bool _showPaymentForm = false;
  bool _isSubmittingPayment = false;
  String _payMode = 'Cash';

  final TextEditingController _collectAmtCtrl = TextEditingController();
  final TextEditingController _collectRefCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _invoiceData = Map<String, dynamic>.from(widget.invoiceData);
  }

  @override
  void dispose() {
    _collectAmtCtrl.dispose();
    _collectRefCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  String _getStatusText(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'paid') return 'Paid';
    if (s == 'unpaid') return 'Unpaid';
    if (s == 'pending') return 'Pending';
    if (s == 'partially paid') return 'Partially Paid';
    return status;
  }

  String _cleanEnglishItemName(String name) {
    if (name.trim().isEmpty) return name;
    final parenMatch = RegExp(r'\(([^)]+)\)').firstMatch(name);
    if (parenMatch != null) {
      final insideParen = parenMatch.group(1)!.trim();
      if (RegExp(r'[a-zA-Z]').hasMatch(insideParen) && !RegExp(r'[\u0B80-\u0BFF]').hasMatch(insideParen)) {
        if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(name)) {
          final prefix = name.contains(':') ? '${name.split(':').first}: ' : '';
          return '$prefix$insideParen';
        }
      }
    }
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(name)) {
      final stripped = name.replaceAll(RegExp(r'[\u0B80-\u0BFF]'), '').trim();
      if (stripped.isNotEmpty && RegExp(r'[a-zA-Z]').hasMatch(stripped)) {
        return stripped.replaceAll(RegExp(r'^[^\w]+|[^\w)]+$'), '').trim();
      }
    }
    return name;
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
              child: const Text(
                'Edit Consultation Fee',
                style: TextStyle(
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
              const Text(
                'Home Visit Consultation & Basic Nursing Care Fee',
                style: TextStyle(fontSize: 13, color: Colors.black87),
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
                  labelText: 'Fee Amount (₹)',
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
                    return 'Please enter consultation fee';
                  }
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed < 0 || parsed > 50000) {
                    return 'Please enter a valid amount (₹0 - ₹50,000)';
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
            child: const Text('Cancel'),
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
                  'Consultation fee updated successfully',
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncBillItems() async {
    setState(() => _isSyncing = true);
    try {
      final updatedData = await HomeVisitService().generateInvoice(
        widget.visit.id,
        forceRegenerate: true,
      );
      if (!mounted) return;
      setState(() {
        _invoiceData = Map<String, dynamic>.from(updatedData);
        _isSyncing = false;
      });
      try {
        final ctrl = Provider.of<HomeVisitController>(context, listen: false);
        ctrl.fetchVisitDetails(widget.visit.id);
        ctrl.fetchVisits();
      } catch (_) {}
      AppNotification.showSuccess(
        context,
        'Invoice synchronized with latest visit care records!',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSyncing = false);
      AppNotification.showError(
        context,
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> _submitPaymentRecord(int invoiceId, double balanceDue) async {
    final amtText = _collectAmtCtrl.text.trim();
    final double? amt = double.tryParse(amtText);
    if (amt == null || amt <= 0) {
      AppNotification.showError(context, 'Please enter a valid payment amount greater than zero');
      return;
    }
    final double disc = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;

    setState(() => _isSubmittingPayment = true);
    try {
      await BillingController().recordPayment(
        invoiceId: invoiceId,
        amount: amt,
        paymentMode: _payMode,
        transactionReference: _collectRefCtrl.text.trim(),
        discount: disc > 0 ? disc : null,
      );

      // Reload fresh invoice details
      final refreshed = await HomeVisitService().getInvoiceForVisit(widget.visit.id);
      if (!mounted) return;
      setState(() {
        _invoiceData = Map<String, dynamic>.from(refreshed);
        _showPaymentForm = false;
        _isSubmittingPayment = false;
        _collectAmtCtrl.clear();
        _collectRefCtrl.clear();
        _discountCtrl.text = '0';
      });

      try {
        final ctrl = Provider.of<HomeVisitController>(context, listen: false);
        ctrl.fetchVisitDetails(widget.visit.id);
        ctrl.fetchVisits();
      } catch (_) {}

      AppNotification.showSuccess(
        context,
        'Payment recorded and invoice updated successfully!',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingPayment = false);
      AppNotification.showError(
        context,
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void _showPrintReceiptSheet(
    BuildContext context,
    Map<String, dynamic> invoice,
    List<dynamic> items,
    double netAmount,
    double paidAmount,
    double balanceDue,
  ) {
    final dateStr = invoice['created_at'] != null
        ? DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(invoice['created_at']).toLocal())
        : DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      builder: (pCtx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.print, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('Print Bill & Official Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(pCtx)),
            ],
          ),
          content: SingleChildScrollView(
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hospital Header with Logo
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Image.asset(
                          'assets/image/full_logo.png',
                          height: 48,
                          width: 80,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, stack) => Image.asset(
                            'assets/image/sriPonniLogo.png',
                            height: 48,
                            width: 48,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SRI PONNI MEDICAL CENTRE',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5, color: AppTheme.primaryColor),
                            ),
                            SizedBox(height: 2),
                            Text('Home Health Care & Nursing Division', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black87)),
                            SizedBox(height: 2),
                            Text('Trichy Main Road, Namakkal, Tamil Nadu - 637001', style: TextStyle(fontSize: 10, color: Colors.black54)),
                            Text('Phone: +91 98427 34567 | GSTIN: 33AAAAA0000A1Z5', style: TextStyle(fontSize: 10, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, thickness: 1.2),
                  // Bill Metadata
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Invoice: ${invoice['invoice_number'] ?? 'INV-HV'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      Text('Date: $dateStr', style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Patient: ${widget.visit.patientName ?? "N/A"} (${widget.visit.patientDisplayId ?? "ID"})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text('Address: ${widget.visit.visitAddress ?? "Patient Residence"}', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                  const SizedBox(height: 2),
                  Text('Attender: ${widget.visit.attenderName ?? "Attender"} (${widget.visit.attenderRelation ?? "Family"})', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                  const Divider(height: 18),

                  // Items Table
                  const Row(
                    children: [
                      Expanded(flex: 5, child: Text('Service / Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 2, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 3, child: Text('Rate (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 3, child: Text('Subtotal (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 1, thickness: 1),
                  const SizedBox(height: 6),
                  ...items.map((it) {
                    final qty = it['quantity'] as int? ?? 1;
                    final price = double.tryParse((it['unit_price'] ?? 0).toString()) ?? 0.0;
                    final sub = it['subtotal'] != null
                        ? double.tryParse(it['subtotal'].toString()) ?? (qty * price)
                        : (qty * price);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                      child: Row(
                        children: [
                          Expanded(flex: 5, child: Text(_cleanEnglishItemName(it['item_name'] ?? ''), style: const TextStyle(fontSize: 11.5))),
                          Expanded(flex: 2, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5))),
                          Expanded(flex: 3, child: Text(price.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5))),
                          Expanded(flex: 3, child: Text(sub.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5))),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 20),

                  // Summary Totals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Bill Amount:', style: TextStyle(fontSize: 12.5)),
                      Text('₹${(double.tryParse((invoice['total_amount'] ?? 0).toString()) ?? netAmount).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                  if ((double.tryParse((invoice['discount'] ?? 0).toString()) ?? 0.0) > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discount:', style: TextStyle(fontSize: 12.5, color: Colors.red)),
                        Text('- ₹${double.parse((invoice['discount'] ?? 0).toString()).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, color: Colors.red)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Net Amount Due:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      Text('₹${netAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.primaryColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount Paid:', style: TextStyle(fontSize: 12.5, color: Colors.green)),
                      Text('₹${paidAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Balance Due:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      Text('₹${balanceDue.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: balanceDue > 0 ? Colors.red : Colors.green)),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Payment Status: ${invoice['payment_status'] ?? 'Unpaid'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text('Authorized Signatory', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                    ],
                  )
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(pCtx),
              style: AppTheme.cancelButton,
              child: const Text('Back'),
            ),
            ElevatedButton.icon(
              style: AppTheme.primaryButton,
              icon: const Icon(Icons.print, size: 16),
              label: const Text('Send to Printer'),
              onPressed: () {
                Navigator.pop(pCtx);
                printHospitalReceipt(
                  context: context,
                  invoice: {
                    ...invoice,
                    'patient_name': widget.visit.patientName,
                    'patient_display_id': widget.visit.patientDisplayId,
                    'patient_phone': widget.visit.patientPhone,
                    'admission_type': 'Home Visit (${widget.visit.visitNumber ?? 'HV'})',
                    'nurse_name': widget.visit.nurseName,
                    'home_visit_number': widget.visit.visitNumber,
                  },
                  items: items,
                  payments: const [],
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> invoice = (_invoiceData['invoice'] is Map)
        ? Map<String, dynamic>.from(_invoiceData['invoice'])
        : Map<String, dynamic>.from(_invoiceData);
    final List<dynamic> items = (invoice['items'] as List<dynamic>?) ??
        (_invoiceData['items'] as List<dynamic>?) ??
        [];
    final int? invoiceId = invoice['id'] as int?;
    final String invoiceNumber = invoice['invoice_number'] ?? 'INV-HV-0000';

    final double totalAmount = (invoice['total_amount'] != null)
        ? double.tryParse(invoice['total_amount'].toString()) ?? 0.0
        : items.fold<double>(0.0, (acc, item) {
            final st = item['subtotal'] ?? ((item['quantity'] ?? 1) * (item['unit_price'] ?? 0.0));
            return acc + (double.tryParse(st.toString()) ?? 0.0);
          });
    final double discount = double.tryParse((invoice['discount'] ?? 0).toString()) ?? 0.0;
    final double netAmount = (invoice['net_amount'] != null)
        ? double.tryParse(invoice['net_amount'].toString()) ?? (totalAmount - discount)
        : (totalAmount - discount);
    final double paidAmount = double.tryParse((invoice['paid_amount'] ?? 0).toString()) ?? 0.0;
    final double balanceDue = (netAmount - paidAmount) > 0 ? (netAmount - paidAmount) : 0.0;
    final String status = invoice['payment_status'] ?? (paidAmount >= netAmount && netAmount > 0 ? 'Paid' : 'Unpaid');
    final bool isFullyPaid = status == 'Paid' || status == 'Settled' || balanceDue <= 0;

    final patientDisplayName = widget.visit.patientName ?? 'N/A';
    final attenderDisplayName = widget.visit.attenderName ?? 'Attender';
    final nurseDisplayName = widget.visit.nurseName ?? 'Nurse';

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        insetPadding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 680,
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          padding: EdgeInsets.all(isMobile ? 14.0 : 20.0),
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
                          'Home Visit Billing & Invoice',
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
                          'Invoice #: $invoiceNumber',
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
                  // Sync Button
                  Tooltip(
                    message: 'Synchronize bill with latest care entries',
                    child: IconButton(
                      icon: _isSyncing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.sync, color: AppTheme.primaryColor, size: 22),
                      onPressed: _isSyncing ? null : _syncBillItems,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Payment Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isFullyPaid
                          ? const Color(0xFFDCFCE7)
                          : (paidAmount > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isFullyPaid
                            ? const Color(0xFF166534)
                            : (paidAmount > 0 ? const Color(0xFF92400E) : const Color(0xFF991B1B)),
                      ),
                    ),
                  ),
                ],
              ),
              Divider(height: isMobile ? 18 : 24),

              // Patient & Attender Summary Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _infoColumn('Patient Name', patientDisplayName)),
                        Expanded(child: _infoColumn('Patient ID', widget.visit.patientDisplayId ?? 'N/A')),
                        Expanded(child: _infoColumn('Scheduled Date', widget.visit.scheduledDate)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _infoColumn('Verified Attender', attenderDisplayName)),
                        Expanded(child: _infoColumn('Attender Relation', widget.visit.attenderRelation ?? 'Attender')),
                        Expanded(child: _infoColumn('Assigned Nurse', nurseDisplayName)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Itemized Bill Section
              const Text(
                'Itemized Service Charges:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 6),

              // Items List
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(9),
                            topRight: Radius.circular(9),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                'Item / Service',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Qty',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Unit Price',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Subtotal',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                      // Items rows
                      Expanded(
                        child: items.isEmpty
                            ? const Center(child: Text('No items recorded', style: TextStyle(color: Colors.grey)))
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: items.length,
                                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 0.5, color: Color(0xFFF1F5F9)),
                                itemBuilder: (ctx, i) {
                                  final item = items[i];
                                  final String itemName = item['item_name'] ?? 'Item';
                                  final int qty = item['quantity'] != null ? int.tryParse(item['quantity'].toString()) ?? 1 : 1;
                                  final double unitPrice = item['unit_price'] != null ? double.tryParse(item['unit_price'].toString()) ?? 0.0 : 0.0;
                                  final double subtotal = item['subtotal'] != null ? double.tryParse(item['subtotal'].toString()) ?? 0.0 : (qty * unitPrice);
                                  final isFeeItem = _isConsultationFeeItem(itemName);

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    color: isFeeItem ? AppTheme.primaryColor.withValues(alpha: 0.03) : null,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _cleanEnglishItemName(itemName),
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                              if (isFeeItem)
                                                Tooltip(
                                                  message: 'Edit Fee',
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
                                                        size: 13,
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
            const SizedBox(height: 10),

            // Financial Summary Row (Net, Paid, Balance)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F7FB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Net Bill Amount', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('₹${netAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Paid Amount', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('₹${paidAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Balance Due', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          '₹${balanceDue.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: balanceDue > 0 ? Colors.redAccent : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Expandable Collect Payment Form
            if (_showPaymentForm && !isFullyPaid) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Record Patient Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _showPaymentForm = false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFormLabel('Amount to Collect (₹) *'),
                              TextFormField(
                                controller: _collectAmtCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFormLabel('Discount (₹)'),
                              TextFormField(
                                controller: _discountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                onChanged: (val) {
                                  final d = double.tryParse(val) ?? 0.0;
                                  final rem = Math.max(0.0, balanceDue - d);
                                  _collectAmtCtrl.text = rem.toStringAsFixed(0);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildFormLabel('Payment Mode'),
                    Row(
                      children: ['Cash', 'Card', 'UPI', 'Insurance'].map((mode) {
                        final sel = _payMode == mode;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(mode, style: const TextStyle(fontSize: 11)),
                            selected: sel,
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(color: sel ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                            backgroundColor: Colors.grey.shade100,
                            onSelected: (val) {
                              if (val) setState(() => _payMode = mode);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _collectRefCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Txn Ref / Cheque # (Optional)',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: AppTheme.secondaryButton.copyWith(
                            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                          ),
                          onPressed: _isSubmittingPayment
                              ? null
                              : () => _submitPaymentRecord(invoiceId ?? widget.visit.id, balanceDue),
                          child: _isSubmittingPayment
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Confirm Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Bottom Actions Bar
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Close Button
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                    fixedSize: const Size.fromHeight(42),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    ModalHistoryHelper.skipNextHistoryBack();
                    Navigator.of(context).pop();
                    if (widget.onCloseAndComplete != null) {
                      widget.onCloseAndComplete!();
                    }
                  },
                  child: const Text('Close'),
                ),

                // Collect Payment Trigger (if not paid)
                if (!isFullyPaid && !_showPaymentForm)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                      fixedSize: const Size.fromHeight(42),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.payment, size: 17),
                    label: const Text('Collect Payment'),
                    onPressed: () {
                      _collectAmtCtrl.text = balanceDue.toStringAsFixed(0);
                      setState(() => _showPaymentForm = true);
                    },
                  ),

                // Print Receipt Button (With primary background color on the right side)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    fixedSize: const Size.fromHeight(42),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.print, size: 17),
                  label: const Text('Print Receipt'),
                  onPressed: () => _showPrintReceiptSheet(context, invoice, items, netAmount, paidAmount, balanceDue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black87)),
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
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class Math {
  static double max(double a, double b) => a > b ? a : b;
}
