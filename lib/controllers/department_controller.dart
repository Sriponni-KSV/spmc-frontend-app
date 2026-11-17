import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/department_model.dart';
import '../services/api_service.dart';

class DepartmentController extends ChangeNotifier {
  static final DepartmentController _instance = DepartmentController._internal();
  factory DepartmentController() => _instance;
  DepartmentController._internal();

  String get baseUrl => ApiEndpoints.baseUrl;

  List<DepartmentModel> _departments = [];
  List<DepartmentModel> get departments => List.unmodifiable(_departments);

  List<DepartmentModel> get activeDepartments =>
      _departments.where((d) => d.isActive).toList();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DateTime? _lastFetchTime;

  /// Fetches departments from centralized Department Master API.
  /// If [forceRefresh] is false and cache is fresh (< 2 mins), returns cached data.
  Future<List<DepartmentModel>> fetchDepartments({
    bool includeInactive = false,
    bool forceRefresh = false,
    String? search,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _departments.isNotEmpty &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!).inMinutes < 2 &&
        search == null) {
      return includeInactive ? _departments : activeDepartments;
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

      final uri = Uri.parse('$baseUrl/departments').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await ApiService.get(uri.toString());

      if (response.statusCode == 200) {
        final decoded = ApiService.decodeJsonResponse(response);
        final List list = decoded['data'] ?? [];
        _departments = list.map((json) => DepartmentModel.fromJson(json)).toList();
        _departments.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _lastFetchTime = DateTime.now();
        _isLoading = false;
        notifyListeners();
        return includeInactive ? _departments : activeDepartments;
      } else {
        final decoded = ApiService.decodeJsonResponse(response);
        _errorMessage = decoded['message'] ?? 'Failed to load departments';
        _isLoading = false;
        notifyListeners();
        return includeInactive ? _departments : activeDepartments;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return includeInactive ? _departments : activeDepartments;
    }
  }

  /// Creates a new department in the centralized Department Master
  Future<DepartmentModel> createDepartment({
    required String name,
    required String code,
    String? description,
    String status = 'Active',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.post('$baseUrl/departments', {
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'description': description?.trim(),
        'status': status,
      });

      final decoded = ApiService.decodeJsonResponse(response);
      if (response.statusCode == 201 && decoded['success'] == true) {
        final newDept = DepartmentModel.fromJson(decoded['data']);
        _departments.add(newDept);
        _departments.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _isLoading = false;
        notifyListeners();
        return newDept;
      } else {
        _isLoading = false;
        notifyListeners();
        throw Exception(decoded['message'] ?? 'Failed to create department');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Updates an existing department
  Future<DepartmentModel> updateDepartment(
    int id, {
    String? name,
    String? code,
    String? description,
    String? status,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name.trim();
      if (code != null) body['code'] = code.trim().toUpperCase();
      if (description != null) body['description'] = description.trim();
      if (status != null) body['status'] = status;

      final response = await ApiService.put('$baseUrl/departments/$id', body);
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && decoded['success'] == true) {
        final updated = DepartmentModel.fromJson(decoded['data']);
        final idx = _departments.indexWhere((d) => d.id == id);
        if (idx != -1) {
          _departments[idx] = updated;
        } else {
          _departments.add(updated);
        }
        _departments.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _isLoading = false;
        notifyListeners();
        return updated;
      } else {
        _isLoading = false;
        notifyListeners();
        throw Exception(decoded['message'] ?? 'Failed to update department');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Toggles status between Active and Inactive
  Future<void> toggleDepartmentStatus(int id, String newStatus) async {
    try {
      final response = await ApiService.patch('$baseUrl/departments/$id/status', {
        'status': newStatus,
      });
      final decoded = ApiService.decodeJsonResponse(response);
      if (response.statusCode == 200 && decoded['success'] == true) {
        final idx = _departments.indexWhere((d) => d.id == id);
        if (idx != -1) {
          _departments[idx] = _departments[idx].copyWith(status: newStatus);
          notifyListeners();
        }
      } else {
        throw Exception(decoded['message'] ?? 'Failed to update status');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches department statistics (doctor count, staff count)
  Future<List<Map<String, dynamic>>> fetchDepartmentStats() async {
    try {
      final response = await ApiService.get('$baseUrl/departments/stats');
      if (response.statusCode == 200) {
        final decoded = ApiService.decodeJsonResponse(response);
        final List list = decoded['data'] ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching department stats: $e');
      return [];
    }
  }

  DepartmentModel? findById(int? id) {
    if (id == null) return null;
    try {
      return _departments.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  DepartmentModel? findByName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final clean = name.trim().toLowerCase();
    try {
      return _departments.firstWhere(
        (d) => d.name.toLowerCase() == clean || d.code.toLowerCase() == clean,
      );
    } catch (_) {
      return null;
    }
  }
}

