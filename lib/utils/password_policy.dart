import 'dart:math';

class PasswordPolicy {
  /// Validates a password against the standard policy.
  /// Returns a string with the error message if invalid, or null if valid.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter Password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (value.length > 16) {
      return 'Password must be at most 16 characters long';
    }
    if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
      return 'Must contain at least one lowercase letter';
    }
    if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
      return 'Must contain at least one uppercase letter';
    }
    if (!RegExp(r'(?=.*\d)').hasMatch(value)) {
      return 'Must contain at least one number';
    }
    if (!RegExp(r'(?=.*[\W_])').hasMatch(value)) {
      return 'Must contain at least one special character';
    }
    return null;
  }

  /// Generates a secure random temporary password that meets the policy rules.
  static String generateSecurePassword() {
    const length = 12; // Choosing a reasonable length between 8 and 16
    const lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const specials = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

    final random = Random.secure();
    
    // Ensure at least one of each required type
    String password = '';
    password += lowercase[random.nextInt(lowercase.length)];
    password += uppercase[random.nextInt(uppercase.length)];
    password += numbers[random.nextInt(numbers.length)];
    password += specials[random.nextInt(specials.length)];

    // Fill the rest randomly from all characters
    const allChars = lowercase + uppercase + numbers + specials;
    for (int i = 4; i < length; i++) {
      password += allChars[random.nextInt(allChars.length)];
    }

    // Shuffle the characters
    List<String> chars = password.split('');
    chars.shuffle(random);
    return chars.join('');
  }
}
