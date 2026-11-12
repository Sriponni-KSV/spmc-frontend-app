class DoctorModel {
  final String? medicalLicense;
  final int? specializationId;
  final String? specialization;
  final String? experience;
  final int? numberPatientsAttended;
  final String? qualification;
  final String? bio;
  final List<String>? availableDays;
  final String? slotStartTime;
  final String? slotEndTime;
  final String? slotDuration;
  final List<String>? weeklyOffDays;
  final List<String>? specificLeaveDates;
  final String? clinicName;
  final String? clinicLocation;
  final String? consultationFee;
  final String? areasOfExpertise;
  final int? followupValidityDays;
  final String? followupFee;
  final String? morningStartTime;
  final String? morningEndTime;
  final String? eveningStartTime;
  final String? eveningEndTime;

  DoctorModel({
    this.medicalLicense,
    this.specializationId,
    this.specialization,
    this.experience,
    this.numberPatientsAttended,
    this.qualification,
    this.bio,
    this.availableDays,
    this.slotStartTime,
    this.slotEndTime,
    this.slotDuration,
    this.weeklyOffDays,
    this.specificLeaveDates,
    this.clinicName,
    this.clinicLocation,
    this.consultationFee,
    this.areasOfExpertise,
    this.followupValidityDays,
    this.followupFee,
    this.morningStartTime,
    this.morningEndTime,
    this.eveningStartTime,
    this.eveningEndTime,
  });

  static List<String>? _parseList(dynamic val) {
    if (val == null) return null;
    if (val is List) return val.map((e) => e.toString()).toList();
    if (val is String) {
      if (val.startsWith('{') && val.endsWith('}')) {
        return val.substring(1, val.length - 1).split(',').where((e) => e.isNotEmpty).map((e) => e.trim()).toList();
      }
      if (val.isEmpty) return [];
      return [val];
    }
    return null;
  }

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      medicalLicense: json['medical_license'] ?? json['medicalLicense'],
      specializationId: json['specialization_id'] ?? json['specializationId'],
      specialization: json['specialization'],
      experience: (json['experience'] ?? json['Experience'])?.toString(),
      numberPatientsAttended: (json['patients_attended'] ?? json['patientsAttended']) != null 
          ? int.tryParse((json['patients_attended'] ?? json['patientsAttended']).toString())
          : null,
      qualification: json['qualification'] ?? json['Qualification'],
      bio: json['bio'] ?? json['Bio'],
      availableDays: _parseList(json['available_days'] ?? json['availableDays']),
      slotStartTime: json['slot_start_time'] ?? json['slotStartTime'],
      slotEndTime: json['slot_end_time'] ?? json['slotEndTime'],
      slotDuration: json['slot_duration'] ?? json['slotDuration'],
      weeklyOffDays: _parseList(json['weekly_off_days'] ?? json['weeklyOffDays']),
      specificLeaveDates: _parseList(json['specific_leave_dates'] ?? json['specificLeaveDates']),
      clinicName: json['clinic_name'] ?? json['clinicName'],
      clinicLocation: json['clinic_location'] ?? json['clinicLocation'],
      consultationFee: (json['consultation_fee'] ?? json['consultationFee'])?.toString(),
      areasOfExpertise: json['areas_of_expertise'] ?? json['areasOfExpertise'],
      followupValidityDays: json['followup_validity_days'] != null ? int.tryParse(json['followup_validity_days'].toString()) : 7,
      followupFee: (json['followup_fee'] ?? '0.00')?.toString(),
      morningStartTime: json['morning_start_time'] ?? json['morningStartTime'],
      morningEndTime: json['morning_end_time'] ?? json['morningEndTime'],
      eveningStartTime: json['evening_start_time'] ?? json['eveningStartTime'],
      eveningEndTime: json['evening_end_time'] ?? json['eveningEndTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medical_license': medicalLicense,
      'specialization_id': specializationId,
      'specialization': specialization,
      'experience': experience,
      'patients_attended': numberPatientsAttended,
      'qualification': qualification,
      'bio': bio,
      'available_days': availableDays,
      'slot_start_time': slotStartTime,
      'slot_end_time': slotEndTime,
      'slot_duration': slotDuration,
      'weekly_off_days': weeklyOffDays,
      'specific_leave_dates': specificLeaveDates,
      'clinic_name': clinicName,
      'clinic_location': clinicLocation,
      'consultation_fee': consultationFee,
      'areas_of_expertise': areasOfExpertise,
      if (followupValidityDays != null) 'followup_validity_days': followupValidityDays,
      if (followupFee != null) 'followup_fee': followupFee,
      if (morningStartTime != null) 'morning_start_time': morningStartTime,
      if (morningEndTime != null) 'morning_end_time': morningEndTime,
      if (eveningStartTime != null) 'evening_start_time': eveningStartTime,
      if (eveningEndTime != null) 'evening_end_time': eveningEndTime,
    };
  }
}
