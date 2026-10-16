import '../utils/date_formatter.dart';

class AppointmentModel {
  final int? id;
  final int? doctorId;
  final int patientId;
  final String? patientDisplayId;
  final String patientName;
  final String department;
  final String doctorName;
  final String appointmentDate;
  final String appointmentTime;
  final String? patientPhone;
  final String? patientGender;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final double? sugarLevel;
  final double? temperature;
  final int? pulse;
  final int? spo2;
  final double? height;
  final double? weight;
  final String? reasonForVisit;
  final int? painScore;
  final String? triageCategory;
  final String? triageNotes;
  final String status;
  final String appointmentType;
  final int? tokenNumber;
  final String? overrideReason;
  final String? overrideByName;
  final String? doctorDisplayId;
  final dynamic changesLog;
  final String? cancellationReason;
  final bool isRescheduled;
  final String? createdAt;
  final String? updatedAt;
  final String? overrideAt;

  AppointmentModel({
    this.id,
    this.doctorId,
    required this.patientId,
    this.patientDisplayId,
    required this.patientName,
    required this.department,
    required this.doctorName,
    required this.appointmentDate,
    required this.appointmentTime,
    this.patientPhone,
    this.patientGender,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.sugarLevel,
    this.temperature,
    this.pulse,
    this.spo2,
    this.height,
    this.weight,
    this.reasonForVisit,
    this.painScore,
    this.triageCategory,
    this.triageNotes,
    this.status = 'Confirmed',
    this.appointmentType = 'Routine',
    this.tokenNumber,
    this.overrideReason,
    this.overrideByName,
    this.doctorDisplayId,
    this.changesLog,
    this.cancellationReason,
    this.isRescheduled = false,
    this.createdAt,
    this.updatedAt,
    this.overrideAt,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      doctorId: json['doctor_id'] is int ? json['doctor_id'] : int.tryParse(json['doctor_id']?.toString() ?? ''),
      patientId: json['patient_id'] is int ? json['patient_id'] : int.tryParse(json['patient_id']?.toString() ?? '') ?? 0,
      patientDisplayId: json['patient_display_id']?.toString(),
      patientName: json['patient_name'] ?? '',
      department: json['department'] ?? '',
      doctorName: json['doctor_name'] ?? '',
      appointmentDate: DateFormatter.toUi(json['appointment_date']),
      appointmentTime: json['appointment_time'] ?? '',
      patientPhone: json['patient_phone']?.toString(),
      patientGender: json['patient_gender']?.toString(),
      bloodPressureSystolic: json['blood_pressure_systolic'] is int ? json['blood_pressure_systolic'] : int.tryParse(json['blood_pressure_systolic']?.toString() ?? ''),
      bloodPressureDiastolic: json['blood_pressure_diastolic'] is int ? json['blood_pressure_diastolic'] : int.tryParse(json['blood_pressure_diastolic']?.toString() ?? ''),
      sugarLevel: json['sugar_level'] != null ? double.tryParse(json['sugar_level'].toString()) : null,
      temperature: json['temperature'] != null ? double.tryParse(json['temperature'].toString()) : null,
      pulse: json['pulse'] is int ? json['pulse'] : int.tryParse(json['pulse']?.toString() ?? ''),
      spo2: json['spo2'] is int ? json['spo2'] : int.tryParse(json['spo2']?.toString() ?? ''),
      height: json['height'] != null ? double.tryParse(json['height'].toString()) : null,
      weight: json['weight'] != null ? double.tryParse(json['weight'].toString()) : null,
      reasonForVisit: json['reason_for_visit'],
      painScore: json['pain_score'] is int ? json['pain_score'] : int.tryParse(json['pain_score']?.toString() ?? ''),
      triageCategory: json['triage_category'] ?? json['triage_priority'],
      triageNotes: json['triage_notes'],
      status: json['status'] ?? 'Confirmed',
      appointmentType: json['appointment_type'] ?? 'Routine',
      tokenNumber: json['token_number'] is int ? json['token_number'] : int.tryParse(json['token_number']?.toString() ?? ''),
      overrideReason: json['override_reason'],
      overrideByName: json['override_by_name'],
      doctorDisplayId: json['doctor_display_id']?.toString(),
      changesLog: json['changes_log'],
      cancellationReason: json['cancellation_reason'],
      isRescheduled: json['is_rescheduled'] == true || json['is_rescheduled'] == 'true',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      overrideAt: json['override_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (doctorId != null) 'doctor_id': doctorId,
      'patient_id': patientId,
      'patient_name': patientName,
      'department': department,
      'doctor_name': doctorName,
      'appointment_date': DateFormatter.toDb(appointmentDate),
      'appointment_time': appointmentTime,
      'patient_phone': patientPhone,
      'patient_gender': patientGender,
      'blood_pressure_systolic': bloodPressureSystolic,
      'blood_pressure_diastolic': bloodPressureDiastolic,
      'sugar_level': sugarLevel,
      'temperature': temperature,
      if (pulse != null) 'pulse': pulse,
      if (spo2 != null) 'spo2': spo2,
      if (height != null) 'height': height,
      if (weight != null) 'weight': weight,
      'reason_for_visit': reasonForVisit,
      if (painScore != null) 'pain_score': painScore,
      if (triageCategory != null) 'triage_category': triageCategory,
      if (triageNotes != null) 'triage_notes': triageNotes,
      'status': status,
      'appointment_type': appointmentType,
      if (tokenNumber != null) 'token_number': tokenNumber,
      'cancellation_reason': cancellationReason,
      'is_rescheduled': isRescheduled,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'override_at': overrideAt,
    };
  }

  AppointmentModel copyWith({
    int? id,
    int? doctorId,
    int? patientId,
    String? patientName,
    String? department,
    String? doctorName,
    String? appointmentDate,
    String? appointmentTime,
    String? patientPhone,
    String? patientGender,
    int? bloodPressureSystolic,
    int? bloodPressureDiastolic,
    double? sugarLevel,
    double? temperature,
    int? pulse,
    int? spo2,
    double? height,
    double? weight,
    String? reasonForVisit,
    int? painScore,
    String? triageCategory,
    String? triageNotes,
    String? status,
    String? appointmentType,
    int? tokenNumber,
    String? doctorDisplayId,
    String? cancellationReason,
    bool? isRescheduled,
    String? createdAt,
    String? updatedAt,
    String? overrideAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      department: department ?? this.department,
      doctorName: doctorName ?? this.doctorName,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      patientPhone: patientPhone ?? this.patientPhone,
      patientGender: patientGender ?? this.patientGender,
      bloodPressureSystolic: bloodPressureSystolic ?? this.bloodPressureSystolic,
      bloodPressureDiastolic:
          bloodPressureDiastolic ?? this.bloodPressureDiastolic,
      sugarLevel: sugarLevel ?? this.sugarLevel,
      temperature: temperature ?? this.temperature,
      pulse: pulse ?? this.pulse,
      spo2: spo2 ?? this.spo2,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      reasonForVisit: reasonForVisit ?? this.reasonForVisit,
      painScore: painScore ?? this.painScore,
      triageCategory: triageCategory ?? this.triageCategory,
      triageNotes: triageNotes ?? this.triageNotes,
      status: status ?? this.status,
      appointmentType: appointmentType ?? this.appointmentType,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      doctorDisplayId: doctorDisplayId ?? this.doctorDisplayId,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      isRescheduled: isRescheduled ?? this.isRescheduled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      overrideAt: overrideAt ?? this.overrideAt,
    );
  }
}
