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
      fullname: json['fullname'] ?? json['fullName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      status: json['status'] ?? 'active',
      medicalLicense: json['medical_license'] ?? json['medicalLicense'],
      specializationId: json['specialization_id'] ?? json['specializationId'],
      specialization: json['specialization'],
      staffUniqueId: json['staff_unique_id'] ?? json['staffUniqueId'],
      token: json['token'],
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
