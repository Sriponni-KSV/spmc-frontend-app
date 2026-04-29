class UserModel {
  final int id;
  final String fullname;
  final String email;
  final String role;
  final String status;
  final String? medicalLicense;
  final int? specializationId;
  final String? specialization;
  final String? staffUniqueId;
  final String? token;
  
  // Profile Fields
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
  final List<String> permissions;
  final Map<String, String> permissionDisplayMap;

  UserModel({
    required this.id,
    required this.fullname,
    required this.email,
    required this.role,
    this.status = 'active',
    this.medicalLicense,
    this.specializationId,
    this.specialization,
    this.staffUniqueId,
    this.token,
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
    this.permissions = const [],
    this.permissionDisplayMap = const {},
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<String> perms = [];
    Map<String, String> displays = {};

    if (json['permissions'] != null && json['permissions'] is List) {
      for (var p in json['permissions']) {
        if (p is String) {
          perms.add(p);
        } else if (p is Map) {
          final name = p['permission_name']?.toString();
          final display = p['display_name']?.toString();
          if (name != null) {
            perms.add(name);
            if (display != null) {
              displays[name] = display;
            }
          }
        }
      }
    }

    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      fullname: json['fullname'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      status: json['status'] ?? 'active',
      medicalLicense: json['medical_license'],
      specializationId: json['specialization_id'],
      specialization: json['specialization'],
      staffUniqueId: json['staff_unique_id'],
      token: json['token'],
      experience: json['experience'],
      numberPatientsAttended: json['patients_attended'] != null ? (json['patients_attended'] is int ? json['patients_attended'] : int.tryParse(json['patients_attended'].toString())) : null,
      qualification: json['qualification'],
      bio: json['bio'],
      availableDays: json['available_days'] != null ? List<String>.from(json['available_days']) : null,
      slotStartTime: json['slot_start_time'],
      slotEndTime: json['slot_end_time'],
      slotDuration: json['slot_duration'],
      weeklyOffDays: json['weekly_off_days'] != null ? List<String>.from(json['weekly_off_days']) : null,
      specificLeaveDates: json['specific_leave_dates'] != null ? List<String>.from(json['specific_leave_dates']) : null,
      clinicName: json['clinic_name'],
      clinicLocation: json['clinic_location'],
      consultationFee: json['consultation_fee']?.toString(),
      areasOfExpertise: json['areas_of_expertise'],
      permissions: perms,
      permissionDisplayMap: displays,
    );
  }

  UserModel copyWith({
    int? id,
    String? fullname,
    String? email,
    String? role,
    String? status,
    String? medicalLicense,
    int? specializationId,
    String? specialization,
    String? staffUniqueId,
    String? token,
    String? experience,
    int? numberPatientsAttended,
    String? qualification,
    String? bio,
    List<String>? availableDays,
    String? slotStartTime,
    String? slotEndTime,
    String? slotDuration,
    List<String>? weeklyOffDays,
    List<String>? specificLeaveDates,
    String? clinicName,
    String? clinicLocation,
    String? consultationFee,
    String? areasOfExpertise,
    List<String>? permissions,
    Map<String, String>? permissionDisplayMap,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullname: fullname ?? this.fullname,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      medicalLicense: medicalLicense ?? this.medicalLicense,
      specializationId: specializationId ?? this.specializationId,
      specialization: specialization ?? this.specialization,
      staffUniqueId: staffUniqueId ?? this.staffUniqueId,
      token: token ?? this.token,
      experience: experience ?? this.experience,
      numberPatientsAttended: numberPatientsAttended ?? this.numberPatientsAttended,
      qualification: qualification ?? this.qualification,
      bio: bio ?? this.bio,
      availableDays: availableDays ?? this.availableDays,
      slotStartTime: slotStartTime ?? this.slotStartTime,
      slotEndTime: slotEndTime ?? this.slotEndTime,
      slotDuration: slotDuration ?? this.slotDuration,
      weeklyOffDays: weeklyOffDays ?? this.weeklyOffDays,
      specificLeaveDates: specificLeaveDates ?? this.specificLeaveDates,
      clinicName: clinicName ?? this.clinicName,
      clinicLocation: clinicLocation ?? this.clinicLocation,
      consultationFee: consultationFee ?? this.consultationFee,
      areasOfExpertise: areasOfExpertise ?? this.areasOfExpertise,
      permissions: permissions ?? this.permissions,
      permissionDisplayMap: permissionDisplayMap ?? this.permissionDisplayMap,
    );
  }

  UserModel updateFromPermissions(List<dynamic> jsonList) {
    List<String> perms = [];
    Map<String, String> displays = {};

    for (var p in jsonList) {
      if (p is String) {
        perms.add(p);
      } else if (p is Map) {
        final name = p['permission_name']?.toString();
        final display = p['display_name']?.toString();
        if (name != null) {
          perms.add(name);
          if (display != null) {
            displays[name] = display;
          }
        }
      }
    }

    return copyWith(
      permissions: perms,
      permissionDisplayMap: displays,
    );
  }

  bool hasPermission(String permission) {
    if (role == 'Super Admin') return true;
    return permissions.contains(permission);
  }
}
