import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Represents a securely saved account credential entry.
/// Supports multiple passwords for the same email address.
/// Plaintext passwords are kept strictly in memory when loaded and never logged.
class SavedAccount {
  final String id;
  final String email;
  final String password;
  final DateTime savedAt;

  const SavedAccount({
    required this.id,
    required this.email,
    required this.password,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'password': password,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
        id: json['id'] as String? ??
            '${(json['email'] as String? ?? '').trim()}_${DateTime.now().microsecondsSinceEpoch}',
        email: (json['email'] as String? ?? '').trim(),
        password: json['password'] as String? ?? '',
        savedAt: json['savedAt'] != null
            ? (DateTime.tryParse(json['savedAt'].toString()) ?? DateTime.now())
            : DateTime.now(),
      );

  /// Returns a clean masked string for UI display (e.g. '••••••••'). Never plaintext.
  String get maskedPassword => '••••••••';
}

/// Secure storage service managing multi-account and multi-password credentials using [FlutterSecureStorage].
/// Credentials are encrypted with Android Keystore / iOS Keychain.
/// Never writes passwords to SharedPreferences, .env, or plain text files.
class CredentialStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _storageKey = 'saved_user_accounts';

  /// Retrieves all saved accounts securely.
  /// Returns an empty list safely if storage is empty or an error occurs.
  static Future<List<SavedAccount>> getSavedAccounts() async {
    try {
      final rawJson = await _storage.read(key: _storageKey);
      if (rawJson == null || rawJson.trim().isEmpty) {
        return [];
      }

      final dynamic decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => SavedAccount.fromJson(e))
            .where((acc) => acc.email.isNotEmpty && acc.password.isNotEmpty)
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('CredentialStorageService: Error reading saved accounts: $e');
      return [];
    }
  }

  /// Retrieves a distinct list of saved email addresses.
  static Future<List<String>> getSavedEmails() async {
    final accounts = await getSavedAccounts();
    final seen = <String>{};
    final distinctEmails = <String>[];
    for (final acc in accounts) {
      final lower = acc.email.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        distinctEmails.add(acc.email);
      }
    }
    return distinctEmails;
  }

  /// Retrieves all saved credentials associated with a specific email address.
  static Future<List<SavedAccount>> getAccountsForEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return [];

    final accounts = await getSavedAccounts();
    return accounts
        .where((a) => a.email.toLowerCase() == cleanEmail)
        .toList();
  }

  /// Checks if an exact email and password combination is already saved.
  static Future<bool> isAccountSaved(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;

    final accounts = await getSavedAccounts();
    return accounts.any(
      (a) => a.email.toLowerCase() == cleanEmail && a.password == password,
    );
  }

  /// Saves or updates credentials for an account.
  /// If the exact (email, password) already exists, updates its timestamp (avoids duplicates).
  /// If the same email has a DIFFERENT password, adds it as a separate entry without overwriting!
  static Future<bool> saveAccount(String email, String password) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) return false;

    try {
      final accounts = await getSavedAccounts();
      final updated = <SavedAccount>[];

      bool foundExact = false;
      for (final a in accounts) {
        if (a.email.toLowerCase() == cleanEmail.toLowerCase() &&
            a.password == password) {
          // Update timestamp of the exact existing entry and move to top
          foundExact = true;
        } else {
          updated.add(a);
        }
      }

      // Insert new or refreshed entry at top
      final newId =
          '${cleanEmail}_${DateTime.now().millisecondsSinceEpoch}_${password.hashCode}';
      updated.insert(
        0,
        SavedAccount(
          id: newId,
          email: cleanEmail,
          password: password,
          savedAt: DateTime.now(),
        ),
      );

      final jsonString = jsonEncode(updated.map((a) => a.toJson()).toList());
      await _storage.write(key: _storageKey, value: jsonString);
      return true;
    } catch (e) {
      debugPrint('CredentialStorageService: Error saving account: $e');
      return false;
    }
  }

  /// Removes an individual credential entry by its unique entry ID.
  static Future<bool> removeAccountById(String id) async {
    try {
      final accounts = await getSavedAccounts();
      final filtered = accounts.where((a) => a.id != id).toList();

      if (filtered.isEmpty) {
        await _storage.delete(key: _storageKey);
      } else {
        final jsonString = jsonEncode(filtered.map((a) => a.toJson()).toList());
        await _storage.write(key: _storageKey, value: jsonString);
      }
      return true;
    } catch (e) {
      debugPrint('CredentialStorageService: Error removing account by id: $e');
      return false;
    }
  }

  /// Removes all saved credential entries for an email.
  static Future<bool> removeAccountByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;

    try {
      final accounts = await getSavedAccounts();
      final filtered = accounts
          .where((a) => a.email.toLowerCase() != cleanEmail)
          .toList();

      if (filtered.isEmpty) {
        await _storage.delete(key: _storageKey);
      } else {
        final jsonString = jsonEncode(filtered.map((a) => a.toJson()).toList());
        await _storage.write(key: _storageKey, value: jsonString);
      }
      return true;
    } catch (e) {
      debugPrint('CredentialStorageService: Error removing account by email: $e');
      return false;
    }
  }

  /// Clears all saved credentials from secure storage.
  static Future<bool> clearAllAccounts() async {
    try {
      await _storage.delete(key: _storageKey);
      return true;
    } catch (e) {
      debugPrint('CredentialStorageService: Error clearing accounts: $e');
      return false;
    }
  }
}
