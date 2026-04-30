import 'doctor_model.dart';

class UserModel {
  final int id;
  final String fullname;
  final String email;
  final String role;
  final String status;
  final String? staffUniqueId;
  final String? token;
  
  // Isolated Doctor Profile
  final DoctorModel? doctorProfile;

  final List<String> permissions;
  final Map<String, String> permissionDisplayMap;

  // Backward compatibility getters for UI screens
  String? get medicalLicense => doctorProfile?.medicalLicense;
  int? get specializationId => doctorProfile?.specializationId;
  String? get specialization => doctorProfile?.specialization;
  String? get experience => doctorProfile?.experience;
  int? get numberPatientsAttended => doctorProfile?.numberPatientsAttended;
  String? get qualification => doctorProfile?.qualification;
  String? get bio => doctorProfile?.bio;
  List<String>? get availableDays => doctorProfile?.availableDays;
  String? get slotStartTime => doctorProfile?.slotStartTime;
  String? get slotEndTime => doctorProfile?.slotEndTime;
  String? get slotDuration => doctorProfile?.slotDuration;
  List<String>? get weeklyOffDays => doctorProfile?.weeklyOffDays;
  List<String>? get specificLeaveDates => doctorProfile?.specificLeaveDates;
  String? get clinicName => doctorProfile?.clinicName;
  String? get clinicLocation => doctorProfile?.clinicLocation;
  String? get consultationFee => doctorProfile?.consultationFee;
  String? get areasOfExpertise => doctorProfile?.areasOfExpertise;

  UserModel({
    required this.id,
    required this.fullname,
    required this.email,
    required this.role,
    this.status = 'active',
    this.staffUniqueId,
    this.token,
    this.doctorProfile,
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
      fullname: json['fullname'] ?? json['fullName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      status: json['status'] ?? 'active',
      staffUniqueId: json['staff_unique_id'] ?? json['staffUniqueId'],
      token: json['token'],
      doctorProfile: (json['role'] == 'Doctor' || json['medical_license'] != null || json['specialization_id'] != null) 
          ? DoctorModel.fromJson(json) 
          : null,
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
    String? staffUniqueId,
    String? token,
    DoctorModel? doctorProfile,
    List<String>? permissions,
    Map<String, String>? permissionDisplayMap,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullname: fullname ?? this.fullname,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      staffUniqueId: staffUniqueId ?? this.staffUniqueId,
      token: token ?? this.token,
      doctorProfile: doctorProfile ?? this.doctorProfile,
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
