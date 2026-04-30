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
}
