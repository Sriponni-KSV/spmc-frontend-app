import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';

import '../config/api_config.dart';

class LabController {
  String get baseUrl => ApiEndpoints.baseUrl;

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
    int? targetTatMinutes,
    String? priority,
    int? processingDurationMinutes,
    String? delayReason,
    String? scheduledStartOverride,
  }) async {
    try {
      final url = '$baseUrl/lab/requests/$id';
      final Map<String, dynamic> data = {
        'status': status,
        'result_details': resultDetails,
        'remarks': remarks,
        'attachment_url': attachmentUrl,
        'processed_by': processedBy,
        if (targetTatMinutes != null) 'target_tat_minutes': targetTatMinutes,
        if (priority != null) 'priority': priority,
        if (processingDurationMinutes != null) 'processing_duration_minutes': processingDurationMinutes,
        if (delayReason != null) 'delay_reason': delayReason,
        if (scheduledStartOverride != null) 'scheduled_start_override': scheduledStartOverride,
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

  /// Fetch lab config
  Future<Map<String, dynamic>> fetchLabConfig() async {
    try {
      final url = '$baseUrl/lab/config';
      final response = await ApiService.get(url);
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        return Map<String, dynamic>.from(body['data'] ?? {});
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch lab config');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Update lab config
  Future<Map<String, dynamic>> updateLabConfig({
    required String openingTime,
    required String closingTime,
    required List<int> weeklyOffs,
    required List<String> holidays,
  }) async {
    try {
      final url = '$baseUrl/lab/config';
      final Map<String, dynamic> data = {
        'opening_time': openingTime,
        'closing_time': closingTime,
        'weekly_offs': weeklyOffs,
        'holidays': holidays,
      };

      final response = await ApiService.put(url, data);
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        return Map<String, dynamic>.from(body['data'] ?? {});
      } else {
        throw Exception(body['message'] ?? 'Failed to update lab config');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch test master items
  Future<List<Map<String, dynamic>>> fetchTestMaster() async {
    try {
      final url = '$baseUrl/lab/test-master';
      final response = await ApiService.get(url);
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch test master');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Update test master item
  Future<Map<String, dynamic>> updateTestMaster({
    required int id,
    String? testName,
    int? processingDurationMinutes,
  }) async {
    try {
      final url = '$baseUrl/lab/test-master/$id';
      final Map<String, dynamic> data = {
        if (testName != null) 'test_name': testName,
        if (processingDurationMinutes != null) 'processing_duration_minutes': processingDurationMinutes,
      };

      final response = await ApiService.put(url, data);
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        return Map<String, dynamic>.from(body['data'] ?? {});
      } else {
        throw Exception(body['message'] ?? 'Failed to update test master');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch all lab technicians
  Future<List<Map<String, dynamic>>> fetchTechnicians() async {
    try {
      final url = '$baseUrl/lab/resources/technicians';
      final response = await ApiService.get(url);
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch technicians');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Update lab technician status
  Future<Map<String, dynamic>> updateTechnicianStatus({
    required int id,
    required String status,
  }) async {
    try {
      final url = '$baseUrl/lab/resources/technicians/$id';
      final Map<String, dynamic> data = {
        'status': status,
      };

      final response = await ApiService.put(url, data);
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        return Map<String, dynamic>.from(body['data'] ?? {});
      } else {
        throw Exception(body['message'] ?? 'Failed to update technician status');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch all lab machines
  Future<List<Map<String, dynamic>>> fetchMachines() async {
    try {
      final url = '$baseUrl/lab/resources/machines';
      final response = await ApiService.get(url);
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch machines');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Update lab machine status
  Future<Map<String, dynamic>> updateMachineStatus({
    required int id,
    required String status,
  }) async {
    try {
      final url = '$baseUrl/lab/resources/machines/$id';
      final Map<String, dynamic> data = {
        'status': status,
      };

      final response = await ApiService.put(url, data);
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        return Map<String, dynamic>.from(body['data'] ?? {});
      } else {
        throw Exception(body['message'] ?? 'Failed to update machine status');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
