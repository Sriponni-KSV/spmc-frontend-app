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
      permissions: json['permissions'] != null 
          ? List<String>.from(json['permissions']) 
          : [],
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
