import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GmailEmailService {
  static final GmailEmailService _instance = GmailEmailService._internal();
  factory GmailEmailService() => _instance;
  GmailEmailService._internal();

  String _senderEmail = "mberuela11@gmail.com";
  String _appPassword = "yphw jfvc xouf zkxh";
  bool _initialized = false;

  final Map<String, Map<String, dynamic>> _activeOTPs = {};

  Future<void> _initCredentials() async {
    if (_initialized) return;
    try {
      final jsonStr = await rootBundle.loadString('config/local.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      if (data['GMAIL_SENDER_EMAIL'] != null && data['GMAIL_SENDER_EMAIL'].toString().isNotEmpty) {
        _senderEmail = data['GMAIL_SENDER_EMAIL'].toString().trim();
      }
      if (data['GMAIL_APP_PASSWORD'] != null && data['GMAIL_APP_PASSWORD'].toString().isNotEmpty) {
        _appPassword = data['GMAIL_APP_PASSWORD'].toString().trim();
      }
      _initialized = true;
    } catch (e) {
      debugPrint("Error loading config/local.json (using default credentials): $e");
    }
  }

  String _buildEmailHtml(String cleanRecipient, String recipientName, String otpCode) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { font-family: 'Segoe UI', Helvetica, Arial, sans-serif; background-color: #FFF5F7; margin: 0; padding: 20px; }
        .card { max-width: 500px; margin: 20px auto; background: #ffffff; border-radius: 24px; box-shadow: 0 12px 32px rgba(233, 30, 99, 0.12); overflow: hidden; border: 1px solid #FFE4E8; }
        .header { background: linear-gradient(135deg, #FF2E63 0%, #E91E63 60%, #FF5277 100%); padding: 34px 24px; text-align: center; color: #ffffff; }
        .header h1 { margin: 0; font-size: 26px; font-weight: 900; letter-spacing: 1.5px; text-transform: uppercase; font-family: 'Segoe UI', Arial, sans-serif; text-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header p { margin: 6px 0 0 0; font-size: 13px; color: #FFE0E6; opacity: 0.95; font-weight: 500; }
        .body { padding: 32px 28px; color: #222222; }
        .greeting { font-size: 18px; font-weight: 700; color: #222222; margin-bottom: 12px; }
        .intro { font-size: 14px; line-height: 1.6; color: #444444; margin-bottom: 20px; }
        .otp-box { background: linear-gradient(135deg, #FFF0F5 0%, #FFE4E8 100%); border: 2px dashed #E91E63; border-radius: 18px; padding: 24px; text-align: center; margin: 24px 0; }
        .otp-label { font-size: 11px; font-weight: 700; color: #E91E63; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 8px; }
        .otp-code { font-size: 38px; font-weight: 900; color: #E91E63; letter-spacing: 12px; font-family: 'Courier New', monospace; margin-left: 12px; }
        .notice { font-size: 12px; color: #666666; text-align: center; line-height: 1.5; margin-top: 20px; }
        .footer { background-color: #FFF0F5; padding: 20px; text-align: center; border-top: 1px solid #FFE4E8; font-size: 11px; color: #888888; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="header">
          <h1>BELLIE'S KITCHEN</h1>
          <p>Integrated Order & Business Management System</p>
        </div>
        <div class="body">
          <div class="greeting">Hello ${recipientName.isNotEmpty ? recipientName : 'Foodie'}! 👋</div>
          <div class="intro">Thank you for registering at Bellie's Kitchen! Please use the 6-digit verification code below to verify your email address and activate your account:</div>
          
          <div class="otp-box">
            <div class="otp-label">YOUR VERIFICATION CODE</div>
            <div class="otp-code">$otpCode</div>
          </div>
          
          <div class="notice">🔒 This code is valid for <strong>10 minutes</strong>. For security reasons, please do not share this code with anyone.</div>
        </div>
        <div class="footer">
          <p>© 2026 Bellie's Kitchen & SmartServe. All rights reserved.</p>
          <p>Santa Cruz, Pagsanjan, & Pila, Laguna</p>
        </div>
      </div>
    </body>
    </html>
    ''';
  }

  /// Dispatch email via Web-compatible HTTP REST API (supported across all web browsers & mobile)
  Future<bool> _sendWebEmailViaHttp({
    required String cleanRecipient,
    required String recipientName,
    required String otpCode,
  }) async {
    try {
      final String endpoint = (kIsWeb && !Uri.base.host.contains('localhost') && !Uri.base.host.contains('127.0.0.1'))
          ? Uri.base.resolve('/api/send-otp').toString()
          : 'https://bellies-smartserve.vercel.app/api/send-otp';
      final url = Uri.parse(endpoint);
      
      final response = await http.post(
        url,
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'to': cleanRecipient,
          'toName': recipientName.isNotEmpty ? recipientName : 'Foodie',
          'subject': "Your 6-Digit Verification Code: $otpCode",
          'html': _buildEmailHtml(cleanRecipient, recipientName, otpCode),
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint("✅ [WEB HTTP EMAIL] Real OTP Email sent to $cleanRecipient via Vercel Serverless Function");
        return true;
      } else {
        debugPrint("⚠️ [WEB HTTP EMAIL ERROR] Status ${response.statusCode}: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ [WEB HTTP EMAIL EXCEPTION]: $e");
      return false;
    }
  }

  /// Sends the HTML OTP email in the background asynchronously via Gmail SMTP
  Future<bool> _dispatchSmtpEmail({
    required String cleanRecipient,
    required String recipientName,
    required String otpCode,
    required String cleanAppPassword,
  }) async {
    final htmlContent = _buildEmailHtml(cleanRecipient, recipientName, otpCode);

    final message = Message()
      ..from = Address(_senderEmail, "Bellie's SmartServe")
      ..recipients.add(cleanRecipient)
      ..subject = "Your 6-Digit Verification Code: $otpCode"
      ..html = htmlContent;

    // Try sending via SSL Port 465 first
    try {
      final smtpServer465 = gmail(_senderEmail, cleanAppPassword);
      final sendReport = await send(message, smtpServer465);
      debugPrint('✅ [GMAIL SMTP] OTP email sent successfully via Port 465 to $cleanRecipient: ${sendReport.toString()}');
      return true;
    } catch (e) {
      debugPrint('⚠️ [GMAIL SMTP] Port 465 failed ($e). Retrying via Port 587 (STARTTLS)...');
      try {
        final smtpServer587 = SmtpServer(
          'smtp.gmail.com',
          port: 587,
          username: _senderEmail,
          password: cleanAppPassword,
        );
        final sendReport = await send(message, smtpServer587);
        debugPrint('✅ [GMAIL SMTP] OTP email sent successfully via Port 587 to $cleanRecipient: ${sendReport.toString()}');
        return true;
      } catch (e2) {
        debugPrint('❌ [GMAIL SMTP ERROR] Port 587 failed: $e2');
        return false;
      }
    }
  }

  /// Generates a random 6-digit OTP code, starts asynchronous HTML email delivery,
  /// and stores the OTP code locally with a 10-minute expiration.
  Future<String> sendSignUpOtpEmail({
    required String recipientEmail,
    required String recipientName,
  }) async {
    await _initCredentials();

    final cleanRecipient = recipientEmail.trim().toLowerCase();
    final cleanAppPassword = _appPassword.replaceAll(' ', '');

    // Generate random 6-digit OTP code
    final random = Random();
    final otpCode = (100000 + random.nextInt(900000)).toString();

    // Store in active OTP map immediately with 10-minute expiry
    _activeOTPs[cleanRecipient] = {
      'code': otpCode,
      'expiresAt': DateTime.now().add(const Duration(minutes: 10)),
    };

    debugPrint("--------------------------------------------------");
    debugPrint("🔑 [OTP GENERATED] Email: $cleanRecipient | Code: $otpCode");
    debugPrint("--------------------------------------------------");

    if (kIsWeb) {
      // Dispatch via HTTP REST API (100% web browser compatible)
      final httpSent = await _sendWebEmailViaHttp(
        cleanRecipient: cleanRecipient,
        recipientName: recipientName,
        otpCode: otpCode,
      );

      if (!httpSent) {
        try {
          await Supabase.instance.client.auth.signInWithOtp(
            email: cleanRecipient,
            shouldCreateUser: true,
          );
          debugPrint("✅ [SUPABASE WEB OTP] Backup email sent via Supabase HTTP REST API to $cleanRecipient");
        } catch (e) {
          debugPrint("⚠️ [SUPABASE WEB OTP ERROR]: $e");
        }
      }
      return otpCode;
    }

    // Await Gmail SMTP email sending on Mobile/Desktop
    try {
      final sent = await _dispatchSmtpEmail(
        cleanRecipient: cleanRecipient,
        recipientName: recipientName,
        otpCode: otpCode,
        cleanAppPassword: cleanAppPassword,
      );
      if (!sent) {
        // Fallback to HTTP REST API if SMTP fails on mobile
        await _sendWebEmailViaHttp(
          cleanRecipient: cleanRecipient,
          recipientName: recipientName,
          otpCode: otpCode,
        );
      }
    } catch (e) {
      debugPrint("⚠️ [GMAIL SMTP ERROR]: $e");
      await _sendWebEmailViaHttp(
        cleanRecipient: cleanRecipient,
        recipientName: recipientName,
        otpCode: otpCode,
      );
    }

    return otpCode;
  }

  /// Verifies if the entered OTP code matches and is not expired
  bool verifyOtpCode({required String email, required String code}) {
    final cleanRecipient = email.trim().toLowerCase();
    final cleanCode = code.trim();

    final record = _activeOTPs[cleanRecipient];
    if (record == null) {
      debugPrint("⚠️ [OTP VERIFY] No active OTP record found for $cleanRecipient");
      return false;
    }

    final String storedCode = record['code'] as String;
    final DateTime expiresAt = record['expiresAt'] as DateTime;

    if (DateTime.now().isAfter(expiresAt)) {
      debugPrint("⚠️ [OTP VERIFY] OTP for $cleanRecipient expired at $expiresAt");
      _activeOTPs.remove(cleanRecipient);
      return false;
    }

    final isValid = storedCode == cleanCode;
    debugPrint("🔍 [OTP VERIFY] Email: $cleanRecipient | Stored: $storedCode | Typed: $cleanCode | Match: $isValid");
    if (isValid) {
      _activeOTPs.remove(cleanRecipient);
    }
    return isValid;
  }
}
