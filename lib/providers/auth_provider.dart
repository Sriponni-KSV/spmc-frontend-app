import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../models/user_model.dart';
import '../services/token_service.dart';

class AuthProvider extends ChangeNotifier {

  final AuthController _authController = AuthController();

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> refreshPermissions() async {
    if (_user == null) return;
    try {
      final permissions = await _authController.fetchLivePermissions();
      _user = _user!.copyWith(permissions: permissions);
      notifyListeners();
    } catch (e) {
      print('Failed to refresh permissions: $e');
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authController.login(
        email: email,
        password: password,
      );

      if (user != null) {
        _user = user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await TokenService.deleteToken();
    _user = null;
    notifyListeners();
  }
}