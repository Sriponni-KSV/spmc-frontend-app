class NurseShiftModel {
  final int id;
  final String code;
  final String name;
  final String startTime;
  final String endTime;
  final int breakMinutes;
  final String? description;
  final String status;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const NurseShiftModel({
    required this.id,
    required this.code,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.breakMinutes = 30,
    this.description,
    this.status = 'Active',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  bool get isOperational => isActive && status.toLowerCase() == 'active';

  static int parseMinutes(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      final hour = int.parse(parts[0]);
      final min = parts.length > 1 ? int.parse(parts[1]) : 0;
      return hour * 60 + min;
    } catch (_) {
      return 0;
    }
  }

  bool get isOvernight {
    final start = parseMinutes(startTime);
    final end = parseMinutes(endTime);
    return end <= start;
  }

  double get shiftDurationHours {
    final start = parseMinutes(startTime);
    var end = parseMinutes(endTime);
    if (end <= start) {
      end += 24 * 60; // Overnight wrap-around
    }
    return (end - start) / 60.0;
  }

  double get netWorkingHours {
    final net = shiftDurationHours - (breakMinutes / 60.0);
    return net > 0 ? net : shiftDurationHours;
  }

  static String formatTimeOfDayString(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      var hour = int.parse(parts[0]);
      final min = parts.length > 1 ? int.parse(parts[1]) : 0;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour -= 12;
      }
      final minStr = min.toString().padLeft(2, '0');
      final hourStr = hour.toString().padLeft(2, '0');
      return '$hourStr:$minStr $ampm';
    } catch (_) {
      return timeStr;
    }
  }

  String get formattedStartTime => formatTimeOfDayString(startTime);
  String get formattedEndTime => formatTimeOfDayString(endTime);
  String get formattedTiming => '$formattedStartTime – $formattedEndTime';

  String get formattedDuration {
    final dur = shiftDurationHours;
    final durStr = dur % 1 == 0 ? dur.toInt().toString() : dur.toStringAsFixed(1);
    return '$durStr hrs (${breakMinutes}m break)';
  }

  String get shiftType {
    if (isOvernight) return 'Night / Overnight';
    final start = parseMinutes(startTime);
    if (start < 12 * 60) return 'Morning / Day';
    return 'Evening / Afternoon';
  }

  factory NurseShiftModel.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] ?? json['shift_name'] ?? '').toString().trim();
    final rawCode = (json['code'] ?? json['shift_code'] ?? '').toString().trim();
    final cleanCode = rawCode.isNotEmpty
        ? rawCode.toUpperCase()
        : (rawName.length >= 3 ? rawName.substring(0, 3).toUpperCase() : 'SHF');

    final rawStatus = (json['status'] ?? (json['is_active'] == false ? 'Inactive' : 'Active')).toString();
    final bool rawActive = json['is_active'] == true || (json['is_active'] == null && rawStatus.toLowerCase() == 'active');

    return NurseShiftModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      code: cleanCode,
      name: rawName,
      startTime: (json['start_time'] ?? '06:00:00').toString(),
      endTime: (json['end_time'] ?? '14:00:00').toString(),
      breakMinutes: int.tryParse(json['break_minutes']?.toString() ?? '30') ?? 30,
      description: json['description']?.toString(),
      status: rawStatus,
      isActive: rawActive,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'start_time': startTime,
      'end_time': endTime,
      'break_minutes': breakMinutes,
      'description': description,
      'status': status,
      'is_active': isActive,
    };
  }

  NurseShiftModel copyWith({
    int? id,
    String? code,
    String? name,
    String? startTime,
    String? endTime,
    int? breakMinutes,
    String? description,
    String? status,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NurseShiftModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      description: description ?? this.description,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

