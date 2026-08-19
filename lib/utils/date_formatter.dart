import 'package:intl/intl.dart';

class DateFormatter {
  static const String uiFormat = 'dd/MM/yyyy';
  static const String dbFormat = 'yyyy-MM-dd';

  /// Formats a Date object or string to DD-MM-YYYY for display
  static String toUi(dynamic date) {
    if (date == null) return '';
    
    DateTime? dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is String && date.isNotEmpty) {
      String cleanDate = date.contains('T') ? date.split('T')[0] : date;
      
      // Try DB format first
      try {
        dt = DateFormat(dbFormat).parse(cleanDate);
      } catch (_) {
        // Try UI format
        try {
          dt = DateFormat('dd/MM/yyyy').parse(cleanDate);
        } catch (_) {
          try {
             dt = DateFormat('dd-MM-yyyy').parse(cleanDate);
          } catch (_) {}
        }
      }
    }
    
    if (dt == null) return date.toString();
    return DateFormat(uiFormat).format(dt);
  }

  /// Parses any format into a DateTime object
  static DateTime? toDateTime(dynamic date) {
    if (date == null) return null;
    if (date is DateTime) return date;
    
    String dateStr = date.toString();
    if (dateStr.isEmpty) return null;
    
    // Clean string (e.g. remove T00:00:00.000Z)
    String cleanDate = dateStr.contains('T') ? dateStr.split('T')[0] : dateStr;

    // 1. Try ISO/DB format (yyyy-MM-dd)
    try {
      return DateTime.parse(cleanDate);
    } catch (_) {}

    // 2. Try slashing format (dd/MM/yyyy)
    try {
      return DateFormat('dd/MM/yyyy').parse(cleanDate);
    } catch (_) {}

    // 3. Try dashed format (dd-MM-yyyy)
    try {
      return DateFormat('dd-MM-yyyy').parse(cleanDate);
    } catch (_) {}

    return null;
  }

  /// Formats a DD-MM-YYYY string back to YYYY-MM-DD for database
  static String toDb(String? uiDate) {
    if (uiDate == null || uiDate.isEmpty) return '';
    try {
      DateTime dt = DateFormat('dd/MM/yyyy').parse(uiDate);
      return DateFormat(dbFormat).format(dt);
    } catch (_) {
      try {
        DateTime dt = DateFormat('dd-MM-yyyy').parse(uiDate);
        return DateFormat(dbFormat).format(dt);
      } catch (_) {
        return uiDate; 
      }
    }
  }

  /// Formats patient age. Returns age in months for infants under 1 year (e.g. "6 months" or "6m"),
  /// or age in years (e.g. "25 years" or "25y").
  static String formatAge(dynamic age, {dynamic dob, bool shortUnit = false}) {
    DateTime? dt = toDateTime(dob);

    if (dt != null) {
      final now = DateTime.now();
      int years = now.year - dt.year;
      int months = now.month - dt.month;
      int days = now.day - dt.day;

      if (days < 0) {
        months--;
      }
      if (months < 0) {
        years--;
        months += 12;
      }

      if (years >= 1) {
        return shortUnit ? '${years}y' : '$years years';
      } else {
        // Infant under 1 year old -> Display in terms of months!
        if (months <= 0) {
          int diffDays = now.difference(dt).inDays;
          if (diffDays < 0) diffDays = 0;
          if (diffDays == 0) {
            return shortUnit ? '0m' : '0 months';
          }
          if (diffDays < 30) {
            return shortUnit ? '${diffDays}d' : '$diffDays days';
          }
          return shortUnit ? '1m' : '1 month';
        }
        return shortUnit
            ? '${months}m'
            : '$months month${months == 1 ? '' : 's'}';
      }
    }

    // Fallback if dob is missing/invalid
    int ageNum = 0;
    if (age is int) {
      ageNum = age;
    } else if (age != null) {
      ageNum = int.tryParse(age.toString()) ?? 0;
    }

    if (ageNum > 0) {
      return shortUnit ? '${ageNum}y' : '$ageNum years';
    }

    return 'Not Provided';
  }
}
