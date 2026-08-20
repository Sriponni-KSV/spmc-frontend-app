import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/home_visit_model.dart';
import 'api_service.dart';

class HomeVisitService {
  String get baseUrl {
    final url = dotenv.env['BASE_URL'] ?? 'http://localhost:3001/api';
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  // Fetch list of home visits
  Future<List<HomeVisitModel>> getHomeVisits({int? nurseId, String? status, int? patientId}) async {
    try {
      String endpoint = '$baseUrl/home-visits?';
      if (nurseId != null) endpoint += 'nurse_id=$nurseId&';
      if (status != null) endpoint += 'status=$status&';
      if (patientId != null) endpoint += 'patient_id=$patientId&';

      final response = await ApiService.get(endpoint);
      final body = ApiService.decodeJsonResponse(response);

      if (body['success'] == true && body['data'] is List) {
        return (body['data'] as List)
            .map((item) => HomeVisitModel.fromJson(item))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load home visits: ${e.toString().replaceAll("Exception: ", "")}');
    }
  }

  // Get home visit detail
  Future<HomeVisitModel> getHomeVisitById(int id) async {
    try {
      final response = await ApiService.get('$baseUrl/home-visits/$id');
      final body = ApiService.decodeJsonResponse(response);

      if (body['success'] == true && body['data'] != null) {
        return HomeVisitModel.fromJson(body['data']);
      }
      throw Exception(body['message'] ?? 'Failed to load home visit details');
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Schedule a new home visit
  Future<HomeVisitModel> createHomeVisit(Map<String, dynamic> data) async {
    try {
      final response = await ApiService.post('$baseUrl/home-visits', data);
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 201 || body['success'] == true) {
        return HomeVisitModel.fromJson(body['data']);
      }
      throw Exception(body['message'] ?? 'Failed to schedule home visit');
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Record vitals
  Future<void> recordVitals(int visitId, Map<String, dynamic> vitalsData) async {
    try {
      final response = await ApiService.post('$baseUrl/home-visits/$visitId/vitals', vitalsData);
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to record vitals');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Delete vitals entry
  Future<void> deleteVitals(int visitId, int vitalId) async {
    try {
      final response = await ApiService.delete('$baseUrl/home-visits/$visitId/vitals/$vitalId');
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to delete vitals entry');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Record care activities
  Future<void> recordCareActivities(int visitId, Map<String, dynamic> careData) async {
    try {
      final response = await ApiService.post('$baseUrl/home-visits/$visitId/care-activities', careData);
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to record care activities');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Record medicine administered
  Future<void> recordMedicine(int visitId, Map<String, dynamic> medData) async {
    try {
      final response = await ApiService.post('$baseUrl/home-visits/$visitId/medicines', medData);
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to log medicine');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Update recorded medicine item
  Future<void> updateMedicine(int visitId, int medId, Map<String, dynamic> medData) async {
    try {
      final response = await ApiService.put('$baseUrl/home-visits/$visitId/medicines/$medId', medData);
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to update medicine');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Delete recorded medicine item
  Future<void> deleteMedicine(int visitId, int medId) async {
    try {
      final response = await ApiService.delete('$baseUrl/home-visits/$visitId/medicines/$medId');
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to delete medicine');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Update medicine daily administration days checklist
  Future<void> updateMedicineAdministeredDays(int visitId, int medId, Map<String, bool> days) async {
    try {
      final response = await ApiService.put(
        '$baseUrl/home-visits/$visitId/medicines/$medId/administered-days',
        {'administered_days': days},
      );
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to update daily administration status');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Record Carried Item
  Future<void> recordCarriedItem(int visitId, Map<String, dynamic> itemData) async {
    try {
      var response = await ApiService.post('$baseUrl/home-visits/$visitId/carried-items', itemData);
      var body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        response = await ApiService.post('$baseUrl/home-visits/$visitId/care-activities', {
          'is_carried_item': true,
          'carried_item': itemData,
        });
        body = ApiService.decodeJsonResponse(response);
      }
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to add kit item');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Delete Carried Item
  Future<void> deleteCarriedItem(int visitId, int itemId) async {
    try {
      final response = await ApiService.delete('$baseUrl/home-visits/$visitId/carried-items/$itemId');
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to delete kit item');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Record consumable item used
  Future<void> recordConsumable(int visitId, Map<String, dynamic> consData) async {
    try {
      final response = await ApiService.post('$baseUrl/home-visits/$visitId/consumables', consData);
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to log consumable item');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Upload time-based photo evidence
  Future<void> uploadPhotoEvidence(int visitId, String photoUrl, String category, String caption) async {
    try {
      final response = await ApiService.post('$baseUrl/home-visits/$visitId/photos', {
        'photo_url': photoUrl,
        'category': category,
        'caption': caption,
      });
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to upload photo evidence');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Delete photo evidence
  Future<void> deletePhotoEvidence(int visitId, int photoId) async {
    try {
      final response = await ApiService.delete('$baseUrl/home-visits/$visitId/photos/$photoId');
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to delete photo evidence');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Verify visit with attender signature & trigger auto-billing
  Future<Map<String, dynamic>> verifyAndGenerateBill(
      int visitId, String attenderName, String attenderRelation, String signatureUrl) async {
    try {
      final response = await ApiService.post('$baseUrl/home-visits/$visitId/verify-and-bill', {
        'attender_name': attenderName,
        'attender_relation': attenderRelation,
        'attender_signature_url': signatureUrl,
      });
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] == true && body['data'] != null) {
        return body['data'];
      }
      throw Exception(body['message'] ?? 'Failed to verify visit & generate billing details');
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Update vitals schedule config
  Future<void> updateVitalsConfig(String startTime, String endTime, int intervalMinutes) async {
    try {
      final response = await ApiService.put('$baseUrl/home-visits/vitals-config', {
        'start_time': startTime,
        'end_time': endTime,
        'interval_minutes': intervalMinutes,
      });
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to update vitals schedule configuration');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Get vitals status for a visit
  Future<VitalsScheduleStatusModel> getVitalsScheduleStatus(int visitId) async {
    try {
      final response = await ApiService.get('$baseUrl/home-visits/$visitId/vitals-status');
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] == true && body['data'] != null) {
        return VitalsScheduleStatusModel.fromJson(body['data']);
      }
      throw Exception(body['message'] ?? 'Failed to fetch vitals status');
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Cancel / Discontinue home visit care
  Future<void> cancelHomeVisit(int visitId, String reason, String notes) async {
    try {
      final response = await ApiService.put('$baseUrl/home-visits/$visitId/cancel', {
        'reason': reason,
        'notes': notes,
      });
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to discontinue home visit care');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Fetch Procedure Master Catalog List
  Future<List<ProcedureMasterModel>> fetchProceduresMaster() async {
    try {
      final response = await ApiService.get('$baseUrl/home-visits/procedures-master');
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] == true && body['data'] is List) {
        return (body['data'] as List)
            .map((item) => ProcedureMasterModel.fromJson(item))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Record Procedure Item
  Future<void> recordProcedure(int visitId, Map<String, dynamic> procedureData) async {
    try {
      final response = await ApiService.post('$baseUrl/home-visits/$visitId/procedures', procedureData);
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to record procedure');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Update Procedure Item
  Future<void> updateProcedure(int visitId, int procId, Map<String, dynamic> procData) async {
    try {
      final response = await ApiService.put('$baseUrl/home-visits/$visitId/procedures/$procId', procData);
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to update procedure');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Delete Procedure Item
  Future<void> deleteProcedure(int visitId, int procId) async {
    try {
      final response = await ApiService.delete('$baseUrl/home-visits/$visitId/procedures/$procId');
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to delete procedure');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Fetch Consumables Master List
  Future<List<Map<String, dynamic>>> fetchConsumablesMaster() async {
    try {
      final response = await ApiService.get('$baseUrl/home-visits/consumables-master');
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] == true && body['data'] is List) {
        return List<Map<String, dynamic>>.from(body['data']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Create Procedure Master with Mapped Consumable Items
  Future<void> createProcedureMaster(Map<String, dynamic> procedureData) async {
    try {
      final response = await ApiService.post('$baseUrl/home-visits/procedures-master', procedureData);
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to save procedure');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Add/Map Consumable Item to Existing Procedure
  Future<void> addConsumableToProcedure(int procedureId, Map<String, dynamic> itemData) async {
    try {
      final response = await ApiService.post('$baseUrl/home-visits/procedures-master/$procedureId/consumables', itemData);
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to map consumable item');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Update Procedure Master Entry
  Future<void> updateProcedureMaster(int procedureId, Map<String, dynamic> procData) async {
    try {
      final response = await ApiService.put('$baseUrl/home-visits/procedures-master/$procedureId', procData);
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to update procedure');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Delete/Deactivate Procedure Master
  Future<void> deleteProcedureMaster(int procedureId) async {
    try {
      final response = await ApiService.delete('$baseUrl/home-visits/procedures-master/$procedureId');
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to deactivate procedure');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Remove Consumable Mapping from Procedure
  Future<void> removeConsumableMapping(int procedureId, int mappingId) async {
    try {
      final response = await ApiService.delete('$baseUrl/home-visits/procedures-master/$procedureId/consumables/$mappingId');
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to remove consumable item');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Create Consumable Item Master Directly
  Future<void> createConsumableMaster(Map<String, dynamic> itemData) async {
    try {
      final response = await ApiService.post('$baseUrl/home-visits/consumables-master', itemData);
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to save consumable item');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Update Consumable Item Master Entry
  Future<void> updateConsumableMaster(int id, Map<String, dynamic> itemData) async {
    try {
      final response = await ApiService.put('$baseUrl/home-visits/consumables-master/$id', itemData);
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to update consumable item');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Soft Delete / Deactivate Consumable Item Master
  Future<void> deleteConsumableMaster(int id) async {
    try {
      final response = await ApiService.delete('$baseUrl/home-visits/consumables-master/$id');
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to deactivate consumable item');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Fetch Master Carried Kit Items
  Future<List<Map<String, dynamic>>> fetchKitItemsMaster() async {
    try {
      final response = await ApiService.get('$baseUrl/home-visits/kit-items-master');
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] == true && body['data'] is List) {
        return List<Map<String, dynamic>>.from(body['data']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Create or Update Master Carried Kit Item
  Future<void> createKitItemMaster(Map<String, dynamic> itemData) async {
    try {
      final response = await ApiService.post('$baseUrl/home-visits/kit-items-master', itemData);
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to save kit item');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Update Master Carried Kit Item
  Future<Map<String, dynamic>> updateKitItemMaster(int id, Map<String, dynamic> itemData) async {
    try {
      final response = await ApiService.put('$baseUrl/home-visits/kit-items-master/$id', itemData);
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] == true) {
        return Map<String, dynamic>.from(body['data'] ?? {});
      } else {
        throw Exception(body['message'] ?? 'Failed to update kit item');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Soft Delete / Deactivate Master Carried Kit Item
  Future<void> deleteKitItemMaster(int id) async {
    try {
      final response = await ApiService.delete('$baseUrl/home-visits/kit-items-master/$id');
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to deactivate kit item');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }
}



