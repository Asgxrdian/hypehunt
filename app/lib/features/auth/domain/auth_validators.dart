/// Pure form validators — no Flutter imports, fully unit-testable.
final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

const kMinPasswordLength = 8;

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter your email';
  if (!_emailPattern.hasMatch(v)) return 'That email doesn\'t look right';
  return null;
}

String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Enter a password';
  if (v.length < kMinPasswordLength) {
    return 'Passwords need at least $kMinPasswordLength characters';
  }
  return null;
}

String? validateResetCode(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter the code from your email';
  if (v.length < 6) return 'The code is 6 digits';
  return null;
}
