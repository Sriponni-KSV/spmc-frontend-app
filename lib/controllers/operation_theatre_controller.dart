import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/operation_theatre_model.dart';
import '../services/api_service.dart';

class OperationTheatreController extends ChangeNotifier {
  static final OperationTheatreController _instance = OperationTheatreController._internal();
  factory OperationTheatreController() => _instance;
  OperationTheatreController._internal();

  String get baseUrl => ApiEndpoints.baseUrl;

  List<OperationTheatreModel> _theatres = [];
  List<OperationTheatreModel> get theatres => List.unmodifiable(_theatres);

  List<OperationTheatreModel> get activeTheatres =>
      _theatres.where((t) => t.isOperational).toList();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DateTime? _lastFetchTime;

  /// Fetches operation theatres from API.
  /// When [includeInactive] is true, returns all theatres (Active, Inactive, Maintenance).
  /// When [includeInactive] is false, returns active & operational theatres for scheduling.
  Future<List<OperationTheatreModel>> fetchTheatres({
    bool includeInactive = false,
    bool forceRefresh = false,
    String? search,
    String? type,
    String? status,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _theatres.isNotEmpty &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!).inMinutes < 2 &&
        search == null &&
        type == null &&
        status == null) {
      return includeInactive ? _theatres : activeTheatres;
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
      if (type != null && type.trim().isNotEmpty && type != 'All') {
        queryParams['type'] = type.trim();
      }
      if (status != null && status.trim().isNotEmpty && status != 'All') {
        queryParams['status'] = status.trim();
      }

      final uri = Uri.parse('$baseUrl/ot/theatres').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final response = await ApiService.get(uri.toString());

      if (response.statusCode == 200) {
        final decoded = ApiService.decodeJsonResponse(response);
        final List list = decoded['data'] ?? [];
        _theatres = list.map((json) => OperationTheatreModel.fromJson(json)).toList();
        _lastFetchTime = DateTime.now();
        _errorMessage = null;
      } else {
        final decoded = ApiService.decodeJsonResponse(response);
        _errorMessage = decoded['message'] ?? 'Failed to load operation theatres (${response.statusCode})';
      }
    } catch (e) {
      _errorMessage = 'Network error fetching operation theatres: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return includeInactive ? _theatres : activeTheatres;
  }

  /// Create a new Operation Theatre
  Future<Map<String, dynamic>> createTheatre({
    required String theatreCode,
    required String theatreName,
    String theatreType = 'Major',
    String? location,
    String status = 'Active',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final body = {
        'theatre_code': theatreCode.trim().toUpperCase(),
        'theatre_name': theatreName.trim(),
        'theatre_type': theatreType.trim(),
        'location': (location ?? '').trim(),
        'status': status.trim(),
      };

      final response = await ApiService.post(
        '$baseUrl/ot/theatres',
        body,
      );

      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded['data'] != null) {
          final newTheatre = OperationTheatreModel.fromJson(decoded['data']);
          _theatres.add(newTheatre);
          _theatres.sort((a, b) => a.theatreCode.compareTo(b.theatreCode));
        }
        await fetchTheatres(includeInactive: true, forceRefresh: true);
        return {'success': true, 'message': decoded['message'] ?? 'Operation Theatre created successfully.'};
      } else {
        return {'success': false, 'message': decoded['message'] ?? 'Failed to create operation theatre.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error creating theatre: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update an existing Operation Theatre
  Future<Map<String, dynamic>> updateTheatre({
    required int id,
    required String theatreCode,
    required String theatreName,
    required String theatreType,
    String? location,
    required String status,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final body = {
        'theatre_code': theatreCode.trim().toUpperCase(),
        'theatre_name': theatreName.trim(),
        'theatre_type': theatreType.trim(),
        'location': (location ?? '').trim(),
        'status': status.trim(),
      };

      final response = await ApiService.put(
        '$baseUrl/ot/theatres/$id',
        body,
      );

      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200) {
        if (decoded['data'] != null) {
          final updated = OperationTheatreModel.fromJson(decoded['data']);
          final idx = _theatres.indexWhere((t) => t.id == id);
          if (idx != -1) {
            _theatres[idx] = updated;
          }
        }
        await fetchTheatres(includeInactive: true, forceRefresh: true);
        return {'success': true, 'message': decoded['message'] ?? 'Operation Theatre updated successfully.'};
      } else {
        return {'success': false, 'message': decoded['message'] ?? 'Failed to update operation theatre.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error updating theatre: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Quick toggle or update theatre status (Active, Inactive, Maintenance)
  Future<Map<String, dynamic>> updateStatus(int id, String status) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.patch(
        '$baseUrl/ot/theatres/$id/status',
        {'status': status},
      );

      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200) {
        await fetchTheatres(includeInactive: true, forceRefresh: true);
        return {'success': true, 'message': decoded['message'] ?? 'Status updated successfully.'};
      } else {
        return {'success': false, 'message': decoded['message'] ?? 'Failed to update theatre status.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error updating status: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete or safely deactivate theatre
  Future<Map<String, dynamic>> deleteTheatre(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.delete('$baseUrl/ot/theatres/$id');
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200) {
        await fetchTheatres(includeInactive: true, forceRefresh: true);
        return {'success': true, 'message': decoded['message'] ?? 'Operation theatre removed.'};
      } else {
        return {'success': false, 'message': decoded['message'] ?? 'Failed to remove theatre.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error removing theatre: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Seed initial standard theatres (MOT-01, MOT-02, MIN-01) without duplicate records
  Future<Map<String, dynamic>> seedDefaultTheatres() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.post(
        '$baseUrl/ot/theatres/seed-defaults',
        {},
      );

      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchTheatres(includeInactive: true, forceRefresh: true);
        return {'success': true, 'message': decoded['message'] ?? 'Initial theatres seeded successfully.'};
      } else {
        return {'success': false, 'message': decoded['message'] ?? 'Failed to seed default theatres.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error seeding theatres: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check whether a theatre code is already used (client-side fast check)
  bool isCodeDuplicate(String code, {int? excludeId}) {
    final clean = code.trim().toLowerCase();
    if (clean.isEmpty) return false;
    return _theatres.any((t) => t.theatreCode.toLowerCase() == clean && (excludeId == null || t.id != excludeId));
  }
}

