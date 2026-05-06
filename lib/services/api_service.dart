import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class ApiService {
  static void _checkAccess(http.Response response) {
    // We allow the status codes to be handled by the individual controllers
    // to support granular error messages from the backend (e.g. inactive, suspended)
  }

  static Future<http.Response> get(String url) async {
    String? token = await TokenService.getToken();

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    _checkAccess(response);
    return response;
  }

  static Future<http.Response> post(String url, Map body) async {
    String? token = await TokenService.getToken();

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    _checkAccess(response);
    return response;
  }

  static Future<http.Response> put(String url, Map body) async {
    String? token = await TokenService.getToken();

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    _checkAccess(response);
    return response;
  }

  static Future<http.Response> delete(String url) async {
    String? token = await TokenService.getToken();

    final response = await http.delete(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    _checkAccess(response);
    return response;
  }

  static Future<http.Response> patch(String url, Map body) async {
    String? token = await TokenService.getToken();

    final response = await http.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    _checkAccess(response);
    return response;
  }
}
