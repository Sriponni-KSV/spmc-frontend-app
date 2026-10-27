import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void printHospitalReceipt({
  required BuildContext context,
  required Map<String, dynamic> invoice,
  required List<dynamic> items,
  required List<dynamic> payments,
}) {
  try {
    final invNum = invoice['invoice_number'] ?? 'INV-RECEIPT';
    final patientName = invoice['patient_name'] ?? 'Patient';
    final patientDisplayId = invoice['patient_display_id'] ?? 'N/A';
    final phone = invoice['patient_phone'] ?? 'N/A';
    final gender = invoice['patient_gender'] ?? '';
    final age = invoice['patient_age'] != null ? '${invoice['patient_age']} Yrs' : '';
    final ageGender = [age, gender].where((s) => s.isNotEmpty).join(' / ');
    final docName = invoice['doctor_name'] ?? 'Consultant Doctor';
    final admType = invoice['admission_type'] ?? 'Outpatient';
    final bedNum = invoice['bed_number'];
    final wardType = invoice['ward_type'];
    final visitNum = invoice['home_visit_number'];
    final nurseName = invoice['nurse_name'];

    String locationInfo = admType;
    if (bedNum != null && bedNum.toString().isNotEmpty) {
      locationInfo = 'Bed: $bedNum (${wardType ?? 'General'})';
    } else if (visitNum != null && visitNum.toString().isNotEmpty) {
      locationInfo = 'Home Visit: $visitNum (Nurse: ${nurseName ?? 'Staff'})';
    }

    final otCaseDisplayId = invoice['ot_case_display_id'];
    final otSurgeryType = invoice['ot_surgery_type'];
    final otLeadSurgeon = invoice['ot_lead_surgeon'];
    final otAsstSurgeon = invoice['ot_assistant_surgeon'];
    final otAnaesthetist = invoice['ot_anaesthetist'];
    final otTheatreName = invoice['ot_theatre_name'];
    final hasOt = otCaseDisplayId != null || otSurgeryType != null;

    final rawDate = invoice['created_at'];
    final dateStr = rawDate != null
        ? DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(rawDate).toLocal())
        : DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());

    final totalAmount = double.tryParse((invoice['total_amount'] ?? 0).toString()) ?? 0.0;
    final discount = double.tryParse((invoice['discount'] ?? 0).toString()) ?? 0.0;
    final netAmount = double.tryParse((invoice['net_amount'] ?? 0).toString()) ?? 0.0;
    final paidAmount = double.tryParse((invoice['paid_amount'] ?? 0).toString()) ?? 0.0;
    final balanceDue = (netAmount - paidAmount).clamp(0.0, double.infinity);
    final paymentStatus = (invoice['payment_status'] ?? 'Unpaid').toString().toUpperCase();

    final statusColor = paymentStatus == 'PAID'
        ? '#15803d'
        : (paidAmount > 0 ? '#b45309' : '#dc2626');
    final statusBg = paymentStatus == 'PAID'
        ? '#dcfce7'
        : (paidAmount > 0 ? '#fef3c7' : '#fee2e2');

    // Build Items rows
    final StringBuffer itemsHtml = StringBuffer();
    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      final qty = int.tryParse((it['quantity'] ?? 1).toString()) ?? 1;
      final price = double.tryParse((it['unit_price'] ?? 0).toString()) ?? 0.0;
      final sub = qty * price;
      final name = it['item_name'] ?? 'Service Charge';
      itemsHtml.write('''
        <tr>
          <td style="text-align: center; border-bottom: 1px solid #e2e8f0; padding: 8px 6px;">${i + 1}</td>
          <td style="border-bottom: 1px solid #e2e8f0; padding: 8px 6px; font-weight: 500;">$name</td>
          <td style="text-align: center; border-bottom: 1px solid #e2e8f0; padding: 8px 6px;">$qty</td>
          <td style="text-align: right; border-bottom: 1px solid #e2e8f0; padding: 8px 6px;">₹${price.toStringAsFixed(2)}</td>
          <td style="text-align: right; border-bottom: 1px solid #e2e8f0; padding: 8px 6px; font-weight: 600;">₹${sub.toStringAsFixed(2)}</td>
        </tr>
      ''');
    }

    if (items.isEmpty) {
      itemsHtml.write('''
        <tr>
          <td colspan="5" style="text-align: center; padding: 16px; color: #64748b; font-style: italic;">No itemized charges billed.</td>
        </tr>
      ''');
    }

    // Build Payments rows
    final StringBuffer paymentsHtml = StringBuffer();
    for (final p in payments) {
      final pDateRaw = p['payment_date'];
      final pDate = pDateRaw != null
          ? DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(pDateRaw).toLocal())
          : 'N/A';
      final pAmt = double.tryParse((p['amount'] ?? 0).toString()) ?? 0.0;
      final pMode = p['payment_mode'] ?? 'Cash';
      final pRef = p['transaction_reference'] ?? '-';
      paymentsHtml.write('''
        <tr>
          <td style="border-bottom: 1px solid #f1f5f9; padding: 6px 8px;">$pDate</td>
          <td style="border-bottom: 1px solid #f1f5f9; padding: 6px 8px; font-weight: 600;">$pMode</td>
          <td style="border-bottom: 1px solid #f1f5f9; padding: 6px 8px; color: #475569;">$pRef</td>
          <td style="text-align: right; border-bottom: 1px solid #f1f5f9; padding: 6px 8px; font-weight: 600; color: #15803d;">₹${pAmt.toStringAsFixed(2)}</td>
        </tr>
      ''');
    }

    final paymentsSection = payments.isNotEmpty
        ? '''
        <div style="margin-top: 16px;">
          <div style="font-size: 12px; font-weight: bold; color: #065D96; text-transform: uppercase; margin-bottom: 6px;">Payment Transactions:</div>
          <table style="width: 100%; border-collapse: collapse; font-size: 11.5px;">
            <thead>
              <tr style="background-color: #f8fafc; color: #475569;">
                <th style="text-align: left; padding: 6px 8px; border-bottom: 1px solid #cbd5e1;">Date & Time</th>
                <th style="text-align: left; padding: 6px 8px; border-bottom: 1px solid #cbd5e1;">Mode</th>
                <th style="text-align: left; padding: 6px 8px; border-bottom: 1px solid #cbd5e1;">Reference</th>
                <th style="text-align: right; padding: 6px 8px; border-bottom: 1px solid #cbd5e1;">Amount Paid</th>
              </tr>
            </thead>
            <tbody>
              $paymentsHtml
            </tbody>
          </table>
        </div>
        '''
        : '';

    final String otSection;
    if (hasOt) {
      final caseBadge = otCaseDisplayId != null
          ? '<span style="background-color: #dcfce7; padding: 1px 6px; border-radius: 4px; font-size: 10px; border: 1px solid #86efac;">$otCaseDisplayId</span>'
          : '';
      final surgItem = otSurgeryType != null
          ? '<div><span style="color: #64748b;">Surgery:</span> <b>$otSurgeryType</b></div>'
          : '';
      final thItem = otTheatreName != null
          ? '<div><span style="color: #64748b;">Theatre:</span> <b>$otTheatreName</b></div>'
          : '';
      final docItem = otLeadSurgeon != null
          ? '<div><span style="color: #64748b;">Lead Surgeon:</span> <b>$otLeadSurgeon</b></div>'
          : '';
      final asstItem = otAsstSurgeon != null
          ? '<div><span style="color: #64748b;">Assistant:</span> <b>$otAsstSurgeon</b></div>'
          : '';
      final anaeItem = otAnaesthetist != null
          ? '<div><span style="color: #64748b;">Anaesthetist:</span> <b>$otAnaesthetist</b></div>'
          : '';

      otSection = '''
        <div style="background-color: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 6px; padding: 8px 12px; margin-bottom: 14px; font-size: 11px;">
          <div style="font-weight: bold; color: #166534; margin-bottom: 4px; display: flex; align-items: center; gap: 6px;">
            <span>OPERATION THEATRE & SURGICAL DETAILS</span>
            $caseBadge
          </div>
          <div style="display: flex; flex-wrap: wrap; gap: 14px; color: #374151;">
            $surgItem
            $thItem
            $docItem
            $asstItem
            $anaeItem
          </div>
        </div>
      ''';
    } else {
      otSection = '';
    }

    final htmlContent = '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Receipt - $invNum</title>
      <style>
        @page {
          size: A4 portrait;
          margin: 15mm;
        }
        body {
          font-family: 'Segoe UI', Arial, sans-serif;
          color: #0f172a;
          margin: 0;
          padding: 20px;
          background-color: #fff;
          font-size: 12px;
          line-height: 1.4;
        }
        .receipt-card {
          max-width: 780px;
          margin: 0 auto;
          border: 1px solid #cbd5e1;
          border-radius: 8px;
          padding: 24px;
        }
        .header-table {
          width: 100%;
          border-bottom: 2px solid #065D96;
          padding-bottom: 14px;
          margin-bottom: 14px;
        }
        .hospital-title {
          font-size: 20px;
          font-weight: 800;
          color: #065D96;
          letter-spacing: 0.5px;
          margin: 0;
        }
        .hospital-subtitle {
          font-size: 12px;
          font-weight: 600;
          color: #475569;
          margin: 2px 0;
        }
        .hospital-meta {
          font-size: 11px;
          color: #64748b;
          margin: 2px 0;
        }
        .badge-bar {
          display: flex;
          justify-content: space-between;
          align-items: center;
          background-color: #f8fafc;
          border: 1px solid #e2e8f0;
          border-radius: 6px;
          padding: 8px 12px;
          margin-bottom: 14px;
        }
        .badge-title {
          font-size: 13px;
          font-weight: 800;
          color: #065D96;
          letter-spacing: 0.5px;
        }
        .badge-status {
          font-size: 11px;
          font-weight: 700;
          padding: 4px 10px;
          border-radius: 4px;
          background-color: $statusBg;
          color: $statusColor;
          border: 1px solid $statusColor;
        }
        .meta-grid {
          display: table;
          width: 100%;
          margin-bottom: 16px;
          border: 1px solid #e2e8f0;
          border-radius: 6px;
          background-color: #fdfdfd;
        }
        .meta-col {
          display: table-cell;
          width: 50%;
          padding: 10px 14px;
          vertical-align: top;
        }
        .meta-row {
          margin-bottom: 5px;
          font-size: 11.5px;
        }
        .meta-label {
          color: #64748b;
          font-weight: 500;
          display: inline-block;
          width: 110px;
        }
        .meta-value {
          font-weight: 700;
          color: #0f172a;
        }
        table.items-table {
          width: 100%;
          border-collapse: collapse;
          margin-top: 10px;
          margin-bottom: 16px;
          font-size: 12px;
        }
        table.items-table th {
          background-color: #f1f5f9;
          color: #065D96;
          font-weight: 700;
          border-top: 1px solid #cbd5e1;
          border-bottom: 1px solid #cbd5e1;
          padding: 8px 6px;
        }
        .summary-wrap {
          display: flex;
          justify-content: flex-end;
          margin-top: 12px;
        }
        .summary-box {
          width: 280px;
          border: 1px solid #e2e8f0;
          border-radius: 6px;
          background-color: #f8fafc;
          padding: 10px 14px;
        }
        .sum-row {
          display: flex;
          justify-content: space-between;
          padding: 3px 0;
          font-size: 12px;
        }
        .sum-total {
          border-top: 1px solid #cbd5e1;
          margin-top: 6px;
          padding-top: 6px;
          font-weight: 800;
          font-size: 13.5px;
          color: #065D96;
        }
        .footer-sec {
          margin-top: 24px;
          padding-top: 14px;
          border-top: 1px dashed #cbd5e1;
          display: flex;
          justify-content: space-between;
          align-items: flex-end;
        }
        .footer-note {
          font-size: 10.5px;
          color: #64748b;
          max-width: 440px;
        }
        .signature-box {
          text-align: center;
          width: 180px;
        }
        .sig-line {
          border-top: 1px solid #0f172a;
          margin-top: 40px;
          margin-bottom: 4px;
        }
        @media print {
          body {
            padding: 0;
            background: none;
          }
          .receipt-card {
            border: none;
            padding: 0;
          }
          .no-print {
            display: none !important;
          }
        }
      </style>
    </head>
    <body>
      <div class="receipt-card">
        <!-- Hospital Header with Logo -->
        <table class="header-table">
          <tr>
            <td style="width: 90px; vertical-align: middle;">
              <img src="/assets/assets/image/full_logo.png" onerror="this.src='assets/image/full_logo.png'; this.onerror=function(){this.src='assets/image/sriPonniLogo.png';};" style="height: 60px; max-width: 85px; object-fit: contain;" alt="SPMC Logo" />
            </td>
            <td style="padding-left: 14px; vertical-align: middle;">
              <div class="hospital-title">SRI PONNI MEDICAL CENTRE</div>
              <div class="hospital-subtitle">Multi-Speciality Hospital & Research Institute</div>
              <div class="hospital-meta">124, Trichy Main Road, Namakkal, Tamil Nadu - 637001</div>
              <div class="hospital-meta">Ph: +91 4286 220000 / +91 98427 34567 | GSTIN: 33AAAAA0000A1Z5 | Reg: SPMC-TN-2024-0891</div>
            </td>
          </tr>
        </table>

        <!-- Receipt Title & Payment Status -->
        <div class="badge-bar">
          <div class="badge-title">OFFICIAL RECEIPT / TAX INVOICE</div>
          <div class="badge-status">$paymentStatus</div>
        </div>

        <!-- Demographics & Metadata Grid -->
        <div class="meta-grid">
          <div class="meta-col">
            <div class="meta-row"><span class="meta-label">Invoice / Bill No:</span> <span class="meta-value">$invNum</span></div>
            <div class="meta-row"><span class="meta-label">Date & Time:</span> <span class="meta-value">$dateStr</span></div>
            <div class="meta-row"><span class="meta-label">Visit / Category:</span> <span class="meta-value">$locationInfo</span></div>
            <div class="meta-row"><span class="meta-label">Doctor / Dept:</span> <span class="meta-value">$docName</span></div>
          </div>
          <div class="meta-col">
            <div class="meta-row"><span class="meta-label">Patient Name:</span> <span class="meta-value">$patientName</span></div>
            <div class="meta-row"><span class="meta-label">UHID / Patient ID:</span> <span class="meta-value">$patientDisplayId</span></div>
            <div class="meta-row"><span class="meta-label">Age / Gender:</span> <span class="meta-value">${ageGender.isEmpty ? 'N/A' : ageGender}</span></div>
            <div class="meta-row"><span class="meta-label">Phone:</span> <span class="meta-value">$phone</span></div>
          </div>
        </div>

        $otSection

        <!-- Itemized Charges Table -->
        <div style="font-size: 12px; font-weight: bold; color: #065D96; text-transform: uppercase; margin-bottom: 4px;">Itemized Billing Particulars:</div>
        <table class="items-table">
          <thead>
            <tr>
              <th style="width: 40px; text-align: center;">#</th>
              <th style="text-align: left;">Particulars / Service Description</th>
              <th style="width: 60px; text-align: center;">Qty</th>
              <th style="width: 100px; text-align: right;">Unit Rate (₹)</th>
              <th style="width: 110px; text-align: right;">Subtotal (₹)</th>
            </tr>
          </thead>
          <tbody>
            $itemsHtml
          </tbody>
        </table>

        <!-- Summary Totals -->
        <div class="summary-wrap">
          <div class="summary-box">
            <div class="sum-row">
              <span style="color: #475569;">Gross Bill Total:</span>
              <span style="font-weight: 600;">₹${totalAmount.toStringAsFixed(2)}</span>
            </div>
            ${discount > 0 ? '''
            <div class="sum-row" style="color: #dc2626;">
              <span>Discount Allowed:</span>
              <span>- ₹${discount.toStringAsFixed(2)}</span>
            </div>
            ''' : ''}
            <div class="sum-row sum-total">
              <span>Net Payable Amount:</span>
              <span>₹${netAmount.toStringAsFixed(2)}</span>
            </div>
            <div class="sum-row" style="color: #15803d; font-weight: 600; margin-top: 4px;">
              <span>Amount Received:</span>
              <span>₹${paidAmount.toStringAsFixed(2)}</span>
            </div>
            <div class="sum-row" style="font-weight: 700; color: ${balanceDue > 0 ? '#dc2626' : '#15803d'};">
              <span>Balance Due:</span>
              <span>₹${balanceDue.toStringAsFixed(2)}</span>
            </div>
          </div>
        </div>

        <!-- Payments Ledger -->
        $paymentsSection

        <!-- Footer Notice & Signatory -->
        <div class="footer-sec">
          <div class="footer-note">
            <div>• This is an electronically generated official receipt and tax invoice.</div>
            <div>• All payments are subject to hospital realization. Keep this receipt for any future reference.</div>
            <div style="margin-top: 4px; font-weight: 600; color: #065D96;">24x7 Emergency Services & Ambulance: +91 4286 220000</div>
          </div>
          <div class="signature-box">
            <div class="sig-line"></div>
            <div style="font-size: 11px; font-weight: bold; color: #334155;">Authorized Cashier</div>
            <div style="font-size: 10px; color: #64748b;">Sri Ponni Medical Centre</div>
          </div>
        </div>
      </div>

      <script>
        window.onload = function() {
          setTimeout(function() {
            window.print();
          }, 400);
        };
      </script>
    </body>
    </html>
    ''';

    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final printWin = html.window.open(url, '_blank');
    if (printWin == null) {
      // If popup blocked, fallback to direct page print or alert
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please allow popups to open the clean printable receipt.'),
          backgroundColor: Color(0xFFE53E3E),
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Print error: $e'),
        backgroundColor: const Color(0xFFE53E3E),
      ),
    );
  }
}
