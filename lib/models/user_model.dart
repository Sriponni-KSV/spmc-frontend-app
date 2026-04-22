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
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
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
      numberPatientsAttended: json['number_patients_attended'] != null 
          ? int.tryParse(json['number_patients_attended'].toString()) 
          : null,
      qualification: json['qualification'],
      bio: json['bio'],
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
    );
  }

  bool hasPermission(String permission) {
    if (role == 'Super Admin') return true;
    return permissions.contains(permission);
  }
}
