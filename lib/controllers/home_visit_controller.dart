import 'package:flutter/foundation.dart';
import '../models/home_visit_model.dart';
import '../services/home_visit_service.dart';

class HomeVisitController with ChangeNotifier {
  final HomeVisitService _service = HomeVisitService();

  List<HomeVisitModel> _visits = [];
  HomeVisitModel? _selectedVisit;
  bool _isLoading = false;
  String? _errorMessage;

  List<HomeVisitModel> get visits => _visits;
  HomeVisitModel? get selectedVisit => _selectedVisit;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Load visits
  Future<void> fetchVisits({int? nurseId, String? status}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _visits = await _service.getHomeVisits(nurseId: nurseId, status: status);
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load single visit details
  Future<void> fetchVisitDetails(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedVisit = await _service.getHomeVisitById(id);
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create/Schedule visit
  Future<HomeVisitModel?> createVisit(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newVisit = await _service.createHomeVisit(data);
      _visits.insert(0, newVisit);
      return newVisit;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Record Vitals
  Future<bool> submitVitals(int visitId, Map<String, dynamic> vitalsData) async {
    try {
      await _service.recordVitals(visitId, vitalsData);
      await fetchVisitDetails(visitId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  // Record Care Activities
  Future<bool> submitCareActivities(int visitId, Map<String, dynamic> careData) async {
    try {
      await _service.recordCareActivities(visitId, careData);
      await fetchVisitDetails(visitId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  // Record Medicine
  Future<bool> submitMedicine(int visitId, Map<String, dynamic> medData) async {
    try {
      await _service.recordMedicine(visitId, medData);
      await fetchVisitDetails(visitId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  // Toggle Medicine Daily Dose Checklist Day
  Future<bool> toggleMedicineDay(int visitId, int medId, Map<String, bool> days) async {
    try {
      if (_selectedVisit != null) {
        for (var med in _selectedVisit!.medicines) {
          if (med.id == medId) {
            med.administeredDays.addAll(days);
            break;
          }
        }
        notifyListeners();
      }
      await _service.updateMedicineAdministeredDays(visitId, medId, days);
      await fetchVisitDetails(visitId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  // Record Carried Kit Item / Device
  Future<bool> submitCarriedItem(int visitId, Map<String, dynamic> itemData) async {
    try {
      await _service.recordCarriedItem(visitId, itemData);
      await fetchVisitDetails(visitId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  // Remove Carried Kit Item / Device
  Future<bool> removeCarriedItem(int visitId, int itemId) async {
    try {
      await _service.deleteCarriedItem(visitId, itemId);
      await fetchVisitDetails(visitId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  // Record Consumable
  Future<bool> submitConsumable(int visitId, Map<String, dynamic> consData) async {
    try {
      await _service.recordConsumable(visitId, consData);
      await fetchVisitDetails(visitId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  // Upload Photo
  Future<bool> submitPhotoEvidence(int visitId, String photoUrl, String category, String caption) async {
    try {
      await _service.uploadPhotoEvidence(visitId, photoUrl, category, caption);
      await fetchVisitDetails(visitId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  // Verify Visit & Generate Bill
  Future<Map<String, dynamic>?> verifyVisit(
      int visitId, String attenderName, String attenderRelation, String signatureUrl) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _service.verifyAndGenerateBill(visitId, attenderName, attenderRelation, signatureUrl);
      await fetchVisitDetails(visitId);
      return res;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update Vitals Schedule Config
  Future<bool> updateVitalsConfig(String startTime, String endTime, int intervalMinutes) async {
    try {
      await _service.updateVitalsConfig(startTime, endTime, intervalMinutes);
      if (_selectedVisit != null) {
        await fetchVisitDetails(_selectedVisit!.id);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  List<ProcedureMasterModel> _proceduresMaster = [];
  List<ProcedureMasterModel> get proceduresMaster => _proceduresMaster;

  // Fetch Procedure Master List
  Future<void> fetchProceduresMaster() async {
    try {
      _proceduresMaster = await _service.fetchProceduresMaster();
      notifyListeners();
    } catch (_) {}
  }

  // Record Procedure Item
  Future<bool> recordProcedure(int visitId, Map<String, dynamic> procedureData) async {
    try {
      await _service.recordProcedure(visitId, procedureData);

      if (_selectedVisit != null && _selectedVisit!.id == visitId) {
        final charge = double.tryParse(procedureData['charge_per_procedure']?.toString() ?? '0') ?? 0.0;
        final mult = int.tryParse(procedureData['frequency_multiplier']?.toString() ?? '1') ?? 1;
        final newProc = HomeVisitProcedureModel(
          visitId: visitId,
          procedureId: procedureData['procedure_id'] != null ? int.tryParse(procedureData['procedure_id'].toString()) : null,
          procedureName: procedureData['procedure_name'] ?? '',
          chargePerProcedure: charge,
          frequency: procedureData['frequency'] ?? 'Once Daily',
          frequencyMultiplier: mult,
          durationDays: int.tryParse(procedureData['duration_days']?.toString() ?? '1') ?? 1,
          totalProcedureCharge: charge * mult,
          createdAt: DateTime.now().toIso8601String(),
        );

        final updatedProcedures = List<HomeVisitProcedureModel>.from(_selectedVisit!.procedures)..insert(0, newProc);
        _selectedVisit = _selectedVisit!.copyWith(procedures: updatedProcedures);
        notifyListeners();
      }

      await fetchVisitDetails(visitId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  // Cancel / Discontinue visit
  Future<bool> cancelVisit(int visitId, String reason, String notes) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.cancelHomeVisit(visitId, reason, notes);
      await fetchVisits();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

