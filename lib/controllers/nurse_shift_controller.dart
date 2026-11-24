import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/nurse_shift_model.dart';
import '../services/api_service.dart';

class NurseShiftController extends ChangeNotifier {
  static final NurseShiftController _instance = NurseShiftController._internal();
  factory NurseShiftController() => _instance;
  NurseShiftController._internal();

  String get baseUrl => ApiEndpoints.baseUrl;

  List<NurseShiftModel> _shiftModels = [];
  List<NurseShiftModel> get shiftModels => List.unmodifiable(_shiftModels);

  List<NurseShiftModel> get activeShiftModels =>
      _shiftModels.where((s) => s.isOperational).toList();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DateTime? _lastFetchTime;

  /// Check whether a shift code already exists in memory
  bool isCodeDuplicate(String code, {int? excludeId}) {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return false;
    return _shiftModels.any(
      (s) => s.code.toUpperCase() == clean && (excludeId == null || s.id != excludeId),
    );
  }

  // --- MODEL-BASED SHIFT CRUD (ADMIN MASTER CATALOG) ---

  Future<List<NurseShiftModel>> fetchShiftModels({
    bool includeInactive = true,
    bool forceRefresh = false,
    String? search,
    String? status,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _shiftModels.isNotEmpty &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!).inMinutes < 2 &&
        search == null &&
        status == null) {
      return includeInactive ? _shiftModels : activeShiftModels;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (includeInactive) queryParams['include_inactive'] = 'true';
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (status != null && status.trim().isNotEmpty && status != 'All') {
        queryParams['status'] = status.trim();
      }

      final uri = Uri.parse('$baseUrl/ipd/admin/shifts').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final response = await ApiService.get(uri.toString());

      if (response.statusCode == 200) {
        final decoded = ApiService.decodeJsonResponse(response);
        final List list = decoded['data'] ?? [];
        _shiftModels = list.map((json) => NurseShiftModel.fromJson(json)).toList();
        _lastFetchTime = DateTime.now();
        _errorMessage = null;
      } else {
        final decoded = ApiService.decodeJsonResponse(response);
        _errorMessage = decoded['message'] ?? 'Failed to load shifts (${response.statusCode})';
      }
    } catch (e) {
      _errorMessage = 'Network error fetching shifts: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return includeInactive ? _shiftModels : activeShiftModels;
  }

  Future<Map<String, dynamic>> createShiftModel({
    required String code,
    required String name,
    required String startTime,
    required String endTime,
    int breakMinutes = 30,
    String? description,
    String status = 'Active',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final body = {
        'code': code.trim().toUpperCase(),
        'name': name.trim(),
        'start_time': startTime.trim(),
        'end_time': endTime.trim(),
        'break_minutes': breakMinutes,
        'description': (description ?? '').trim(),
        'status': status.trim(),
      };

      final response = await ApiService.post('$baseUrl/ipd/admin/shifts', body);
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded['data'] != null) {
          final newShift = NurseShiftModel.fromJson(decoded['data']);
          _shiftModels.add(newShift);
          _shiftModels.sort((a, b) => a.code.compareTo(b.code));
        }
        await fetchShiftModels(includeInactive: true, forceRefresh: true);
        return {'success': true, 'message': decoded['message'] ?? 'Shift created successfully.'};
      } else {
        return {'success': false, 'message': decoded['message'] ?? 'Failed to create shift.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error creating shift: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> updateShiftModel(
    int id, {
    required String code,
    required String name,
    required String startTime,
    required String endTime,
    int breakMinutes = 30,
    String? description,
    String status = 'Active',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final body = {
        'code': code.trim().toUpperCase(),
        'name': name.trim(),
        'start_time': startTime.trim(),
        'end_time': endTime.trim(),
        'break_minutes': breakMinutes,
        'description': (description ?? '').trim(),
        'status': status.trim(),
      };

      final response = await ApiService.put('$baseUrl/ipd/admin/shifts/$id', body);
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200) {
        await fetchShiftModels(includeInactive: true, forceRefresh: true);
        return {'success': true, 'message': decoded['message'] ?? 'Shift updated successfully.'};
      } else {
        return {'success': false, 'message': decoded['message'] ?? 'Failed to update shift.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error updating shift: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> toggleShiftStatus(int id, String newStatus) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.patch(
        '$baseUrl/ipd/admin/shifts/$id/status',
        {'status': newStatus},
      );
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200) {
        await fetchShiftModels(includeInactive: true, forceRefresh: true);
        return {'success': true, 'message': decoded['message'] ?? 'Shift status updated.'};
      } else {
        return {'success': false, 'message': decoded['message'] ?? 'Failed to toggle shift status.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error updating shift status: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> deleteShiftModel(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.delete('$baseUrl/ipd/admin/shifts/$id');
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200) {
        await fetchShiftModels(includeInactive: true, forceRefresh: true);
        return {'success': true, 'message': decoded['message'] ?? 'Shift deleted successfully.'};
      } else {
        return {'success': false, 'message': decoded['message'] ?? 'Failed to delete shift.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error deleting shift: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> seedDefaultShiftModels() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.post('$baseUrl/ipd/admin/shifts/seed-defaults', {});
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchShiftModels(includeInactive: true, forceRefresh: true);
        return {
          'success': true,
          'message': decoded['message'] ?? 'Default shifts configured successfully.',
          'data': decoded['data'],
        };
      } else {
        return {'success': false, 'message': decoded['message'] ?? 'Failed to seed default shifts.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error seeding shifts: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- BACKWARD-COMPATIBLE ADMIN SHIFT METHODS ---

  Future<List<Map<String, dynamic>>> fetchShifts() async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/admin/shifts');
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to fetch shifts',
      );
      if (response.statusCode == 200 && body['success'] == true) {
        final list = List<Map<String, dynamic>>.from(body['data'] ?? []);
        _shiftModels = list.map((json) => NurseShiftModel.fromJson(json)).toList();
        _lastFetchTime = DateTime.now();
        notifyListeners();
        return list;
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
        await fetchShiftModels(includeInactive: true, forceRefresh: true);
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
        await fetchShiftModels(includeInactive: true, forceRefresh: true);
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
        await fetchShiftModels(includeInactive: true, forceRefresh: true);
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
      await fetchShiftModels(includeInactive: true, forceRefresh: true);
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

  Future<Map<String, dynamic>> autoAllocateRosters(String weekStartDate) async {
    try {
      final response = await ApiService.post(
        '$baseUrl/ipd/admin/rosters/auto-allocate',
        {'week_start_date': weekStartDate},
      );
      final body = ApiService.decodeJsonResponse(
        response,
        fallbackMessage: 'Failed to auto-allocate rosters',
      );
      if (response.statusCode == 200 && body['success'] == true) {
        return Map<String, dynamic>.from(body);
      }
      throw Exception(body['message'] ?? 'Failed to auto-allocate rosters');
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
