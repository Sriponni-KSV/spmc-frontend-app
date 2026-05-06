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
    );
  }
}
