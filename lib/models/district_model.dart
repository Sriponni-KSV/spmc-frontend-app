class DistrictModel {
  final int id;
  final String name;
  final String state;
  final String? code;
  final String status;
  final int pincodeCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DistrictModel({
    required this.id,
    required this.name,
    required this.state,
    this.code,
    this.status = 'Active',
    this.pincodeCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  bool get isOperational => status.toLowerCase() == 'active';

  factory DistrictModel.fromJson(Map<String, dynamic> json) {
    return DistrictModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      state: json['state']?.toString() ?? 'Tamil Nadu',
      code: json['code']?.toString(),
      status: json['status']?.toString() ?? 'Active',
      pincodeCount: json['pincode_count'] is int
          ? json['pincode_count']
          : int.tryParse(json['pincode_count']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'state': state,
    'code': code,
    'status': status,
    'pincode_count': pincodeCount,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  DistrictModel copyWith({
    int? id,
    String? name,
    String? state,
    String? code,
    String? status,
    int? pincodeCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DistrictModel(
      id: id ?? this.id,
      name: name ?? this.name,
      state: state ?? this.state,
      code: code ?? this.code,
      status: status ?? this.status,
      pincodeCount: pincodeCount ?? this.pincodeCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PincodeModel {
  final int id;
  final int districtId;
  final String? districtName;
  final String? districtState;
  final String pincode;
  final String? postOfficeName;
  final String displayLabel;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PincodeModel({
    required this.id,
    required this.districtId,
    this.districtName,
    this.districtState,
    required this.pincode,
    this.postOfficeName,
    required this.displayLabel,
    this.status = 'Active',
    this.createdAt,
    this.updatedAt,
  });

  bool get isOperational => status.toLowerCase() == 'active';

  factory PincodeModel.fromJson(Map<String, dynamic> json) {
    final pin = json['pincode']?.toString() ?? '';
    final po = json['post_office_name']?.toString();
    final label = json['display_label']?.toString() ??
        (po != null && po.isNotEmpty ? '$pin ($po)' : pin);

    return PincodeModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      districtId: json['district_id'] is int
          ? json['district_id']
          : int.tryParse(json['district_id']?.toString() ?? '0') ?? 0,
      districtName: json['district_name']?.toString(),
      districtState: json['district_state']?.toString() ?? 'Tamil Nadu',
      pincode: pin,
      postOfficeName: po,
      displayLabel: label,
      status: json['status']?.toString() ?? 'Active',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'district_id': districtId,
    'district_name': districtName,
    'district_state': districtState,
    'pincode': pincode,
    'post_office_name': postOfficeName,
    'display_label': displayLabel,
    'status': status,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  PincodeModel copyWith({
    int? id,
    int? districtId,
    String? districtName,
    String? districtState,
    String? pincode,
    String? postOfficeName,
    String? displayLabel,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PincodeModel(
      id: id ?? this.id,
      districtId: districtId ?? this.districtId,
      districtName: districtName ?? this.districtName,
      districtState: districtState ?? this.districtState,
      pincode: pincode ?? this.pincode,
      postOfficeName: postOfficeName ?? this.postOfficeName,
      displayLabel: displayLabel ?? this.displayLabel,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
