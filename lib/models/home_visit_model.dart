import 'dart:convert';

class HomeVisitCarriedItem {
  final int? id;
  final int? visitId;
  final String itemType; // Device, Medicine, Consumable
  final String itemName;
  final int quantityCarried;

  HomeVisitCarriedItem({
    this.id,
    this.visitId,
    required this.itemType,
    required this.itemName,
    required this.quantityCarried,
  });

  factory HomeVisitCarriedItem.fromJson(Map<String, dynamic> json) {
    return HomeVisitCarriedItem(
      id: json['id'],
      visitId: json['visit_id'],
      itemType: json['item_type'] ?? 'Consumable',
      itemName: json['item_name'] ?? '',
      quantityCarried: json['quantity_carried'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'item_type': itemType,
        'item_name': itemName,
        'quantity_carried': quantityCarried,
      };
}

class HomeVisitVitals {
  final int? id;
  final int? systolicBp;
  final int? diastolicBp;
  final int? pulseRate;
  final double? temperature;
  final int? spo2;
  final double? bloodSugar;
  final double? weight;
  final double? height;
  final String? recordedAt;

  HomeVisitVitals({
    this.id,
    this.systolicBp,
    this.diastolicBp,
    this.pulseRate,
    this.temperature,
    this.spo2,
    this.bloodSugar,
    this.weight,
    this.height,
    this.recordedAt,
  });

  factory HomeVisitVitals.fromJson(Map<String, dynamic> json) {
    return HomeVisitVitals(
      id: json['id'],
      systolicBp: json['systolic_bp'] != null ? int.tryParse(json['systolic_bp'].toString()) : null,
      diastolicBp: json['diastolic_bp'] != null ? int.tryParse(json['diastolic_bp'].toString()) : null,
      pulseRate: json['pulse_rate'] != null ? int.tryParse(json['pulse_rate'].toString()) : null,
      temperature: json['temperature'] != null ? double.tryParse(json['temperature'].toString()) : null,
      spo2: json['spo2'] != null ? int.tryParse(json['spo2'].toString()) : null,
      bloodSugar: json['blood_sugar'] != null ? double.tryParse(json['blood_sugar'].toString()) : null,
      weight: json['weight'] != null ? double.tryParse(json['weight'].toString()) : null,
      height: json['height'] != null ? double.tryParse(json['height'].toString()) : null,
      recordedAt: json['recorded_at'] ?? json['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'systolic_bp': systolicBp,
        'diastolic_bp': diastolicBp,
        'pulse_rate': pulseRate,
        'temperature': temperature,
        'spo2': spo2,
        'blood_sugar': bloodSugar,
        'weight': weight,
        'height': height,
      };
}

class HomeVisitCareActivities {
  final int? id;
  final String? nursingNotes;
  final String? dressingProcedures;
  final bool nailTrimmingDone;
  final String? otherCareActivities;
  final String? createdAt;

  HomeVisitCareActivities({
    this.id,
    this.nursingNotes,
    this.dressingProcedures,
    this.nailTrimmingDone = false,
    this.otherCareActivities,
    this.createdAt,
  });

  factory HomeVisitCareActivities.fromJson(Map<String, dynamic> json) {
    return HomeVisitCareActivities(
      id: json['id'],
      nursingNotes: json['nursing_notes'],
      dressingProcedures: json['dressing_procedures'],
      nailTrimmingDone: json['nail_trimming_done'] == true || json['nail_trimming_done'] == 1,
      otherCareActivities: json['other_care_activities'],
      createdAt: json['created_at'] != null ? json['created_at'].toString() : json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'nursing_notes': nursingNotes,
        'dressing_procedures': dressingProcedures,
        'nail_trimming_done': nailTrimmingDone,
        'other_care_activities': otherCareActivities,
        'created_at': createdAt,
      };
}

class HomeVisitMedicine {
  final int? id;
  final String medicineName;
  final String? dosage;
  final String? route;
  final String? foodTiming;
  final int quantity;
  final double unitPrice;
  final String medicineType;
  final String? frequency;
  final String? duration;
  final String? givenTime;
  final Map<String, bool> administeredDays;
  final String? administeredAt;

  HomeVisitMedicine({
    this.id,
    required this.medicineName,
    this.dosage,
    this.route,
    this.foodTiming,
    this.quantity = 1,
    this.unitPrice = 0.0,
    this.medicineType = 'Regular',
    this.frequency,
    this.duration,
    this.givenTime,
    this.administeredDays = const {},
    this.administeredAt,
  });

  factory HomeVisitMedicine.fromJson(Map<String, dynamic> json) {
    Map<String, bool> parsedDays = {};
    if (json['administered_days'] != null) {
      try {
        var raw = json['administered_days'];
        if (raw is Map) {
          raw.forEach((k, v) {
            parsedDays[k.toString()] = v == true || v.toString() == 'true';
          });
        } else if (raw is String && raw.trim().isNotEmpty) {
          String cleaned = raw.trim();
          if (cleaned.startsWith("'") || cleaned.contains("'")) {
            cleaned = cleaned.replaceAll("'", '"');
          }
          dynamic decoded = jsonDecode(cleaned);
          if (decoded is String) {
            decoded = jsonDecode(decoded);
          }
          if (decoded is Map) {
            decoded.forEach((k, v) {
              parsedDays[k.toString()] = v == true || v.toString() == 'true';
            });
          }
        }
      } catch (_) {
        final matches = RegExp(r'''['"]?(\d+)['"]?\s*:\s*(true|1)''', caseSensitive: false)
            .allMatches(json['administered_days'].toString());
        for (final m in matches) {
          if (m.group(1) != null) {
            parsedDays[m.group(1)!] = true;
          }
        }
      }
    }

    return HomeVisitMedicine(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      medicineName: json['medicine_name'] ?? '',
      dosage: json['dosage'],
      route: json['route'],
      foodTiming: json['food_timing'] ?? json['food_relation'] ?? json['route'],
      quantity: json['quantity'] != null ? int.tryParse(json['quantity'].toString()) ?? 1 : 1,
      unitPrice: json['unit_price'] != null ? double.tryParse(json['unit_price'].toString()) ?? 0.0 : 0.0,
      medicineType: json['medicine_type'] ?? 'Regular',
      frequency: json['frequency'],
      duration: json['duration'],
      givenTime: json['given_time'],
      administeredDays: parsedDays,
      administeredAt: json['administered_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'medicine_name': medicineName,
        'dosage': dosage,
        'route': route,
        'food_timing': foodTiming,
        'quantity': quantity,
        'unit_price': unitPrice,
        'medicine_type': medicineType,
        'frequency': frequency,
        'duration': duration,
        'given_time': givenTime,
        'administered_days': administeredDays,
        'administered_at': administeredAt,
      };
}

class HomeVisitConsumable {
  final int? id;
  final String itemName;
  final int quantityUsed;
  final double unitPrice;
  final String? createdAt;

  HomeVisitConsumable({
    this.id,
    required this.itemName,
    this.quantityUsed = 1,
    this.unitPrice = 0.0,
    this.createdAt,
  });

  factory HomeVisitConsumable.fromJson(Map<String, dynamic> json) {
    return HomeVisitConsumable(
      id: json['id'],
      itemName: json['item_name'] ?? '',
      quantityUsed: json['quantity_used'] != null ? int.tryParse(json['quantity_used'].toString()) ?? 1 : 1,
      unitPrice: json['unit_price'] != null ? double.tryParse(json['unit_price'].toString()) ?? 0.0 : 0.0,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'item_name': itemName,
        'quantity_used': quantityUsed,
        'unit_price': unitPrice,
        'created_at': createdAt,
      };
}

class HomeVisitPhotoEvidence {
  final int? id;
  final String photoUrl;
  final String? category;
  final String? caption;
  final String? capturedAt;

  HomeVisitPhotoEvidence({
    this.id,
    required this.photoUrl,
    this.category,
    this.caption,
    this.capturedAt,
  });

  factory HomeVisitPhotoEvidence.fromJson(Map<String, dynamic> json) {
    return HomeVisitPhotoEvidence(
      id: json['id'],
      photoUrl: json['photo_url'] ?? '',
      category: json['category'],
      caption: json['caption'],
      capturedAt: json['captured_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'photo_url': photoUrl,
        'category': category,
        'caption': caption,
      };
}

class HomeVisitModel {
  final int id;
  final String visitNumber;
  final int patientId;
  final String? patientName;
  final String? patientDisplayId;
  final String? patientPhone;
  final int? patientAge;
  final String? patientGender;
  final int? nurseId;
  final String? nurseName;
  final String scheduledDate;
  final String? scheduledTime;
  final String? startTime;
  final String? startNurseName;
  final String status; // Scheduled, In-Progress, Completed, Verified, Cancelled
  final String? visitAddress;
  final String? attenderName;
  final String? attenderRelation;
  final String? attenderSignatureUrl;
  final String? signedAt;
  final String? notes;
  final List<HomeVisitCarriedItem> carriedItems;
  final HomeVisitVitals? vitals;
  final List<HomeVisitVitals> vitalsHistory;
  final VitalsScheduleStatusModel? vitalsScheduleStatus;
  final HomeVisitCareActivities? careActivities;
  final List<HomeVisitCareActivities> careActivitiesHistory;
  final List<HomeVisitMedicine> medicines;
  final List<HomeVisitConsumable> consumables;
  final List<HomeVisitProcedureModel> procedures;
  final List<HomeVisitPhotoEvidence> photos;
  final Map<String, dynamic>? invoice;

  HomeVisitModel({
    required this.id,
    required this.visitNumber,
    required this.patientId,
    this.patientName,
    this.patientDisplayId,
    this.patientPhone,
    this.patientAge,
    this.patientGender,
    this.nurseId,
    this.nurseName,
    required this.scheduledDate,
    this.scheduledTime,
    this.startTime,
    this.startNurseName,
    required this.status,
    this.visitAddress,
    this.attenderName,
    this.attenderRelation,
    this.attenderSignatureUrl,
    this.signedAt,
    this.notes,
    this.carriedItems = const [],
    this.vitals,
    this.vitalsHistory = const [],
    this.vitalsScheduleStatus,
    this.careActivities,
    this.careActivitiesHistory = const [],
    this.medicines = const [],
    this.consumables = const [],
    this.procedures = const [],
    this.photos = const [],
    this.invoice,
  });

  HomeVisitModel copyWith({
    int? id,
    String? visitNumber,
    int? patientId,
    String? patientName,
    String? patientDisplayId,
    String? patientPhone,
    int? patientAge,
    String? patientGender,
    int? nurseId,
    String? nurseName,
    String? scheduledDate,
    String? scheduledTime,
    String? startTime,
    String? startNurseName,
    String? status,
    String? visitAddress,
    String? attenderName,
    String? attenderRelation,
    String? attenderSignatureUrl,
    String? signedAt,
    String? notes,
    List<HomeVisitCarriedItem>? carriedItems,
    HomeVisitVitals? vitals,
    List<HomeVisitVitals>? vitalsHistory,
    VitalsScheduleStatusModel? vitalsScheduleStatus,
    HomeVisitCareActivities? careActivities,
    List<HomeVisitCareActivities>? careActivitiesHistory,
    List<HomeVisitMedicine>? medicines,
    List<HomeVisitConsumable>? consumables,
    List<HomeVisitProcedureModel>? procedures,
    List<HomeVisitPhotoEvidence>? photos,
    Map<String, dynamic>? invoice,
  }) {
    return HomeVisitModel(
      id: id ?? this.id,
      visitNumber: visitNumber ?? this.visitNumber,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      patientDisplayId: patientDisplayId ?? this.patientDisplayId,
      patientPhone: patientPhone ?? this.patientPhone,
      patientAge: patientAge ?? this.patientAge,
      patientGender: patientGender ?? this.patientGender,
      nurseId: nurseId ?? this.nurseId,
      nurseName: nurseName ?? this.nurseName,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      startTime: startTime ?? this.startTime,
      startNurseName: startNurseName ?? this.startNurseName,
      status: status ?? this.status,
      visitAddress: visitAddress ?? this.visitAddress,
      attenderName: attenderName ?? this.attenderName,
      attenderRelation: attenderRelation ?? this.attenderRelation,
      attenderSignatureUrl: attenderSignatureUrl ?? this.attenderSignatureUrl,
      signedAt: signedAt ?? this.signedAt,
      notes: notes ?? this.notes,
      carriedItems: carriedItems ?? this.carriedItems,
      vitals: vitals ?? this.vitals,
      vitalsHistory: vitalsHistory ?? this.vitalsHistory,
      vitalsScheduleStatus: vitalsScheduleStatus ?? this.vitalsScheduleStatus,
      careActivities: careActivities ?? this.careActivities,
      careActivitiesHistory: careActivitiesHistory ?? this.careActivitiesHistory,
      medicines: medicines ?? this.medicines,
      consumables: consumables ?? this.consumables,
      procedures: procedures ?? this.procedures,
      photos: photos ?? this.photos,
      invoice: invoice ?? this.invoice,
    );
  }

  String get formattedScheduledDate {
    if (scheduledDate.isEmpty) return '';
    try {
      final parts = scheduledDate.split('T')[0].split('-');
      if (parts.length == 3 && parts[0].length == 4) {
        return '${parts[2]}-${parts[1]}-${parts[0]}'; // dd-mm-yyyy
      }
    } catch (_) {}
    return scheduledDate;
  }

  factory HomeVisitModel.fromJson(Map<String, dynamic> json) {
    return HomeVisitModel(
      id: json['id'],
      visitNumber: json['visit_number'] ?? '',
      patientId: json['patient_id'],
      patientName: json['patient_name'],
      patientDisplayId: json['patient_display_id'],
      patientPhone: json['patient_phone'],
      patientAge: json['patient_age'],
      patientGender: json['patient_gender'],
      nurseId: json['nurse_id'],
      nurseName: json['nurse_name'],
      scheduledDate: json['scheduled_date'] != null ? json['scheduled_date'].toString().split('T')[0] : '',
      scheduledTime: json['scheduled_time'],
      startTime: json['start_time'],
      startNurseName: json['start_nurse_name'],
      status: json['status'] ?? 'Scheduled',
      visitAddress: json['visit_address'],
      attenderName: json['attender_name'],
      attenderRelation: json['attender_relation'],
      attenderSignatureUrl: json['attender_signature_url'],
      signedAt: json['signed_at'],
      notes: json['notes'],
      carriedItems: (json['carried_items'] as List<dynamic>?)
              ?.map((item) => HomeVisitCarriedItem.fromJson(item))
              .toList() ??
          [],
      vitals: json['vitals'] != null ? HomeVisitVitals.fromJson(json['vitals']) : null,
      vitalsHistory: (json['vitals_history'] as List<dynamic>?) != null && (json['vitals_history'] as List<dynamic>).isNotEmpty
          ? (json['vitals_history'] as List<dynamic>).map((v) => HomeVisitVitals.fromJson(v)).toList()
          : (json['vitals'] != null ? [HomeVisitVitals.fromJson(json['vitals'])] : []),
      vitalsScheduleStatus: json['vitals_schedule_status'] != null
          ? VitalsScheduleStatusModel.fromJson(json['vitals_schedule_status'])
          : null,
      careActivities: json['care_activities'] != null
          ? HomeVisitCareActivities.fromJson(json['care_activities'])
          : null,
      careActivitiesHistory: (json['care_activities_history'] as List<dynamic>?) != null && (json['care_activities_history'] as List<dynamic>).isNotEmpty
          ? (json['care_activities_history'] as List<dynamic>).map((c) => HomeVisitCareActivities.fromJson(c)).toList()
          : (json['care_activities'] != null ? [HomeVisitCareActivities.fromJson(json['care_activities'])] : []),
      medicines: (json['medicines'] as List<dynamic>?)
              ?.map((m) => HomeVisitMedicine.fromJson(m))
              .toList() ??
          [],
      consumables: (json['consumables'] as List<dynamic>?)
              ?.map((c) => HomeVisitConsumable.fromJson(c))
              .toList() ??
          [],
      procedures: (json['procedures'] as List<dynamic>?)
              ?.map((p) => HomeVisitProcedureModel.fromJson(p))
              .toList() ??
          [],
      photos: (json['photos'] as List<dynamic>?)
              ?.map((p) => HomeVisitPhotoEvidence.fromJson(p))
              .toList() ??
          [],
      invoice: json['invoice'] is Map<String, dynamic>
          ? json['invoice'] as Map<String, dynamic>
          : (json['invoice_number'] != null
              ? {
                  'invoice_number': json['invoice_number'],
                  'total_amount': json['invoice_total_amount'],
                  'net_amount': json['invoice_net_amount'],
                  'payment_status': json['invoice_payment_status'],
                }
              : null),
    );
  }
}

class ProcedureConsumableMappingModel {
  final int consumableId;
  final String consumableName;
  final String unit;
  final double unitPrice;
  final int qtyPerProcedure;

  ProcedureConsumableMappingModel({
    required this.consumableId,
    required this.consumableName,
    required this.unit,
    this.unitPrice = 0.0,
    required this.qtyPerProcedure,
  });

  factory ProcedureConsumableMappingModel.fromJson(Map<String, dynamic> json) {
    return ProcedureConsumableMappingModel(
      consumableId: json['consumable_id'] ?? 0,
      consumableName: json['consumable_name'] ?? '',
      unit: json['unit'] ?? 'Pc',
      unitPrice: json['unit_price'] != null
          ? double.tryParse(json['unit_price'].toString()) ?? 0.0
          : 0.0,
      qtyPerProcedure: json['qty_per_procedure'] != null
          ? int.tryParse(json['qty_per_procedure'].toString()) ?? 1
          : 1,
    );
  }
}

class ProcedureMasterModel {
  final int id;
  final String name;
  final double procedureCharge;
  final String status;
  final List<ProcedureConsumableMappingModel> mappedConsumables;

  ProcedureMasterModel({
    required this.id,
    required this.name,
    required this.procedureCharge,
    required this.status,
    required this.mappedConsumables,
  });

  factory ProcedureMasterModel.fromJson(Map<String, dynamic> json) {
    return ProcedureMasterModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      procedureCharge: json['procedure_charge'] != null
          ? double.tryParse(json['procedure_charge'].toString()) ?? 0.0
          : 0.0,
      status: json['status'] ?? 'Active',
      mappedConsumables: (json['mapped_consumables'] as List<dynamic>?)
              ?.map((c) => ProcedureConsumableMappingModel.fromJson(c))
              .toList() ??
          [],
    );
  }
}

class HomeVisitProcedureModel {
  final int? id;
  final int visitId;
  final int? procedureId;
  final String procedureName;
  final double chargePerProcedure;
  final String frequency;
  final int frequencyMultiplier;
  final int durationDays;
  final double totalProcedureCharge;
  final String? createdAt;

  HomeVisitProcedureModel({
    this.id,
    required this.visitId,
    this.procedureId,
    required this.procedureName,
    required this.chargePerProcedure,
    required this.frequency,
    required this.frequencyMultiplier,
    required this.durationDays,
    required this.totalProcedureCharge,
    this.createdAt,
  });

  factory HomeVisitProcedureModel.fromJson(Map<String, dynamic> json) {
    return HomeVisitProcedureModel(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      visitId: json['visit_id'] != null ? int.tryParse(json['visit_id'].toString()) ?? 0 : 0,
      procedureId: json['procedure_id'] != null ? int.tryParse(json['procedure_id'].toString()) : null,
      procedureName: json['procedure_name'] ?? '',
      chargePerProcedure: json['charge_per_procedure'] != null
          ? double.tryParse(json['charge_per_procedure'].toString()) ?? 0.0
          : 0.0,
      frequency: json['frequency'] ?? 'Once Daily',
      frequencyMultiplier: json['frequency_multiplier'] != null
          ? int.tryParse(json['frequency_multiplier'].toString()) ?? 1
          : 1,
      durationDays: json['duration_days'] != null
          ? int.tryParse(json['duration_days'].toString()) ?? 1
          : 1,
      totalProcedureCharge: json['total_procedure_charge'] != null
          ? double.tryParse(json['total_procedure_charge'].toString()) ?? 0.0
          : 0.0,
      createdAt: json['created_at'],
    );
  }
}

class VitalsScheduleStatusModel {
  final bool isLocked;
  final String statusCode;
  final String nextAvailableTime;
  final String? lockReason;
  final String startTime;
  final String endTime;
  final int intervalMinutes;
  final int timeRemainingSeconds;
  final String? lastRecordedAt;

  VitalsScheduleStatusModel({
    required this.isLocked,
    required this.statusCode,
    required this.nextAvailableTime,
    this.lockReason,
    required this.startTime,
    required this.endTime,
    required this.intervalMinutes,
    required this.timeRemainingSeconds,
    this.lastRecordedAt,
  });

  factory VitalsScheduleStatusModel.fromJson(Map<String, dynamic> json) {
    return VitalsScheduleStatusModel(
      isLocked: json['is_locked'] ?? false,
      statusCode: json['status_code'] ?? 'UNLOCKED',
      nextAvailableTime: json['next_available_time'] ?? '9:00 AM',
      lockReason: json['lock_reason'],
      startTime: json['start_time'] ?? '9:00 AM',
      endTime: json['end_time'] ?? '6:00 PM',
      intervalMinutes: json['interval_minutes'] ?? 60,
      timeRemainingSeconds: json['time_remaining_seconds'] ?? 0,
      lastRecordedAt: json['last_recorded_at'],
    );
  }
}

