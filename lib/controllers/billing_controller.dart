import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';

class BillingController {
  String get baseUrl => dotenv.env['BASE_URL']!;

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

  /// Create a new invoice (e.g. Quick Bill)
  Future<Map<String, dynamic>> createInvoice({
    required int patientId,
    required String admissionType,
    int? admissionId,
    int? appointmentId,
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

  /// Discharge patient and finalize/settle IP billing
  Future<Map<String, dynamic>> dischargeAndSettleIP({
    required int admissionId,
    String? dischargeSummary,
    required List<Map<String, dynamic>> items,
    required double discount,
    required String finalPaymentMode,
    String? transactionReference,
  }) async {
    try {
      final response = await ApiService.post('$baseUrl/billing/ipd/$admissionId/discharge', {
        'discharge_summary': dischargeSummary ?? 'Discharged & Settle Billing',
        'items': items,
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
}
