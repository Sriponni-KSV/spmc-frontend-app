import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';

class NotificationController {
  String get baseUrl => dotenv.env['BASE_URL']!;

  /// Fetch all notifications for the current logged-in user.
  /// Returns an empty list on any error so failures are silent.
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final url = '$baseUrl/notifications';
      final response = await ApiService.get(url);

      if (response.statusCode != 200) return [];

      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] != true) return [];

      final List data = body['data'] ?? [];
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      // Silently return empty — notification errors should never break the UI
      return [];
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(int id) async {
    try {
      final url = '$baseUrl/notifications/$id/read';
      final response = await ApiService.put(url, {});
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to update notification');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
