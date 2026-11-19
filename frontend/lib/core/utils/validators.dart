abstract final class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _letter = RegExp(r'[A-Za-z]');
  static final _digit = RegExp(r'[0-9]');

  static String? email(String? value) =>
      _email.hasMatch(value?.trim() ?? '') ? null : 'Enter a valid email.';

  static String? password(String? value) {
    final password = value ?? '';
    if (password.length < 8 ||
        password.length > 72 ||
        !_letter.hasMatch(password) ||
        !_digit.hasMatch(password)) {
      return 'Use 8–72 characters with a letter and a number.';
    }
    return null;
  }

  static String? length(String? value, String label, int min, int max) {
    final count = value?.trim().runes.length ?? 0;
    return count >= min && count <= max
        ? null
        : '$label must be $min–$max characters.';
  }
}
