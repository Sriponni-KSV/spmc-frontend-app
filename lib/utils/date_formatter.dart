import 'package:intl/intl.dart';

class DateFormatter {
  static const String uiFormat = 'dd-mm-yyyy';
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
          dt = DateFormat('dd-MM-yyyy').parse(cleanDate);
        } catch (_) {}
      }
    }
    
    if (dt == null) return date.toString();
    return DateFormat('dd-MM-yyyy').format(dt);
  }

  /// Formats a DD-MM-YYYY string back to YYYY-MM-DD for database
  static String toDb(String? uiDate) {
    if (uiDate == null || uiDate.isEmpty) return '';
    try {
      DateTime dt = DateFormat('dd-MM-yyyy').parse(uiDate);
      return DateFormat(dbFormat).format(dt);
    } catch (_) {
      return uiDate; // Return as is if already in DB format or invalid
    }
  }
}
