import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptOcrService {
  /// Extracts a 10 to 13-digit GCash/InstaPay reference number from a receipt image.
  /// Returns the extracted reference number if a valid pattern is found in the image text,
  /// or null if no valid reference number is detected.
  static Future<String?> extractGcashReferenceNumber(String imagePath, {String? fileName}) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      try {
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        final String fullText = recognizedText.text;

        if (fullText.trim().isNotEmpty) {
          final foundRef = parseReferenceFromText(fullText);
          if (foundRef != null) {
            return foundRef;
          }
        }
      } catch (mlKitError) {
        debugPrint('ML Kit OCR failed or unsupported platform: $mlKitError');
      } finally {
        textRecognizer.close();
      }
    } catch (e) {
      debugPrint('Error preparing OCR image: $e');
    }

    // Secondary check: if filename explicitly contains a 10 to 13-digit reference string
    if (fileName != null && fileName.isNotEmpty) {
      final fileMatch = RegExp(r'\b\d{10,13}\b').firstMatch(fileName);
      if (fileMatch != null) {
        final candidate = fileMatch.group(0)!;
        if (isValidGcashRefNumber(candidate)) {
          return candidate;
        }
      }
    }

    // STRICT POLICY: Return null if no genuine reference number is found.
    // NEVER generate random fake numbers or hashes.
    return null;
  }

  /// Parses recognized OCR text for GCash/InstaPay reference number patterns
  static String? parseReferenceFromText(String text) {
    // 1. Search line by line for explicit labels
    // e.g. "Ref No. 1000 035 576 07", "Ref: 100003557607", "Reference Number: 100003557607"
    final labeledRegex = RegExp(
      r'(?:Ref(?:erence)?\s*(?:No|Num|Number|ID)?[\s.:#]*)([0-9\s-]{10,20})',
      caseSensitive: false,
    );

    for (final line in text.split('\n')) {
      final match = labeledRegex.firstMatch(line);
      if (match != null) {
        final digitsOnly = match.group(1)!.replaceAll(RegExp(r'\D'), '');
        if (isValidGcashRefNumber(digitsOnly)) {
          return digitsOnly;
        }
      }
    }

    // 2. Search for any standalone 13-digit sequence in the text
    final exact13DigitRegex = RegExp(r'\b\d{13}\b');
    for (final m in exact13DigitRegex.allMatches(text)) {
      final candidate = m.group(0)!;
      if (isValidGcashRefNumber(candidate)) {
        return candidate;
      }
    }

    // 3. Search for 13 digits separated by spaces or dashes (e.g. "1000 035 576 07")
    final spacedDigitsRegex = RegExp(r'\b(?:\d[\s-]*){13}\b');
    for (final m in spacedDigitsRegex.allMatches(text)) {
      final candidate = m.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (isValidGcashRefNumber(candidate)) {
        return candidate;
      }
    }

    // 4. Fallback search for any 10 to 12 digit number block
    final flexDigitsRegex = RegExp(r'\b\d{10,12}\b');
    for (final m in flexDigitsRegex.allMatches(text)) {
      final candidate = m.group(0)!;
      if (isValidGcashRefNumber(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  /// Validates if a string matches the format of a valid GCash / InstaPay Reference Number
  static bool isValidGcashRefNumber(String? ref) {
    if (ref == null) return false;
    final cleaned = ref.trim().replaceAll(RegExp(r'\D'), '');

    // GCash & InstaPay reference numbers are typically 10 to 13 digits long
    if (cleaned.length < 10 || cleaned.length > 13) {
      return false;
    }

    // Reject repetitive fake digit strings like 0000000000000 or 1111111111111
    if (RegExp(r'^(.)\1+$').hasMatch(cleaned)) {
      return false;
    }

    return true;
  }
}
