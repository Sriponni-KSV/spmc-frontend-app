import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../utils/receipt_printer.dart';
import '../controllers/billing_controller.dart';

/// Professional, reusable dialog for displaying an official itemized hospital receipt
/// with hospital branding & logo, detailed clinical demographics, itemized particulars,
/// financial breakdown, payments ledger, in-place payment collector, and printable receipt.
class BillingReceiptDialog extends StatefulWidget {
  final int? invoiceId;
  final int? appointmentId;
  final VoidCallback? onPaymentSuccess;

  const BillingReceiptDialog({
    super.key,
    this.invoiceId,
    this.appointmentId,
    this.onPaymentSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    int? invoiceId,
    int? appointmentId,
    VoidCallback? onPaymentSuccess,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BillingReceiptDialog(
        invoiceId: invoiceId,
        appointmentId: appointmentId,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  State<BillingReceiptDialog> createState() => _BillingReceiptDialogState();
}

class _BillingReceiptDialogState extends State<BillingReceiptDialog> {
  final BillingController _billingCtrl = BillingController();

  Map<String, dynamic>? _invoiceData;
  bool _isLoading = true;
  String? _errorMessage;

  bool _showPaymentForm = false;
  String _payMode = 'Cash';
  final TextEditingController _collectAmtCtrl = TextEditingController();
  final TextEditingController _collectRefCtrl = TextEditingController();
  final TextEditingController _discountPercentCtrl = TextEditingController(text: '0');
  bool _isSubmittingPayment = false;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  @override
  void dispose() {
    _collectAmtCtrl.dispose();
    _collectRefCtrl.dispose();
    _discountPercentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInvoice() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic> data;
      if (widget.invoiceId != null && widget.invoiceId! > 0) {
        data = await _billingCtrl.fetchInvoiceDetails(widget.invoiceId!);
      } else if (widget.appointmentId != null && widget.appointmentId! > 0) {
        data = await _billingCtrl.fetchInvoiceByAppointment(widget.appointmentId!);
      } else {
        throw Exception('Neither invoice ID nor appointment ID was provided.');
      }

      if (mounted) {
        setState(() {
          _invoiceData = data;
          _isLoading = false;

          final inv = _invoiceData?['invoice'] ?? {};
          final double initialDiscount = double.tryParse((inv['discount'] ?? 0.0).toString()) ?? 0.0;
          final double totalAmountVal = double.tryParse((inv['total_amount'] ?? 0.0).toString()) ?? 0.0;
          final double initialPercent = totalAmountVal > 0 ? (initialDiscount / totalAmountVal) * 100.0 : 0.0;
          _discountPercentCtrl.text = initialPercent.toStringAsFixed(0);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _submitPayment(int invoiceId, Map<String, dynamic> inv) async {
    final double amt = double.tryParse(_collectAmtCtrl.text.trim()) ?? 0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount greater than zero.')),
      );
      return;
    }

    final double pct = double.tryParse(_discountPercentCtrl.text) ?? 0.0;
    final double total = double.tryParse(inv['total_amount']?.toString() ?? '0') ?? 0.0;
    final double discAmt = total * (pct / 100.0);

    setState(() => _isSubmittingPayment = true);

    try {
      await _billingCtrl.recordPayment(
        invoiceId: invoiceId,
        amount: amt,
        paymentMode: _payMode,
        transactionReference: _collectRefCtrl.text.trim(),
        discount: discAmt,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded successfully! Receipt updated.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );

        setState(() {
          _showPaymentForm = false;
          _collectAmtCtrl.clear();
          _collectRefCtrl.clear();
          _isSubmittingPayment = false;
        });

        widget.onPaymentSuccess?.call();
        await _loadInvoice();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording payment: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 28,
        vertical: 20,
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Hospital Bill & Official Receipt',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Close',
          ),
        ],
      ),
      content: _buildContent(isMobile),
      actions: _buildActions(),
    );
  }

  Widget _buildContent(bool isMobile) {
    if (_isLoading) {
      return const SizedBox(
        width: 580,
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading receipt details...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        width: 580,
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.dangerColor, size: 36),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.dangerColor),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadInvoice,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final data = _invoiceData!;
    final inv = data['invoice'] ?? {};
    final List items = data['items'] ?? [];
    final List payments = data['payments'] ?? [];

    final patientName = inv['patient_name'] ?? 'N/A';
    final patientDisplayId = inv['patient_display_id'] ?? 'N/A';
    final patientPhone = inv['patient_phone'] ?? 'N/A';
    final patientGender = inv['patient_gender'] ?? '';
    final patientAge = inv['patient_age'] != null ? '${inv['patient_age']} Yrs' : '';
    final ageGender = [patientAge, patientGender].where((s) => s.isNotEmpty).join(' / ');
    final docName = inv['doctor_name'] ?? 'Consultant Doctor';
    final admType = inv['admission_type'] ?? 'Outpatient';
    final bedNum = inv['bed_number'];
    final wardType = inv['ward_type'];
    final visitNum = inv['home_visit_number'];
    final nurseName = inv['nurse_name'];

    String locationInfo = admType;
    if (bedNum != null && bedNum.toString().isNotEmpty) {
      locationInfo = 'Bed: $bedNum (${wardType ?? 'General'})';
    } else if (visitNum != null && visitNum.toString().isNotEmpty) {
      locationInfo = 'Home Visit: $visitNum';
      if (nurseName != null) locationInfo += ' (Nurse: $nurseName)';
    }

    final rawDate = inv['created_at'];
    final date = rawDate != null
        ? DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(rawDate).toLocal())
        : 'N/A';

    final paymentStatus = (inv['payment_status'] ?? 'Unpaid').toString();
    final isPaid = paymentStatus.toLowerCase() == 'paid' || paymentStatus.toLowerCase() == 'settled';

    final totalAmount = double.tryParse((inv['total_amount'] ?? 0).toString()) ?? 0.0;
    final discount = double.tryParse((inv['discount'] ?? 0).toString()) ?? 0.0;
    final netAmount = double.tryParse((inv['net_amount'] ?? 0).toString()) ?? 0.0;
    final paidAmount = double.tryParse((inv['paid_amount'] ?? 0).toString()) ?? 0.0;
    final balanceDue = (netAmount - paidAmount).clamp(0.0, double.infinity);

    return SingleChildScrollView(
      child: SizedBox(
        width: isMobile ? double.maxFinite : 620,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. Hospital Letterhead with Logo ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
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
                      height: 52,
                      width: 90,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => Image.asset(
                        'assets/image/sriPonniLogo.png',
                        height: 52,
                        width: 52,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SRI PONNI MEDICAL CENTRE',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Multi-Speciality Hospital & Research Institute',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '124, Trichy Main Road, Namakkal, Tamil Nadu - 637001',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                        Text(
                          'Ph: +91 4286 220000 | GSTIN: 33AAAAA0000A1Z5 | Reg: SPMC-TN-2024-0891',
                          style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── 2. Receipt Title Ribbon & Status ──────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'OFFICIAL RECEIPT / TAX INVOICE',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.6,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? const Color(0xFFDCFCE7)
                          : (paidAmount > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isPaid
                            ? const Color(0xFF86EFAC)
                            : (paidAmount > 0 ? const Color(0xFFFDE68A) : const Color(0xFFFECACA)),
                      ),
                    ),
                    child: Text(
                      paymentStatus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isPaid
                            ? const Color(0xFF15803D)
                            : (paidAmount > 0 ? const Color(0xFFB45309) : const Color(0xFFDC2626)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ─── 3. Demographics & Billing Metadata Box ───────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetaRow('Bill / Invoice No:', inv['invoice_number'] ?? 'Draft'),
                        _buildMetaRow('Date & Time:', date),
                        _buildMetaRow('Visit / Category:', locationInfo),
                        _buildMetaRow('Doctor / Dept:', docName),
                        const Divider(height: 14, color: Color(0xFFCBD5E1)),
                        _buildMetaRow('Patient Name:', patientName),
                        _buildMetaRow('UHID / Patient ID:', patientDisplayId),
                        _buildMetaRow('Age / Gender:', ageGender.isEmpty ? 'N/A' : ageGender),
                        _buildMetaRow('Contact Phone:', patientPhone),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMetaRow('Invoice No:', inv['invoice_number'] ?? 'Draft'),
                              _buildMetaRow('Date & Time:', date),
                              _buildMetaRow('Visit / Type:', locationInfo),
                              _buildMetaRow('Doctor / Dept:', docName),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMetaRow('Patient Name:', patientName),
                              _buildMetaRow('UHID / ID:', patientDisplayId),
                              _buildMetaRow('Age / Gender:', ageGender.isEmpty ? 'N/A' : ageGender),
                              _buildMetaRow('Contact Phone:', patientPhone),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            if (inv['ot_case_display_id'] != null || inv['ot_surgery_type'] != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.medical_services_outlined, size: 16, color: Color(0xFF16A34A)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'OT CASE: ${(inv['ot_surgery_type'] ?? 'Surgery').toString().toUpperCase()} ${inv['ot_case_display_id'] != null ? "(${inv['ot_case_display_id']})" : ""}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        if (inv['ot_theatre_name'] != null && inv['ot_theatre_name'].toString().isNotEmpty)
                          Text('Theatre: ${inv['ot_theatre_name']}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF374151))),
                        if (inv['ot_lead_surgeon'] != null && inv['ot_lead_surgeon'].toString().isNotEmpty)
                          Text('Lead Surgeon: ${inv['ot_lead_surgeon']}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF374151))),
                        if (inv['ot_assistant_surgeon'] != null && inv['ot_assistant_surgeon'].toString().isNotEmpty)
                          Text('Assistant: ${inv['ot_assistant_surgeon']}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF374151))),
                        if (inv['ot_anaesthetist'] != null && inv['ot_anaesthetist'].toString().isNotEmpty)
                          Text('Anaesthetist: ${inv['ot_anaesthetist']}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF374151))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // ─── 4. Itemized Charges Table ───────────────────────────────────
            const Text(
              'Itemized Billing Particulars:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppTheme.primaryColor,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 30, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                        Expanded(flex: 5, child: Text('Particulars / Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                        Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('Rate (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('Subtotal (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                      ],
                    ),
                  ),

                  // Table Body Rows
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text('No itemized charges billed.', style: TextStyle(color: Colors.grey, fontSize: 11.5)),
                      ),
                    )
                  else
                    ...items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final qty = int.tryParse((item['quantity'] ?? 1).toString()) ?? 1;
                      final price = double.tryParse((item['unit_price'] ?? 0).toString()) ?? 0.0;
                      final sub = qty * price;
                      final itemName = item['item_name'] ?? 'Charge';
                      final isEven = i % 2 == 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isEven ? Colors.white : const Color(0xFFFAFAFA),
                          border: Border(bottom: BorderSide(color: i == items.length - 1 ? Colors.transparent : const Color(0xFFF1F5F9))),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 30, child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
                            Expanded(
                              flex: 5,
                              child: Text(
                                itemName,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '$qty',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                price.toStringAsFixed(2),
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                sub == 0 ? 'FREE' : sub.toStringAsFixed(2),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                  color: sub == 0 ? const Color(0xFF16A34A) : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── 5. Financial Summary Breakdown ──────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: isMobile ? double.maxFinite : 290,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Gross Bill Total', totalAmount),
                    if (discount > 0) ...[
                      const SizedBox(height: 4),
                      _buildSummaryRow('Discount Allowed', discount, color: AppTheme.dangerColor, prefix: '- '),
                    ],
                    const Divider(height: 12, thickness: 1, color: Color(0xFFCBD5E1)),
                    _buildSummaryRow('Net Payable Amount', netAmount, isBold: true, color: AppTheme.primaryColor),
                    const SizedBox(height: 4),
                    _buildSummaryRow('Amount Received', paidAmount, color: const Color(0xFF16A34A)),
                    const SizedBox(height: 4),
                    _buildSummaryRow(
                      'Balance Due',
                      balanceDue,
                      isBold: true,
                      color: balanceDue > 0 ? AppTheme.dangerColor : const Color(0xFF16A34A),
                    ),
                  ],
                ),
              ),
            ),

            // ─── 6. Payments History Ledger ───────────────────────────────────
            if (payments.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Payment Transactions:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: payments.map((pay) {
                    final rawPayDate = pay['payment_date'];
                    final pDate = rawPayDate != null
                        ? DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(rawPayDate).toLocal())
                        : 'N/A';
                    final payAmt = double.tryParse((pay['amount'] ?? 0).toString()) ?? 0.0;
                    final mode = pay['payment_mode'] ?? 'Cash';
                    final ref = pay['transaction_reference'];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  mode,
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(pDate, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                              if (ref != null && ref.toString().isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text('• $ref', style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5)),
                              ],
                            ],
                          ),
                          Text(
                            '₹${payAmt.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // ─── 7. Payment Collection Sub-Form ──────────────────────────────
            if (!isPaid && _showPaymentForm) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Collect Fee / Settle Balance',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Discount (%)'),
                              TextFormField(
                                controller: _discountPercentCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                onChanged: (val) {
                                  final double pct = double.tryParse(val) ?? 0.0;
                                  final double discAmt = totalAmount * (pct / 100.0);
                                  final double net = totalAmount - discAmt;
                                  _collectAmtCtrl.text = (net - paidAmount).clamp(0.0, double.infinity).toStringAsFixed(0);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Amount to Collect (₹) *'),
                              TextFormField(
                                controller: _collectAmtCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildLabel('Payment Mode'),
                    Wrap(
                      spacing: 6,
                      children: ['Cash', 'Card', 'UPI', 'Insurance'].map((mode) {
                        final selected = _payMode == mode;
                        return ChoiceChip(
                          label: Text(mode, style: const TextStyle(fontSize: 11.5)),
                          selected: selected,
                          selectedColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          backgroundColor: Colors.white,
                          onSelected: (val) {
                            if (val) setState(() => _payMode = mode);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    _buildLabel('Transaction Reference / Notes'),
                    TextFormField(
                      controller: _collectRefCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. UPI Ref / Cheque No / Card Last 4 digits',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _showPaymentForm = false),
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSubmittingPayment
                              ? null
                              : () => _submitPayment(inv['id'], inv),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: _isSubmittingPayment
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Submit Payment'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // ─── 8. Receipt Footer & Signatory ───────────────────────────────
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0), style: BorderStyle.solid)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• Computer-generated tax invoice & receipt.',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                        Text(
                          '• All payments subject to realization.',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '24x7 Emergency: +91 4286 220000',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 1,
                        color: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Authorized Cashier',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      Text(
                        'Sri Ponni Medical Centre',
                        style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions() {
    if (_isLoading || _errorMessage != null || _invoiceData == null) {
      return [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ];
    }

    final inv = _invoiceData!['invoice'] ?? {};
    final items = _invoiceData!['items'] ?? [];
    final payments = _invoiceData!['payments'] ?? [];
    final paymentStatus = (inv['payment_status'] ?? 'Unpaid').toString();
    final isPaid = paymentStatus.toLowerCase() == 'paid' || paymentStatus.toLowerCase() == 'settled';

    final netAmount = double.tryParse((inv['net_amount'] ?? 0).toString()) ?? 0.0;
    final paidAmount = double.tryParse((inv['paid_amount'] ?? 0).toString()) ?? 0.0;
    final balanceDue = (netAmount - paidAmount).clamp(0.0, double.infinity);

    return [
      Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
              fixedSize: const Size.fromHeight(42),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            child: const Text('Close'),
          ),
          if (!isPaid && !_showPaymentForm)
            ElevatedButton.icon(
              onPressed: () {
                _collectAmtCtrl.text = balanceDue.toStringAsFixed(0);
                setState(() => _showPaymentForm = true);
              },
              icon: const Icon(Icons.payment, size: 16),
              label: const Text('Collect Fee'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
                fixedSize: const Size.fromHeight(42),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                elevation: 0,
              ),
            ),
          ElevatedButton.icon(
            onPressed: () {
              printHospitalReceipt(
                context: context,
                invoice: inv,
                items: items,
                payments: payments,
              );
            },
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print Receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              fixedSize: const Size.fromHeight(42),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              elevation: 0,
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false, Color? color, String prefix = ''}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? const Color(0xFF475569),
          ),
        ),
        Text(
          '$prefix₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isBold ? 13 : 11.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondaryColor,
        ),
      ),
    );
  }
}
