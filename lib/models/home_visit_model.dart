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

  HomeVisitCareActivities({
    this.id,
    this.nursingNotes,
    this.dressingProcedures,
    this.nailTrimmingDone = false,
    this.otherCareActivities,
  });

  factory HomeVisitCareActivities.fromJson(Map<String, dynamic> json) {
    return HomeVisitCareActivities(
      id: json['id'],
      nursingNotes: json['nursing_notes'],
      dressingProcedures: json['dressing_procedures'],
      nailTrimmingDone: json['nail_trimming_done'] == true || json['nail_trimming_done'] == 1,
      otherCareActivities: json['other_care_activities'],
    );
  }

  Map<String, dynamic> toJson() => {
        'nursing_notes': nursingNotes,
        'dressing_procedures': dressingProcedures,
        'nail_trimming_done': nailTrimmingDone,
        'other_care_activities': otherCareActivities,
      };
}

class HomeVisitMedicine {
  final int? id;
  final String medicineName;
  final String? dosage;
  final String? route;
  final int quantity;
  final double unitPrice;
  final String? administeredAt;

  HomeVisitMedicine({
    this.id,
    required this.medicineName,
    this.dosage,
    this.route,
    this.quantity = 1,
    this.unitPrice = 0.0,
    this.administeredAt,
  });

  factory HomeVisitMedicine.fromJson(Map<String, dynamic> json) {
    return HomeVisitMedicine(
      id: json['id'],
      medicineName: json['medicine_name'] ?? '',
      dosage: json['dosage'],
      route: json['route'],
      quantity: json['quantity'] != null ? int.tryParse(json['quantity'].toString()) ?? 1 : 1,
      unitPrice: json['unit_price'] != null ? double.tryParse(json['unit_price'].toString()) ?? 0.0 : 0.0,
      administeredAt: json['administered_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'medicine_name': medicineName,
        'dosage': dosage,
        'route': route,
        'quantity': quantity,
        'unit_price': unitPrice,
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
    this.photos = const [],
    this.invoice,
  });

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

