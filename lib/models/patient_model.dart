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
  final double height;
  final double weight;
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
    required this.height,
    required this.weight,
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
      'height': height,
      'weight': weight,
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
    final bpSys  = json['bpSystolic']  ?? json['bp_systolic'];
    final bpDia  = json['bpDiastolic'] ?? json['bp_diastolic'];
    final sugarV = json['sugar'];
    final tempV  = json['temp'];
    final heightV = json['height'];
    final weightV = json['weight'];

    return PatientModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()),
      name:       (json['name']       ?? '').toString(),
      dob:        (json['dob']        ?? '').toString(),
      age:        json['age'] is int  ? json['age'] : int.tryParse(json['age'].toString()) ?? 0,
      gender:     (json['gender']     ?? '').toString(),
      phone:      (json['phone']      ?? '').toString(),
      department: (json['department'] ?? '').toString(),
      address:    (json['address']    ?? '').toString(),
      height:     heightV == null ? 0.0 : (heightV is double ? heightV : double.tryParse(heightV.toString()) ?? 0.0),
      weight:     weightV == null ? 0.0 : (weightV is double ? weightV : double.tryParse(weightV.toString()) ?? 0.0),
      bpSystolic:  bpSys  == null ? 0 : (bpSys  is int ? bpSys  : int.tryParse(bpSys.toString())  ?? 0),
      bpDiastolic: bpDia  == null ? 0 : (bpDia  is int ? bpDia  : int.tryParse(bpDia.toString())  ?? 0),
      sugar:       sugarV == null ? 0.0 : (sugarV is double ? sugarV : double.tryParse(sugarV.toString()) ?? 0.0),
      temp:        tempV  == null ? 0.0 : (tempV  is double ? tempV  : double.tryParse(tempV.toString())  ?? 0.0),
      complaints:      (json['complaints']                                    ?? '').toString(),
      history:         (json['history']                                       ?? '').toString(),
      smokingStatus:   (json['smokingStatus']  ?? json['smoking_status']      ?? 'No').toString(),
      alcoholStatus:   (json['alcoholStatus']  ?? json['alcohol_status']      ?? 'No').toString(),
      occupation:      (json['occupation']                                    ?? '').toString(),
      hobbies:         (json['hobbies']                                       ?? '').toString(),
      foodHabits:      (json['foodHabits']     ?? json['food_habits']         ?? '').toString(),
      physicalActivity:(json['physicalActivity']?? json['physical_activity']  ?? '').toString(),
    );
  }
}