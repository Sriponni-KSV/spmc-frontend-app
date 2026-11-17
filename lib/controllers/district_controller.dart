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

  final Map<String, List<PincodeModel>> _pincodeCache = {};

  bool _isLoadingDistricts = false;
  bool get isLoadingDistricts => _isLoadingDistricts;

  bool _isLoadingPincodes = false;
  bool get isLoadingPincodes => _isLoadingPincodes;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Fetch all districts from the database API
  Future<List<DistrictModel>> fetchDistricts({bool forceRefresh = false}) async {
    if (!forceRefresh && _districts.isNotEmpty) {
      return _districts;
    }

    _isLoadingDistricts = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.get('$baseUrl/districts');
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final List list = body['data'] ?? [];
        _districts = list.map((item) => DistrictModel.fromJson(item)).toList();
        _isLoadingDistricts = false;
        notifyListeners();
        return _districts;
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch districts');
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoadingDistricts = false;
      notifyListeners();
      return _districts;
    }
  }

  /// Fetch PIN codes for a given district name or ID
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
      final body = jsonDecode(response.body);

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
    if (cleanDistrict.isEmpty || cleanPincode.isEmpty || cleanPincode.length != 6) {
      return false;
    }

    // Check in cache first if available
    final cleanKey = cleanDistrict.toLowerCase();
    if (_pincodeCache.containsKey(cleanKey)) {
      final cachedList = _pincodeCache[cleanKey]!;
      if (cachedList.isNotEmpty) {
        return cachedList.any((p) => p.pincode == cleanPincode);
      }
    }

    try {
      final encDistrict = Uri.encodeComponent(cleanDistrict);
      final encPin = Uri.encodeComponent(cleanPincode);
      final response = await ApiService.get('$baseUrl/districts/validate?district=$encDistrict&pincode=$encPin');
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        return body['isValid'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void clearCache() {
    _districts.clear();
    _pincodeCache.clear();
    notifyListeners();
  }
}

