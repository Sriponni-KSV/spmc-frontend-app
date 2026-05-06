import '../utils/date_formatter.dart';

class AppointmentModel {
  final int? id;
  final int patientId;
  final String? patientDisplayId;
  final String patientName;
  final String department;
  final String doctorName;
  final String appointmentDate;
  final String appointmentTime;
  final String? patientPhone;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final double? sugarLevel;
  final double? temperature;
  final String? reasonForVisit;
  final String status;
  final String appointmentType;
  final String? overrideReason;
  final String? overrideByName;
  final String? doctorDisplayId;
  final dynamic changesLog;

  AppointmentModel({
    this.id,
    required this.patientId,
    this.patientDisplayId,
    required this.patientName,
    required this.department,
    required this.doctorName,
    required this.appointmentDate,
    required this.appointmentTime,
    this.patientPhone,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.sugarLevel,
    this.temperature,
    this.reasonForVisit,
    this.status = 'Confirmed',
    this.appointmentType = 'Routine',
    this.overrideReason,
    this.overrideByName,
    this.doctorDisplayId,
    this.changesLog,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      patientId: json['patient_id'] is int ? json['patient_id'] : int.tryParse(json['patient_id']?.toString() ?? '') ?? 0,
      patientDisplayId: json['patient_display_id']?.toString(),
      patientName: json['patient_name'] ?? '',
      department: json['department'] ?? '',
      doctorName: json['doctor_name'] ?? '',
      appointmentDate: DateFormatter.toUi(json['appointment_date']),
      appointmentTime: json['appointment_time'] ?? '',
      patientPhone: json['patient_phone']?.toString(),
      bloodPressureSystolic: json['blood_pressure_systolic'] is int ? json['blood_pressure_systolic'] : int.tryParse(json['blood_pressure_systolic']?.toString() ?? ''),
      bloodPressureDiastolic: json['blood_pressure_diastolic'] is int ? json['blood_pressure_diastolic'] : int.tryParse(json['blood_pressure_diastolic']?.toString() ?? ''),
      sugarLevel: json['sugar_level'] != null ? double.tryParse(json['sugar_level'].toString()) : null,
      temperature: json['temperature'] != null ? double.tryParse(json['temperature'].toString()) : null,
      reasonForVisit: json['reason_for_visit'],
      status: json['status'] ?? 'Confirmed',
      appointmentType: json['appointment_type'] ?? 'Routine',
      overrideReason: json['override_reason'],
      overrideByName: json['override_by_name'],
      doctorDisplayId: json['doctor_display_id']?.toString(),
      changesLog: json['changes_log'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient_id': patientId,
      'patient_name': patientName,
      'department': department,
      'doctor_name': doctorName,
      'appointment_date': DateFormatter.toDb(appointmentDate),
      'appointment_time': appointmentTime,
      'patient_phone': patientPhone,
      'blood_pressure_systolic': bloodPressureSystolic,
      'blood_pressure_diastolic': bloodPressureDiastolic,
      'sugar_level': sugarLevel,
      'temperature': temperature,
      'reason_for_visit': reasonForVisit,
      'status': status,
      'appointment_type': appointmentType,
    };
  }

  AppointmentModel copyWith({
    int? id,
    int? patientId,
    String? patientName,
    String? department,
    String? doctorName,
    String? appointmentDate,
    String? appointmentTime,
    String? patientPhone,
    int? bloodPressureSystolic,
    int? bloodPressureDiastolic,
    double? sugarLevel,
    double? temperature,
    String? reasonForVisit,
    String? status,
    String? appointmentType,
    String? doctorDisplayId,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      department: department ?? this.department,
      doctorName: doctorName ?? this.doctorName,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      patientPhone: patientPhone ?? this.patientPhone,
      bloodPressureSystolic: bloodPressureSystolic ?? this.bloodPressureSystolic,
      bloodPressureDiastolic:
          bloodPressureDiastolic ?? this.bloodPressureDiastolic,
      sugarLevel: sugarLevel ?? this.sugarLevel,
      temperature: temperature ?? this.temperature,
      reasonForVisit: reasonForVisit ?? this.reasonForVisit,
      status: status ?? this.status,
      appointmentType: appointmentType ?? this.appointmentType,
      doctorDisplayId: doctorDisplayId ?? this.doctorDisplayId,
    );
  }
}
