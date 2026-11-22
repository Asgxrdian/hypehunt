import 'package:flutter_test/flutter_test.dart';
import 'package:hyperhunt/features/auth/domain/auth_validators.dart';

void main() {
  group('validateEmail', () {
    test('accepts a normal email', () {
      expect(validateEmail('cody@hyperhunt.gg'), isNull);
    });
    test('trims whitespace', () {
      expect(validateEmail('  cody@hyperhunt.gg  '), isNull);
    });
    test('rejects empty', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail(null), isNotNull);
    });
    test('rejects malformed shapes', () {
      for (final bad in ['plainaddress', 'a@b', 'a b@c.com', '@no-user.com']) {
        expect(validateEmail(bad), isNotNull, reason: bad);
      }
    });
  });

  group('validatePassword', () {
    test('accepts 8+ characters', () {
      expect(validatePassword('longenough'), isNull);
    });
    test('rejects short or empty', () {
      expect(validatePassword('short'), isNotNull);
      expect(validatePassword(''), isNotNull);
      expect(validatePassword(null), isNotNull);
    });
  });

  group('validateResetCode', () {
    test('accepts a 6-digit code', () {
      expect(validateResetCode('123456'), isNull);
    });
    test('rejects short or empty codes', () {
      expect(validateResetCode('123'), isNotNull);
      expect(validateResetCode(''), isNotNull);
    });
  });
}
