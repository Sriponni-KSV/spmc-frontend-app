class DepartmentModel {
  final int id;
  final String name;
  final String code;
  final String? description;
  final String status;
  final int doctorCount;
  final int staffCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DepartmentModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.status = 'Active',
    this.doctorCount = 0,
    this.staffCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: (json['name'] ?? json['department_name'] ?? '').toString().trim(),
      code: (json['code'] ?? json['department_code'] ?? '').toString().trim(),
      description: json['description']?.toString(),
      status: (json['status'] ?? 'Active').toString(),
      doctorCount: int.tryParse(json['doctor_count']?.toString() ?? '0') ?? 0,
      staffCount: int.tryParse(json['staff_count']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'status': status,
    };
  }

  DepartmentModel copyWith({
    int? id,
    String? name,
    String? code,
    String? description,
    String? status,
    int? doctorCount,
    int? staffCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DepartmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      status: status ?? this.status,
      doctorCount: doctorCount ?? this.doctorCount,
      staffCount: staffCount ?? this.staffCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepartmentModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$name ($code)';
}

