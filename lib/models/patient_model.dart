import '../utils/date_formatter.dart';

class PatientModel {
  final int? id;
  final String? patientId;
  final String name;
  final String dob;
  final int age;
  final String gender;
  final String phone;
  final String email;
  final String address;
  final String addressLine2;
  final String district;
  final String pincode;
  final String? createdAt;

  String get fullAddress {
    final parts = [address, addressLine2, district, pincode]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  // Emergency Contact
  final String emergencyContactName;
  final String emergencyContactRelation;
  final String emergencyContactPhone;

  // Medical intake
  final double height;
  final double weight;
  final int bpSystolic;
  final int bpDiastolic;
  final double sugar;
  final double temp;
  final String bloodGroup;
  final String allergies;
  final String chronicConditions;
  final String complaints;
  final String history;

  // Lifestyle
  final String smokingStatus;
  final String alcoholStatus;
  final String occupation;
  final String hobbies;
  final String foodHabits;
  final String physicalActivity;
  final bool isQuickRegister;

  PatientModel({
    this.id,
    required this.name,
    required this.dob,
    required this.age,
    required this.gender,
    required this.phone,
    required this.email,
    required this.address,
    required this.addressLine2,
    required this.district,
    required this.pincode,
    required this.emergencyContactName,
    required this.emergencyContactRelation,
    required this.emergencyContactPhone,
    required this.height,
    required this.weight,
    required this.bpSystolic,
    required this.bpDiastolic,
    required this.sugar,
    required this.temp,
    required this.bloodGroup,
    required this.allergies,
    required this.chronicConditions,
    required this.complaints,
    required this.history,
    required this.smokingStatus,
    required this.alcoholStatus,
    required this.occupation,
    required this.hobbies,
    required this.foodHabits,
    required this.physicalActivity,
    this.isQuickRegister = false,
    this.patientId,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'name': name,
      'dob': DateFormatter.toDb(dob),
      'age': age,
      'gender': gender,
      'phone': phone,
      'email': email,
      'address': address,
      'addressLine2': addressLine2,
      'district': district,
      'pincode': pincode,
      'emergencyContactName': emergencyContactName,
      'emergencyContactRelation': emergencyContactRelation,
      'emergencyContactPhone': emergencyContactPhone,
      'height': height,
      'weight': weight,
      'bpSystolic': bpSystolic,
      'bpDiastolic': bpDiastolic,
      'sugar': sugar,
      'temp': temp,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'chronicConditions': chronicConditions,
      'complaints': complaints,
      'history': history,
      'smokingStatus': smokingStatus,
      'alcoholStatus': alcoholStatus,
      'occupation': occupation,
      'hobbies': hobbies,
      'foodHabits': foodHabits,
      'physicalActivity': physicalActivity,
      'isQuickRegister': isQuickRegister,
      'created_at': createdAt,
    };
  }

  /// Convert JSON from backend → model (for future fetch patient list)
  factory PatientModel.fromJson(Map<String, dynamic> json) {
    final bpSys = json['bpSystolic'] ?? json['bp_systolic'];
    final bpDia = json['bpDiastolic'] ?? json['bp_diastolic'];
    final sugarV = json['sugar'];
    final tempV = json['temp'];
    final heightV = json['height'];
    final weightV = json['weight'];

    return PatientModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()),
      name: (json['name'] ?? '').toString(),
      dob: DateFormatter.toUi(json['dob']),
      age: json['age'] is int ? json['age'] : int.tryParse(json['age'].toString()) ?? 0,
      gender: (json['gender'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      addressLine2: (json['address_line_2'] ?? json['addressLine2'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
      pincode: (json['pincode'] ?? '').toString(),
      emergencyContactName: (json['emergency_contact_name'] ?? json['emergencyContactName'] ?? '').toString(),
      emergencyContactRelation: (json['emergency_contact_relation'] ?? json['emergencyContactRelation'] ?? '').toString(),
      emergencyContactPhone: (json['emergency_contact_phone'] ?? json['emergencyContactPhone'] ?? '').toString(),
      height: heightV == null ? 0.0 : (heightV is double ? heightV : double.tryParse(heightV.toString()) ?? 0.0),
      weight: weightV == null ? 0.0 : (weightV is double ? weightV : double.tryParse(weightV.toString()) ?? 0.0),
      bpSystolic: bpSys == null ? 0 : (bpSys is int ? bpSys : int.tryParse(bpSys.toString()) ?? 0),
      bpDiastolic: bpDia == null ? 0 : (bpDia is int ? bpDia : int.tryParse(bpDia.toString()) ?? 0),
      sugar: sugarV == null ? 0.0 : (sugarV is double ? sugarV : double.tryParse(sugarV.toString()) ?? 0.0),
      temp: tempV == null ? 0.0 : (tempV is double ? tempV : double.tryParse(tempV.toString()) ?? 0.0),
      bloodGroup: (json['blood_group'] ?? json['bloodGroup'] ?? '').toString(),
      allergies: (json['allergies'] ?? '').toString(),
      chronicConditions: (json['chronic_conditions'] ?? json['chronicConditions'] ?? '').toString(),
      complaints: (json['complaints'] ?? '').toString(),
      history: (json['history'] ?? '').toString(),
      smokingStatus: (json['smokingStatus'] ?? json['smoking_status'] ?? 'No').toString(),
      alcoholStatus: (json['alcoholStatus'] ?? json['alcohol_status'] ?? 'No').toString(),
      occupation: (json['occupation'] ?? '').toString(),
      hobbies: (json['hobbies'] ?? '').toString(),
      foodHabits: (json['foodHabits'] ?? json['food_habits'] ?? '').toString(),
      physicalActivity: (json['physicalActivity'] ?? json['physical_activity'] ?? '').toString(),
      isQuickRegister: (json['isQuickRegister'] ?? json['is_quick_register']) == true ||
          (json['isQuickRegister'] ?? json['is_quick_register']).toString() == '1' ||
          (json['isQuickRegister'] ?? json['is_quick_register']).toString().toLowerCase() == 'true',
      patientId: json['patientId']?.toString() ?? json['patient_id']?.toString(),
      createdAt: (json['createdAt'] ?? json['created_at']) != null ? DateFormatter.toUi(json['createdAt'] ?? json['created_at']) : null,
    );
  }
}