import 'dart:convert';
import '../services/api_service.dart';

import '../config/api_config.dart';

class BillingController {
  String get baseUrl => ApiEndpoints.baseUrl;

  /// Fetch billing services from the catalog
  Future<List<Map<String, dynamic>>> fetchBillingServices() async {
    try {
      final response = await ApiService.get('$baseUrl/billing/services');
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to fetch billing services');
      }
      final List data = body['data'] ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Create or update a billing service in the catalog
  Future<Map<String, dynamic>> saveBillingService({
    required String name,
    required String category,
    required double price,
    String? description,
  }) async {
    try {
      final response = await ApiService.post('$baseUrl/billing/services', {
        'name': name,
        'category': category,
        'price': price,
        'description': description ?? '',
      });
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to save billing service');
      }
      return Map<String, dynamic>.from(body['data']);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch all invoices
  Future<List<Map<String, dynamic>>> fetchInvoices() async {
    try {
      final response = await ApiService.get('$baseUrl/billing/invoices');
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to fetch invoices');
      }
      final List data = body['data'] ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch a detailed invoice with its items and payments
  Future<Map<String, dynamic>> fetchInvoiceDetails(int id) async {
    try {
      final response = await ApiService.get('$baseUrl/billing/invoices/$id');
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to fetch invoice details');
      }
      return Map<String, dynamic>.from(body['data']);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch or auto-generate invoice by appointment ID
  Future<Map<String, dynamic>> fetchInvoiceByAppointment(int appointmentId) async {
    try {
      final response = await ApiService.get('$baseUrl/billing/invoices/by-appointment/$appointmentId');
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to fetch invoice for appointment');
      }
      return Map<String, dynamic>.from(body['data']);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Create a new invoice (e.g. Quick Bill)
  Future<Map<String, dynamic>> createInvoice({
    required int patientId,
    required String admissionType,
    int? admissionId,
    int? appointmentId,
    int? otCaseId,
    required List<Map<String, dynamic>> items,
    required double discount,
    Map<String, dynamic>? initialPayment,
  }) async {
    try {
      final response = await ApiService.post('$baseUrl/billing/invoices', {
        'patient_id': patientId,
        'admission_type': admissionType,
        'admission_id': admissionId,
        'appointment_id': appointmentId,
        if (otCaseId != null) 'ot_case_id': otCaseId,
        'items': items,
        'discount': discount,
        if (initialPayment != null) 'initial_payment': initialPayment,
      });
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to create invoice');
      }
      return Map<String, dynamic>.from(body['data']);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch unbilled OT cases
  Future<List<Map<String, dynamic>>> fetchUnbilledOtCases() async {
    try {
      final response = await ApiService.get('$baseUrl/billing/ot-cases/unbilled');
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to fetch unbilled OT cases');
      }
      final List data = body['data'] ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch charges breakdown for an OT case
  Future<Map<String, dynamic>> fetchOtCaseCharges(dynamic caseId) async {
    try {
      final response = await ApiService.get('$baseUrl/billing/ot-cases/$caseId/charges');
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to fetch OT case charges');
      }
      return Map<String, dynamic>.from(body['data']);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Create dedicated OT case invoice
  Future<Map<String, dynamic>> createOtCaseInvoice({
    required dynamic caseId,
    double discount = 0.0,
    Map<String, dynamic>? initialPayment,
    List<Map<String, dynamic>>? customItems,
  }) async {
    try {
      final response = await ApiService.post('$baseUrl/billing/ot-cases/$caseId/invoice', {
        'discount': discount,
        if (initialPayment != null) 'initial_payment': initialPayment,
        if (customItems != null) 'custom_items': customItems,
      });
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to create OT invoice');
      }
      return Map<String, dynamic>.from(body['data']);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Update fees for an unbilled OT case
  Future<Map<String, dynamic>> updateOtCaseFees({
    required int caseId,
    double? theatreFee,
    double? surgeonFee,
    double? assistantSurgeonFee,
    double? anaesthesiaFee,
    List<Map<String, dynamic>>? consumables,
    List<Map<String, dynamic>>? implants,
  }) async {
    try {
      final response = await ApiService.put('$baseUrl/billing/ot-cases/$caseId/fees', {
        if (theatreFee != null) 'theatre_fee': theatreFee,
        if (surgeonFee != null) 'surgeon_fee': surgeonFee,
        if (assistantSurgeonFee != null) 'assistant_surgeon_fee': assistantSurgeonFee,
        if (anaesthesiaFee != null) 'anaesthesia_fee': anaesthesiaFee,
        if (consumables != null) 'consumables_used': consumables,
        if (implants != null) 'implants_used': implants,
      });
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to update OT case fees');
      }
      return Map<String, dynamic>.from(body['data']);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Add a payment or deposit to an invoice
  Future<Map<String, dynamic>> recordPayment({
    required int invoiceId,
    required double amount,
    required String paymentMode,
    String? transactionReference,
    double? discount,
  }) async {
    try {
      final response = await ApiService.post('$baseUrl/billing/payments', {
        'invoice_id': invoiceId,
        'amount': amount,
        'payment_mode': paymentMode,
        'transaction_reference': transactionReference ?? '',
        if (discount != null) 'discount': discount,
      });
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to record payment');
      }
      return Map<String, dynamic>.from(body['data']);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch dynamic real-time IP billing summary worksheet
  Future<Map<String, dynamic>> fetchIpdBillingSummary(int admissionId) async {
    try {
      final response = await ApiService.get('$baseUrl/billing/ipd/$admissionId/summary');
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to fetch IP billing summary');
      }
      return Map<String, dynamic>.from(body['data']);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Discharge patient and finalize/settle IP billing with clinical summary and clearances
  Future<Map<String, dynamic>> dischargeAndSettleIP({
    required int admissionId,
    String? dischargeSummary,
    String? finalDiagnosis,
    String? treatmentSummary,
    String? medicationPlan,
    String? dischargeInstructions,
    String? followUpDate,
    Map<String, dynamic>? structuredDischargeData,
    Map<String, dynamic>? clearanceStatuses,
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>>? folioItems,
    required double discount,
    required String finalPaymentMode,
    String? transactionReference,
  }) async {
    try {
      final response = await ApiService.post('$baseUrl/billing/ipd/$admissionId/discharge', {
        'discharge_summary': dischargeSummary ?? 'Discharged & Settle Billing',
        'final_diagnosis': finalDiagnosis,
        'treatment_summary': treatmentSummary,
        'medication_plan': medicationPlan,
        'discharge_instructions': dischargeInstructions,
        'follow_up_date': followUpDate,
        'structured_discharge_data': structuredDischargeData,
        'clearance_statuses': clearanceStatuses,
        'items': items,
        'folio_items': folioItems,
        'discount': discount,
        'final_payment_mode': finalPaymentMode,
        'transaction_reference': transactionReference ?? '',
      });
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to settle billing and discharge');
      }
      return Map<String, dynamic>.from(body);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Add a worksheet item to an invoice before discharge
  Future<Map<String, dynamic>> addInvoiceItem({
    required int invoiceId,
    required String itemName,
    required double unitPrice,
    required int quantity,
    int? serviceId,
  }) async {
    try {
      final response = await ApiService.post('$baseUrl/billing/invoices/items', {
        'invoice_id': invoiceId,
        'item_name': itemName,
        'unit_price': unitPrice,
        'quantity': quantity,
        if (serviceId != null) 'service_id': serviceId,
      });
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to add item to invoice');
      }
      return Map<String, dynamic>.from(body['data']);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Delete a worksheet item from an invoice
  Future<Map<String, dynamic>> deleteInvoiceItem(int itemId) async {
    try {
      final response = await ApiService.delete('$baseUrl/billing/invoices/items/$itemId');
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to delete item from invoice');
      }
      return Map<String, dynamic>.from(body['data']);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch consolidated Home Care bill for a patient (multiple visits grouped by date)
  Future<Map<String, dynamic>> fetchHomeCarePatientBill(int patientId) async {
    try {
      final response = await ApiService.get('$baseUrl/billing/home-care/patient/$patientId');
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to fetch consolidated home care bill');
      }
      return Map<String, dynamic>.from(body['data']);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Record payment towards consolidated Home Care patient bill
  Future<Map<String, dynamic>> recordHomeCarePatientPayment({
    required int patientId,
    required double amount,
    String paymentMode = 'Cash',
    String? transactionReference,
    double discount = 0.0,
  }) async {
    try {
      final response = await ApiService.post('$baseUrl/billing/home-care/patient/$patientId/record-payment', {
        'amount': amount,
        'payment_mode': paymentMode,
        'transaction_reference': transactionReference ?? '',
        'discount': discount,
      });
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to record home care payment');
      }
      return Map<String, dynamic>.from(body['data']);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
