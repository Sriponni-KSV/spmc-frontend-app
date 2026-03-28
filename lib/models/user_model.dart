class UserModel {
  final int id;
  final String fullname;
  final String email;
  final String role;
  final String status;
  final String? medicalLicense;
  final String? token;

  UserModel({
    required this.id,
    required this.fullname,
    required this.email,
    required this.role,
    this.status = 'active',
    this.medicalLicense,
    this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      fullname: json['fullname'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      status: json['status'] ?? 'active',
      medicalLicense: json['medical_license'],
      token: json['token'],
    );
  }
}
