import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenService {
  static const _storage = FlutterSecureStorage();

  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'token', value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: 'token');
  }

  static Future<void> saveUser(String userJson) async {
    await _storage.write(key: 'user', value: userJson);
  }

  static Future<String?> getUser() async {
    return await _storage.read(key: 'user');
  }

  static Future<void> deleteUser() async {
    await _storage.delete(key: 'user');
  }
}