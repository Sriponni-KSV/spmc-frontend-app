class UserModel {
  final int id;
  final String fullname;
  final String email;
  final String role;
  final String? medicalLicense;
  final String? token; // To hold JWT if implemented

  UserModel({
    required this.id,
    required this.fullname,
    required this.email,
    required this.role,
    this.medicalLicense,
    this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      fullname: json['fullname'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      medicalLicense: json['medical_license'],
      token: json['token'],
    );
  }
}
