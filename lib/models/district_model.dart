class DistrictModel {
  final int id;
  final String name;
  final String state;
  final String? code;
  final int pincodeCount;

  DistrictModel({
    required this.id,
    required this.name,
    required this.state,
    this.code,
    this.pincodeCount = 0,
  });

  factory DistrictModel.fromJson(Map<String, dynamic> json) {
    return DistrictModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      state: json['state']?.toString() ?? 'Tamil Nadu',
      code: json['code']?.toString(),
      pincodeCount: json['pincode_count'] is int
          ? json['pincode_count']
          : int.tryParse(json['pincode_count']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'state': state,
    'code': code,
    'pincode_count': pincodeCount,
  };
}

class PincodeModel {
  final int id;
  final int districtId;
  final String pincode;
  final String? postOfficeName;
  final String displayLabel;

  PincodeModel({
    required this.id,
    required this.districtId,
    required this.pincode,
    this.postOfficeName,
    required this.displayLabel,
  });

  factory PincodeModel.fromJson(Map<String, dynamic> json) {
    final pin = json['pincode']?.toString() ?? '';
    final po = json['post_office_name']?.toString();
    final label = json['display_label']?.toString() ?? (po != null && po.isNotEmpty ? '$pin ($po)' : pin);

    return PincodeModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      districtId: json['district_id'] is int
          ? json['district_id']
          : int.tryParse(json['district_id']?.toString() ?? '0') ?? 0,
      pincode: pin,
      postOfficeName: po,
      displayLabel: label,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'district_id': districtId,
    'pincode': pincode,
    'post_office_name': postOfficeName,
    'display_label': displayLabel,
  };
}

