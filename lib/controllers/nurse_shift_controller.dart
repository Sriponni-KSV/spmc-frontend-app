import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';

class NurseShiftController {
  String get baseUrl => dotenv.env['BASE_URL']!;

  // --- ADMIN SHIFT CONFIG ---

  Future<List<Map<String, dynamic>>> fetchShifts() async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/admin/shifts');
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to fetch shifts',
      );
      if (response.statusCode == 200 && body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['data'] ?? []);
      }
      throw Exception(body['message'] ?? 'Failed to fetch shifts');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>> createShift(
    String name,
    String startTime,
    String endTime,
  ) async {
    try {
      final response = await ApiService.post('$baseUrl/ipd/admin/shifts', {
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
      });
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to create shift',
      );
      if (response.statusCode == 201 && body['success'] == true) {
        return Map<String, dynamic>.from(body['data']);
      }
      throw Exception(body['message'] ?? 'Failed to create shift');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<List<Map<String, dynamic>>> seedDefaultShifts() async {
    try {
      final response = await ApiService.post(
        '$baseUrl/ipd/admin/shifts/seed-defaults',
        {},
      );
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to seed default shifts',
      );
      if (response.statusCode == 201 && body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['data'] ?? []);
      }
      throw Exception(body['message'] ?? 'Failed to seed default shifts');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>> updateShift(
    int id,
    String name,
    String startTime,
    String endTime,
  ) async {
    try {
      final response = await ApiService.put('$baseUrl/ipd/admin/shifts/$id', {
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
      });
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to update shift',
      );
      if (response.statusCode == 200 && body['success'] == true) {
        return Map<String, dynamic>.from(body['data']);
      }
      throw Exception(body['message'] ?? 'Failed to update shift');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> deleteShift(int id) async {
    try {
      final response = await ApiService.delete('$baseUrl/ipd/admin/shifts/$id');
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to delete shift',
      );
      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to delete shift');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // --- ADMIN NURSE ALLOCATIONS ---

  Future<List<Map<String, dynamic>>> fetchAllocations() async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/admin/allocations');
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to fetch allocations',
      );
      if (response.statusCode == 200 && body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['data'] ?? []);
      }
      throw Exception(body['message'] ?? 'Failed to fetch allocations');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>> createAllocation(
    int nurseId,
    int shiftId,
    String wardType,
    String allocationDate,
  ) async {
    try {
      final response = await ApiService.post('$baseUrl/ipd/admin/allocations', {
        'nurse_id': nurseId,
        'shift_id': shiftId,
        'ward_type': wardType,
        'allocation_date': allocationDate,
      });
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to create allocation',
      );
      if (response.statusCode == 201 && body['success'] == true) {
        return Map<String, dynamic>.from(body['data']);
      }
      throw Exception(body['message'] ?? 'Failed to create allocation');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> deleteAllocation(int id) async {
    try {
      final response = await ApiService.delete(
        '$baseUrl/ipd/admin/allocations/$id',
      );
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to delete allocation',
      );
      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to delete allocation');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // --- ADMIN NURSE ROSTERS (WEEKLY TEMPLATES) ---

  Future<List<Map<String, dynamic>>> fetchRosters(String weekStartDate) async {
    try {
      final response = await ApiService.get(
        '$baseUrl/ipd/admin/rosters?week_start_date=$weekStartDate',
      );
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to fetch rosters',
      );
      if (response.statusCode == 200 && body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['data'] ?? []);
      }
      throw Exception(body['message'] ?? 'Failed to fetch rosters');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> saveRosterEntry(
    int nurseId,
    int shiftId,
    String wardType,
    String weekStartDate,
  ) async {
    try {
      final response = await ApiService.post('$baseUrl/ipd/admin/rosters', {
        'nurse_id': nurseId,
        'shift_id': shiftId,
        'ward_type': wardType,
        'week_start_date': weekStartDate,
      });
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to save roster entry',
      );
      if (response.statusCode != 201 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to save roster entry');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> deleteRosterEntry(int id) async {
    try {
      final response = await ApiService.delete(
        '$baseUrl/ipd/admin/rosters/$id',
      );
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to delete roster entry',
      );
      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to delete roster entry');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // --- NURSING STATION & DASHBOARD ---

  Future<Map<String, dynamic>> fetchActiveShift({int? nurseId}) async {
    try {
      final queryParam = nurseId != null ? '?nurse_id=$nurseId' : '';
      final response = await ApiService.get('$baseUrl/ipd/nurse/active-shift$queryParam');
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to fetch active shift details',
      );
      if (response.statusCode == 200 && body['success'] == true) {
        return Map<String, dynamic>.from(body);
      }
      throw Exception(
        body['message'] ?? 'Failed to fetch active shift details',
      );
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<List<Map<String, dynamic>>> fetchHandovers() async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/nurse/handovers');
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to fetch handovers',
      );
      if (response.statusCode == 200 && body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['data'] ?? []);
      }
      throw Exception(body['message'] ?? 'Failed to fetch handovers');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> acknowledgeHandover(int id, {String? notes}) async {
    try {
      final requestBody = <String, dynamic>{};
      if (notes != null) {
        requestBody['notes'] = notes;
      }
      final response = await ApiService.post(
        '$baseUrl/ipd/nurse/handovers/$id/acknowledge',
        requestBody,
      );
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to acknowledge handover',
      );
      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to acknowledge handover');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<List<Map<String, dynamic>>> fetchAuditTrail() async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/nurse/audit');
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to fetch audit trail',
      );
      if (response.statusCode == 200 && body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['data'] ?? []);
      }
      throw Exception(body['message'] ?? 'Failed to fetch audit trail');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>> fetchNurseStats() async {
    try {
      final response = await ApiService.get('$baseUrl/nurse/stats');
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to fetch nurse stats',
      );
      if (response.statusCode == 200 && body['success'] == true) {
        return Map<String, dynamic>.from(body['data'] ?? {});
      }
      throw Exception(body['message'] ?? 'Failed to fetch nurse stats');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
