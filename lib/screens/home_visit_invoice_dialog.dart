import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/home_visit_model.dart';

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

  @override
  Widget build(BuildContext context) {
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
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Home Visit Billing Invoice',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Text(
                          'Invoice #: $invoiceNumber',
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
                    status,
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
                      Expanded(child: _infoColumn('Patient Name', visit.patientName ?? 'N/A')),
                      Expanded(child: _infoColumn('Patient ID', visit.patientDisplayId ?? 'N/A')),
                      Expanded(child: _infoColumn('Scheduled Date', visit.scheduledDate)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _infoColumn('Verified Attender', visit.attenderName ?? 'Attender')),
                      Expanded(child: _infoColumn('Attender Relation', visit.attenderRelation ?? 'Attender')),
                      Expanded(child: _infoColumn('Assigned Nurse', visit.nurseName ?? 'Nurse')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Itemized Service & Care Charges:',
              style: TextStyle(
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
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Service / Item Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Expanded(flex: 1, child: Text('Unit Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Expanded(flex: 1, child: Text('Subtotal', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
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
                                    item['item_name'] ?? 'Item',
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
                color: AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Net Total Bill Amount:',
                    style: TextStyle(
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
                style: AppTheme.primaryButton,
                onPressed: () {
                  Navigator.of(context).pop();
                  if (onCloseAndComplete != null) {
                    onCloseAndComplete!();
                  }
                },
                child: const Text('Close & Complete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
