import 'package:flutter/services.dart';

class InputValidators {
  // Strict Regular Expressions
  static final RegExp _nameRegExp = RegExp(r"^[a-zA-Z\s\-\'\.]+$");
  static final RegExp _phoneRegExp = RegExp(r"^(09|\+639)\d{9}$");
  static final RegExp _emailRegExp =
      RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
  static final RegExp _scriptTagRegExp = RegExp(
    r"<[^>]*>|javascript:|select\s+.*from|insert\s+into|delete\s+from",
    caseSensitive: false,
  );

  /// Sanitize & Trim Input
  static String sanitize(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Name Validation (First Name, Middle Name, Last Name)
  static String? validateName(
    String? value, {
    required String fieldName,
    bool isRequired = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return "$fieldName is required.";
      return null;
    }

    final trimmed = sanitize(value);

    if (trimmed.length < 2) {
      return "$fieldName must be at least 2 characters.";
    }

    if (trimmed.length > 50) {
      return "$fieldName cannot exceed 50 characters.";
    }

    if (!_nameRegExp.hasMatch(trimmed)) {
      return "$fieldName can only contain letters, spaces, hyphens, and apostrophes.";
    }

    if (RegExp(r"[\-\'\.]{2,}").hasMatch(trimmed)) {
      return "$fieldName contains invalid consecutive punctuation.";
    }

    return null;
  }

  /// Phone / Contact Number Validation (Philippine mobile standard)
  static String? validatePhoneNumber(
    String? value, {
    bool isRequired = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return "Contact number is required.";
      return null;
    }

    final cleanPhone = value.replaceAll(RegExp(r'[\s\-]'), '');

    if (!_phoneRegExp.hasMatch(cleanPhone)) {
      return "Enter a valid PH mobile number (e.g. 09171234567 or +639171234567).";
    }

    return null;
  }

  /// Email Address Validation
  static String? validateEmail(
    String? value, {
    bool isRequired = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return "Email address is required.";
      return null;
    }

    final trimmed = value.trim();

    if (trimmed.length > 80) {
      return "Email address cannot exceed 80 characters.";
    }

    if (!_emailRegExp.hasMatch(trimmed)) {
      return "Enter a valid email address (e.g. user@gmail.com).";
    }

    return null;
  }

  /// Address Validation
  static String? validateAddress(
    String? value, {
    bool isRequired = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return "Address is required.";
      return null;
    }

    final trimmed = sanitize(value);

    if (trimmed.length < 5) {
      return "Address must be at least 5 characters long.";
    }

    if (trimmed.length > 200) {
      return "Address cannot exceed 200 characters.";
    }

    if (_scriptTagRegExp.hasMatch(trimmed)) {
      return "Invalid characters or HTML/script tags detected in address.";
    }

    return null;
  }

  /// Input Formatters for TextFields
  static final List<TextInputFormatter> nameFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\'\.]")),
    DenyLeadingSpaceFormatter(),
    LengthLimitingTextInputFormatter(50),
  ];

  static final List<TextInputFormatter> phoneFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r"[0-9\+]")),
    DenyLeadingSpaceFormatter(),
    LengthLimitingTextInputFormatter(13),
  ];

  static final List<TextInputFormatter> emailFormatters = [
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
    LengthLimitingTextInputFormatter(80),
  ];

  static final List<TextInputFormatter> addressFormatters = [
    DenyLeadingSpaceFormatter(),
    LengthLimitingTextInputFormatter(200),
  ];
}

class DenyLeadingSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.startsWith(' ')) {
      return oldValue;
    }
    return newValue;
  }
}
