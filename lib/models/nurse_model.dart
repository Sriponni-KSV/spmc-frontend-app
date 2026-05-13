class NurseModel {
  final String? qualification;
  final String? specialization;
  final String? nursingRegistrationNumber;
  final String? yearsOfExperience;
  final List<String>? workingDays;
  final String? shiftStartTime;
  final String? shiftEndTime;
  final String? shiftType;
  final String? department;
  final String? totalExperience;
  final String? areasOfExpertise;
  final String? registrationCertificate;
  final List<String>? weeklyOffDays;
  final List<String>? specificLeaveDates;

  NurseModel({
    this.qualification,
    this.specialization,
    this.nursingRegistrationNumber,
    this.yearsOfExperience,
    this.workingDays,
    this.shiftStartTime,
    this.shiftEndTime,
    this.shiftType,
    this.department,
    this.totalExperience,
    this.areasOfExpertise,
    this.registrationCertificate,
    this.weeklyOffDays,
    this.specificLeaveDates,
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

  factory NurseModel.fromJson(Map<String, dynamic> json) {
    return NurseModel(
      qualification: json['qualification'] ?? json['Qualification'],
      specialization: json['specialization'],
      nursingRegistrationNumber: json['nursing_registration_number'] ?? json['nursingRegistrationNumber'],
      yearsOfExperience: (json['years_of_experience'] ?? json['yearsOfExperience'])?.toString(),
      workingDays: _parseList(json['working_days'] ?? json['workingDays'] ?? json['available_days']),
      shiftStartTime: json['shift_start_time'] ?? json['shiftStartTime'] ?? json['slot_start_time'],
      shiftEndTime: json['shift_end_time'] ?? json['shiftEndTime'] ?? json['slot_end_time'],
      shiftType: json['shift_type'] ?? json['shiftType'],
      department: json['department'],
      totalExperience: (json['total_experience'] ?? json['totalExperience'])?.toString(),
      areasOfExpertise: json['areas_of_expertise'] ?? json['areasOfExpertise'],
      registrationCertificate: json['registration_certificate'] ?? json['registrationCertificate'],
      weeklyOffDays: _parseList(json['weekly_off_days'] ?? json['weeklyOffDays']),
      specificLeaveDates: _parseList(json['specific_leave_dates'] ?? json['specificLeaveDates']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'qualification': qualification,
      'specialization': specialization,
      'nursing_registration_number': nursingRegistrationNumber,
      'years_of_experience': yearsOfExperience,
      'working_days': workingDays,
      'shift_start_time': shiftStartTime,
      'shift_end_time': shiftEndTime,
      'shift_type': shiftType,
      'department': department,
      'total_experience': totalExperience,
      'areas_of_expertise': areasOfExpertise,
      'registration_certificate': registrationCertificate,
      'weekly_off_days': weeklyOffDays,
      'specific_leave_dates': specificLeaveDates,
    };
  }
}
