import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';

class LabController {
  String get baseUrl => dotenv.env['BASE_URL']!;

  /// Fetch all lab requests, with optional filters
  Future<List<Map<String, dynamic>>> fetchLabRequests({String? status, int? patientId}) async {
    try {
      String url = '$baseUrl/lab/requests';
      final List<String> queryParams = [];
      if (status != null && status.isNotEmpty) {
        queryParams.add('status=${Uri.encodeComponent(status)}');
      }
      if (patientId != null) {
        queryParams.add('patient_id=$patientId');
      }
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await ApiService.get(url);
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch lab requests');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch dashboard stats for lab technician
  Future<Map<String, dynamic>> fetchLabStats() async {
    try {
      final url = '$baseUrl/lab/stats';
      final response = await ApiService.get(url);
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        return Map<String, dynamic>.from(body['data'] ?? {});
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch lab stats');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Update lab request (e.g. status update, result submission)
  Future<Map<String, dynamic>> updateLabRequest({
    required int id,
    required String status,
    List<Map<String, dynamic>>? resultDetails,
    String? remarks,
    String? attachmentUrl,
    int? processedBy,
  }) async {
    try {
      final url = '$baseUrl/lab/requests/$id';
      final Map<String, dynamic> data = {
        'status': status,
        'result_details': resultDetails,
        'remarks': remarks,
        'attachment_url': attachmentUrl,
        'processed_by': processedBy,
      };

      final response = await ApiService.put(url, data);
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        return Map<String, dynamic>.from(body['data'] ?? {});
      } else {
        throw Exception(body['message'] ?? 'Failed to update lab request');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
