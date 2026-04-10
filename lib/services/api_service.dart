import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class ApiService {
  static Future<http.Response> get(String url) async {
    String? token = await TokenService.getToken();

    return http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  static Future<http.Response> post(String url, Map body) async {
    String? token = await TokenService.getToken();

    return http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> put(String url, Map body) async {
    String? token = await TokenService.getToken();

    return http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> delete(String url) async {
    String? token = await TokenService.getToken();

    return http.delete(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  static Future<http.Response> patch(String url, Map body) async {
    String? token = await TokenService.getToken();

    return http.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }
}
