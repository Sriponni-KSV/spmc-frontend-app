class PatientModel {
  final int? id;
  final String name;
  final String dob;
  final int age;
  final String gender;
  final String phone;
  final String department;
  final String address;

  // Medical intake
  final int bpSystolic;
  final int bpDiastolic;
  final double sugar;
  final double temp;
  final String complaints;
  final String history;

  // Lifestyle
  final String smokingStatus;
  final String alcoholStatus;
  final String occupation;
  final String hobbies;
  final String foodHabits;
  final String physicalActivity;

  PatientModel({
    this.id,
    required this.name,
    required this.dob,
    required this.age,
    required this.gender,
    required this.phone,
    required this.department,
    required this.address,
    required this.bpSystolic,
    required this.bpDiastolic,
    required this.sugar,
    required this.temp,
    required this.complaints,
    required this.history,
    required this.smokingStatus,
    required this.alcoholStatus,
    required this.occupation,
    required this.hobbies,
    required this.foodHabits,
    required this.physicalActivity,
  });

  /// Convert model → JSON to send to backend
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dob': dob,
      'age': age,
      'gender': gender,
      'phone': phone,
      'department': department,
      'address': address,
      'bpSystolic': bpSystolic,
      'bpDiastolic': bpDiastolic,
      'sugar': sugar,
      'temp': temp,
      'complaints': complaints,
      'history': history,
      'smokingStatus': smokingStatus,
      'alcoholStatus': alcoholStatus,
      'occupation': occupation,
      'hobbies': hobbies,
      'foodHabits': foodHabits,
      'physicalActivity': physicalActivity,
    };
  }

  /// Convert JSON from backend → model (for future fetch patient list)
  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()),
      name: json['name'] ?? '',
      dob: json['dob'] ?? '',
      age: json['age'] is int ? json['age'] : int.tryParse(json['age'].toString()) ?? 0,
      gender: json['gender'] ?? '',
      phone: json['phone'] ?? '',
      department: json['department'] ?? '',
      address: json['address'] ?? '',
      bpSystolic: json['bpSystolic'] is int ? json['bpSystolic'] : int.tryParse(json['bpSystolic'].toString()) ?? 0,
      bpDiastolic: json['bpDiastolic'] is int ? json['bpDiastolic'] : int.tryParse(json['bpDiastolic'].toString()) ?? 0,
      sugar: json['sugar'] is double ? json['sugar'] : double.tryParse(json['sugar'].toString()) ?? 0.0,
      temp: json['temp'] is double ? json['temp'] : double.tryParse(json['temp'].toString()) ?? 0.0,
      complaints: json['complaints'] ?? '',
      history: json['history'] ?? '',
      smokingStatus: json['smokingStatus'] ?? 'No',
      alcoholStatus: json['alcoholStatus'] ?? 'No',
      occupation: json['occupation'] ?? '',
      hobbies: json['hobbies'] ?? '',
      foodHabits: json['foodHabits'] ?? '',
      physicalActivity: json['physicalActivity'] ?? '',
    );
  }
}