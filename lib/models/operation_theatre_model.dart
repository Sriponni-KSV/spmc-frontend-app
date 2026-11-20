class OperationTheatreModel {
  final int id;
  final String theatreCode;
  final String theatreName;
  final String theatreType;
  final String? location;
  final String status;
  final bool isActive;
  final int activeTodayCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OperationTheatreModel({
    required this.id,
    required this.theatreCode,
    required this.theatreName,
    this.theatreType = 'Major',
    this.location,
    this.status = 'Active',
    this.isActive = true,
    this.activeTodayCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  bool get isOperational => isActive && status.toLowerCase() == 'active';
  bool get isMaintenance => status.toLowerCase() == 'maintenance';
  bool get isInactive => !isActive || status.toLowerCase() == 'inactive';

  factory OperationTheatreModel.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] ?? (json['is_active'] == false ? 'Inactive' : 'Active')).toString();
    final bool rawActive = json['is_active'] == true || (json['is_active'] == null && rawStatus.toLowerCase() == 'active');

    return OperationTheatreModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      theatreCode: (json['theatre_code'] ?? json['code'] ?? '').toString().trim(),
      theatreName: (json['theatre_name'] ?? json['name'] ?? '').toString().trim(),
      theatreType: (json['theatre_type'] ?? json['type'] ?? 'Major').toString().trim(),
      location: json['location']?.toString().trim(),
      status: rawStatus,
      isActive: rawActive,
      activeTodayCount: int.tryParse(json['active_today_count']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'theatre_code': theatreCode,
      'theatre_name': theatreName,
      'theatre_type': theatreType,
      'location': location,
      'status': status,
      'is_active': isActive,
    };
  }

  OperationTheatreModel copyWith({
    int? id,
    String? theatreCode,
    String? theatreName,
    String? theatreType,
    String? location,
    String? status,
    bool? isActive,
    int? activeTodayCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OperationTheatreModel(
      id: id ?? this.id,
      theatreCode: theatreCode ?? this.theatreCode,
      theatreName: theatreName ?? this.theatreName,
      theatreType: theatreType ?? this.theatreType,
      location: location ?? this.location,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      activeTodayCount: activeTodayCount ?? this.activeTodayCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

