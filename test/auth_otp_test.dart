import 'package:flutter_test/flutter_test.dart';

bool isValidEmail(String email) {
  if (email.isEmpty || email.trim().length > 60) return false;
  final emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );
  return emailRegex.hasMatch(email.trim());
}

void main() {
  group('Email Field & Domain Validation Tests', () {
    test('Accepts valid email domains including gmail.com and edu.ph', () {
      expect(isValidEmail('user@gmail.com'), isTrue);
      expect(isValidEmail('student@lu.edu.ph'), isTrue);
      expect(isValidEmail('test.user+1@domain.co.uk'), isTrue);
    });

    test('Rejects blank, malformed, or emails over 60 characters', () {
      expect(isValidEmail(''), isFalse);
      expect(isValidEmail('plainaddress'), isFalse);
      expect(isValidEmail('@missinguser.com'), isFalse);
      expect(isValidEmail('user@.com'), isFalse);
      expect(
        isValidEmail('extremely_long_email_address_that_exceeds_sixty_characters_limit@domain.com'),
        isFalse,
      );
    });
  });

  group('OTP Verification Simulation Tests', () {
    test('Validates 6-digit OTP code format', () {
      final validOtp = '123456';
      final invalidOtpShort = '1234';
      final invalidOtpAlpha = '12345a';

      expect(validOtp.length == 6 && RegExp(r'^\d+$').hasMatch(validOtp), isTrue);
      expect(invalidOtpShort.length == 6, isFalse);
      expect(RegExp(r'^\d+$').hasMatch(invalidOtpAlpha), isFalse);
    });
  });
}
