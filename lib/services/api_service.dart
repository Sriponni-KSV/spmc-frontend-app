import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import '../exceptions/network_exception.dart';
import 'token_service.dart';

class ApiService {
  static dynamic decodeJsonResponse(
    http.Response response, {
    String? fallbackMessage,
  }) {
    final contentType = response.headers['content-type'] ?? '';
    final trimmedBody = response.body.trimLeft();
    final looksJson =
        trimmedBody.startsWith('{') || trimmedBody.startsWith('[');

    if (!contentType.contains('application/json') && !looksJson) {
      final preview = trimmedBody.length > 80
          ? trimmedBody.substring(0, 80)
          : trimmedBody;
      throw Exception(
        '${fallbackMessage ?? 'Unexpected server response'} '
        '(status ${response.statusCode}, content-type: ${contentType.isEmpty ? 'unknown' : contentType}). '
        'Expected JSON but received: $preview',
      );
    }

    try {
      return jsonDecode(response.body);
    } on FormatException catch (e) {
      throw Exception(
        '${fallbackMessage ?? 'Invalid JSON response'}: ${e.message}',
      );
    }
  }

  static void _checkAccess(http.Response response) {
    // We allow the status codes to be handled by the individual controllers
    // to support granular error messages from the backend (e.g. inactive, suspended).
    // 5xx errors are caught here and surfaced as ServerErrorException.
    if (response.statusCode >= 500) {
      throw ServerErrorException(response.statusCode);
    }
  }

  /// Converts low-level network / timeout errors into the appropriate
  /// [NetworkException] subclass so the UI can show the right message.
  static Never _handleNetworkError(dynamic e) {
    print('[API Network Error] $e');
    // Timeout (dart:async TimeoutException from .timeout())
    if (e is TimeoutException) {
      throw RequestTimeoutException();
    }

    final msg = e.toString().toLowerCase();

    // True no-internet signals
    if (e is SocketException ||
        msg.contains('failed to fetch') ||      // Flutter Web / CORS / offline
        msg.contains('network is unreachable') ||
        msg.contains('failed host lookup') ||   // DNS failure
        msg.contains('no address associated')) {
      throw NoInternetException();
    }

    // Backend refused / not running (localhost server stopped, remote server down)
    if (msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('connection closed') ||
        msg.contains('clientexception')) {
      throw ServerUnavailableException();
    }

    // Any other low-level exception — surface as server unavailable
    // so the user at least gets a meaningful message.
    throw ServerUnavailableException();
  }

  static Map<String, String> _headers(String? token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  static Future<http.Response> get(String url) async {
    try {
      final token = await TokenService.getToken();
      final response = await http
          .get(Uri.parse(url), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      _checkAccess(response);
      return response;
    } on NetworkException {
      rethrow;
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  static Future<http.Response> post(String url, Map body) async {
    try {
      final token = await TokenService.getToken();
      final response = await http
          .post(Uri.parse(url),
              headers: _headers(token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      _checkAccess(response);
      return response;
    } on NetworkException {
      rethrow;
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  static Future<http.Response> put(String url, Map body) async {
    try {
      final token = await TokenService.getToken();
      final response = await http
          .put(Uri.parse(url),
              headers: _headers(token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      _checkAccess(response);
      return response;
    } on NetworkException {
      rethrow;
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  static Future<http.Response> delete(String url) async {
    try {
      final token = await TokenService.getToken();
      final response = await http
          .delete(Uri.parse(url), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      _checkAccess(response);
      return response;
    } on NetworkException {
      rethrow;
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  static Future<http.Response> patch(String url, Map body) async {
    try {
      final token = await TokenService.getToken();
      final response = await http
          .patch(Uri.parse(url),
              headers: _headers(token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      _checkAccess(response);
      return response;
    } on NetworkException {
      rethrow;
    } catch (e) {
      _handleNetworkError(e);
    }
  }
}
