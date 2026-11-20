import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/district_model.dart';
import '../services/api_service.dart';

class DistrictController extends ChangeNotifier {
  static final DistrictController _instance = DistrictController._internal();
  factory DistrictController() => _instance;
  DistrictController._internal();

  String get baseUrl => ApiEndpoints.baseUrl;

  List<DistrictModel> _districts = [];
  List<DistrictModel> get districts => List.unmodifiable(_districts);

  List<PincodeModel> _allPincodes = [];
  List<PincodeModel> get allPincodes => List.unmodifiable(_allPincodes);

  final Map<String, List<PincodeModel>> _pincodeCache = {};

  bool _isLoadingDistricts = false;
  bool get isLoadingDistricts => _isLoadingDistricts;

  bool _isLoadingPincodes = false;
  bool get isLoadingPincodes => _isLoadingPincodes;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ================= DISTRICTS =================

  /// Fetch districts from database API
  Future<List<DistrictModel>> fetchDistricts({
    bool includeInactive = false,
    String? search,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _districts.isNotEmpty && search == null) {
      return includeInactive
          ? _districts
          : _districts.where((d) => d.isOperational).toList();
    }

    _isLoadingDistricts = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final statusParam = includeInactive ? 'All' : 'Active';
      var url = '$baseUrl/districts?status=$statusParam';
      if (search != null && search.trim().isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search.trim())}';
      }

      final response = await ApiService.get(url);
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        final List list = body['data'] ?? [];
        _districts = list.map((item) => DistrictModel.fromJson(item)).toList();
        _isLoadingDistricts = false;
        notifyListeners();
        return includeInactive
            ? _districts
            : _districts.where((d) => d.isOperational).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch districts');
      }
    } catch (e) {
      debugPrint('[DistrictController] Error fetching districts: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoadingDistricts = false;
      notifyListeners();
      return _districts;
    }
  }

  /// Create a new district
  Future<Map<String, dynamic>> createDistrict({
    required String name,
    String state = 'Tamil Nadu',
    String? code,
    String status = 'Active',
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = {
        'name': name.trim(),
        'state': state.trim(),
        if (code != null && code.trim().isNotEmpty) 'code': code.trim().toUpperCase(),
        'status': status.trim(),
      };

      final response = await ApiService.post('$baseUrl/districts', body);
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchDistricts(includeInactive: true, forceRefresh: true);
        return {
          'success': true,
          'message': decoded['message'] ?? 'District created successfully',
          'data': decoded['data'],
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to create district',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error creating district: $e',
      };
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Update an existing district
  Future<Map<String, dynamic>> updateDistrict({
    required int id,
    required String name,
    String state = 'Tamil Nadu',
    String? code,
    required String status,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = {
        'name': name.trim(),
        'state': state.trim(),
        'code': (code != null && code.trim().isNotEmpty) ? code.trim().toUpperCase() : null,
        'status': status.trim(),
      };

      final response = await ApiService.put('$baseUrl/districts/$id', body);
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200) {
        await fetchDistricts(includeInactive: true, forceRefresh: true);
        return {
          'success': true,
          'message': decoded['message'] ?? 'District updated successfully',
          'data': decoded['data'],
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to update district',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error updating district: $e',
      };
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Toggle district status (Active <-> Inactive)
  Future<Map<String, dynamic>> toggleDistrictStatus(int id, String currentStatus) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newStatus = currentStatus.toLowerCase() == 'active' ? 'Inactive' : 'Active';
      final response = await ApiService.patch(
        '$baseUrl/districts/$id/status',
        {'status': newStatus},
      );
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200) {
        await fetchDistricts(includeInactive: true, forceRefresh: true);
        return {
          'success': true,
          'message': decoded['message'] ?? 'District status updated to $newStatus',
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to toggle district status',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error updating district status: $e',
      };
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Delete a district
  Future<Map<String, dynamic>> deleteDistrict(int id) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.delete('$baseUrl/districts/$id');
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200) {
        _pincodeCache.clear();
        await fetchDistricts(includeInactive: true, forceRefresh: true);
        await fetchAllPincodes(forceRefresh: true);
        return {
          'success': true,
          'message': decoded['message'] ?? 'District deleted successfully',
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to delete district',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error deleting district: $e',
      };
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ================= PIN CODES CATALOG =================

  /// Fetch all PIN codes across all districts for Master Catalog
  Future<List<PincodeModel>> fetchAllPincodes({
    String? search,
    int? districtId,
    String? status,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _allPincodes.isNotEmpty && search == null && districtId == null && status == null) {
      return _allPincodes;
    }

    _isLoadingPincodes = true;
    _errorMessage = null;
    notifyListeners();

    try {
      var url = '$baseUrl/districts/pincodes/all?status=${status ?? 'All'}';
      if (search != null && search.trim().isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search.trim())}';
      }
      if (districtId != null && districtId > 0) {
        url += '&district_id=$districtId';
      }

      final response = await ApiService.get(url);
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        final List list = body['data'] ?? [];
        _allPincodes = list.map((item) => PincodeModel.fromJson(item)).toList();
        _isLoadingPincodes = false;
        notifyListeners();
        return _allPincodes;
      } else {
        // Fallback: If /pincodes/all endpoint is not yet loaded (e.g. backend server awaiting restart),
        // gracefully fetch pincodes across available districts using the standard district route
        if (response.statusCode == 404 && _districts.isNotEmpty) {
          final List<PincodeModel> aggregated = [];
          for (final d in _districts) {
            try {
              final enc = Uri.encodeComponent(d.name);
              final r = await ApiService.get('$baseUrl/districts/pincodes?district=$enc');
              final b = ApiService.decodeJsonResponse(r);
              if (r.statusCode == 200 && b['success'] == true) {
                final List pList = b['data'] ?? [];
                aggregated.addAll(pList.map((item) {
                  final map = Map<String, dynamic>.from(item);
                  map['district_name'] = d.name;
                  map['district_state'] = d.state;
                  return PincodeModel.fromJson(map);
                }));
              }
            } catch (_) {}
          }
          if (aggregated.isNotEmpty) {
            _allPincodes = aggregated;
            _isLoadingPincodes = false;
            notifyListeners();
            return _allPincodes;
          }
        }
        throw Exception(body['message'] ?? 'Failed to fetch PIN codes');
      }
    } catch (e) {
      debugPrint('[DistrictController] Error fetching all pincodes: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoadingPincodes = false;
      notifyListeners();
      return _allPincodes;
    }
  }

  /// Create a new PIN code
  Future<Map<String, dynamic>> createPincode({
    required int districtId,
    required String pincode,
    String? postOfficeName,
    String status = 'Active',
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = {
        'district_id': districtId,
        'pincode': pincode.trim(),
        'post_office_name': (postOfficeName != null && postOfficeName.trim().isNotEmpty)
            ? postOfficeName.trim()
            : null,
        'status': status.trim(),
      };

      final response = await ApiService.post('$baseUrl/districts/pincodes', body);
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _pincodeCache.clear();
        await fetchAllPincodes(forceRefresh: true);
        await fetchDistricts(includeInactive: true, forceRefresh: true);
        return {
          'success': true,
          'message': decoded['message'] ?? 'PIN code created successfully',
          'data': decoded['data'],
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to create PIN code',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error creating PIN code: $e',
      };
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Update an existing PIN code
  Future<Map<String, dynamic>> updatePincode({
    required int id,
    required int districtId,
    required String pincode,
    String? postOfficeName,
    required String status,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = {
        'district_id': districtId,
        'pincode': pincode.trim(),
        'post_office_name': (postOfficeName != null && postOfficeName.trim().isNotEmpty)
            ? postOfficeName.trim()
            : null,
        'status': status.trim(),
      };

      final response = await ApiService.put('$baseUrl/districts/pincodes/$id', body);
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200) {
        _pincodeCache.clear();
        await fetchAllPincodes(forceRefresh: true);
        await fetchDistricts(includeInactive: true, forceRefresh: true);
        return {
          'success': true,
          'message': decoded['message'] ?? 'PIN code updated successfully',
          'data': decoded['data'],
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to update PIN code',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error updating PIN code: $e',
      };
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Toggle PIN code status (Active <-> Inactive)
  Future<Map<String, dynamic>> togglePincodeStatus(int id, String currentStatus) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newStatus = currentStatus.toLowerCase() == 'active' ? 'Inactive' : 'Active';
      final response = await ApiService.patch(
        '$baseUrl/districts/pincodes/$id/status',
        {'status': newStatus},
      );
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200) {
        _pincodeCache.clear();
        await fetchAllPincodes(forceRefresh: true);
        return {
          'success': true,
          'message': decoded['message'] ?? 'PIN code status updated to $newStatus',
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to toggle PIN code status',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error updating PIN code status: $e',
      };
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Delete a PIN code
  Future<Map<String, dynamic>> deletePincode(int id) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.delete('$baseUrl/districts/pincodes/$id');
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200) {
        _pincodeCache.clear();
        await fetchAllPincodes(forceRefresh: true);
        await fetchDistricts(includeInactive: true, forceRefresh: true);
        return {
          'success': true,
          'message': decoded['message'] ?? 'PIN code deleted successfully',
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to delete PIN code',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error deleting PIN code: $e',
      };
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Re-seed standardized default Tamil Nadu districts & India Post PIN codes
  Future<Map<String, dynamic>> seedDefaults() async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.post('$baseUrl/districts/seed-defaults', {});
      final decoded = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && decoded['success'] == true) {
        _pincodeCache.clear();
        await fetchDistricts(includeInactive: true, forceRefresh: true);
        await fetchAllPincodes(forceRefresh: true);
        return {
          'success': true,
          'message': decoded['message'] ?? 'Standard Tamil Nadu districts and PIN codes seeded.',
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to seed standard district data.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error seeding data: $e',
      };
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ================= EXISTING HELPERS FOR REGISTRATION =================

  /// Fetch PIN codes for a given district name or ID (used by Patient Registration selector)
  Future<List<PincodeModel>> fetchPincodesForDistrict(String districtNameOrId, {bool forceRefresh = false}) async {
    final cleanKey = districtNameOrId.trim().toLowerCase();
    if (cleanKey.isEmpty) return [];

    if (!forceRefresh && _pincodeCache.containsKey(cleanKey)) {
      return _pincodeCache[cleanKey]!;
    }

    _isLoadingPincodes = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final encodedDistrict = Uri.encodeComponent(districtNameOrId.trim());
      final response = await ApiService.get('$baseUrl/districts/pincodes?district=$encodedDistrict');
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        final List list = body['data'] ?? [];
        final pincodes = list.map((item) => PincodeModel.fromJson(item)).toList();
        _pincodeCache[cleanKey] = pincodes;
        _isLoadingPincodes = false;
        notifyListeners();
        return pincodes;
      } else {
        _isLoadingPincodes = false;
        notifyListeners();
        return [];
      }
    } catch (e) {
      debugPrint('[DistrictController] Error fetching pincodes for $districtNameOrId: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoadingPincodes = false;
      notifyListeners();
      return [];
    }
  }

  /// Validate that a PIN code belongs to a district
  Future<bool> validatePincode(String district, String pincode) async {
    final cleanDistrict = district.trim();
    final cleanPincode = pincode.trim();

    if (cleanDistrict.isEmpty || cleanPincode.length != 6) {
      return false;
    }

    try {
      final encDistrict = Uri.encodeComponent(cleanDistrict);
      final encPincode = Uri.encodeComponent(cleanPincode);
      final response = await ApiService.get('$baseUrl/districts/validate?district=$encDistrict&pincode=$encPincode');
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        return body['isValid'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[DistrictController] Error validating pincode: $e');
      return true; // Fallback to allowing user input if network check fails
    }
  }
}
