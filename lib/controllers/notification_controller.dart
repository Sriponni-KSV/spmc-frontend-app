import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';

class NotificationController {
  String get baseUrl => dotenv.env['BASE_URL']!;

  /// Fetch all notifications for the current logged-in user
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final url = '$baseUrl/notifications';
      final response = await ApiService.get(url);
      final body = ApiService.decodeJsonResponse(response);

      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch notifications');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
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
