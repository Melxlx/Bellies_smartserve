import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'gmail_email_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;
  bool get isAuthenticated => currentUser != null && !currentUser!.isAnonymous;

  Map<String, String?> _splitFullName(String fullName) {
    final parts = fullName.trim().replaceAll(RegExp(r'\s+'), ' ').split(' ');
    if (parts.isEmpty) return {'first_name': null, 'middle_name': null, 'last_name': null};
    if (parts.length == 1) {
      return {'first_name': parts[0], 'middle_name': null, 'last_name': null};
    } else if (parts.length == 2) {
      return {'first_name': parts[0], 'middle_name': null, 'last_name': parts[1]};
    } else {
      return {
        'first_name': parts[0],
        'middle_name': parts.sublist(1, parts.length - 1).join(' '),
        'last_name': parts.last,
      };
    }
  }

  /// Ensures that a user profile exists in `profiles` table.
  /// If it does not exist (e.g. first time Google or Facebook OAuth or Email sign-up),
  /// it creates a default Customer profile (`role: 'GUEST'`).
  Future<UserModel> ensureProfileExists({User? user, bool isCustomerPortal = false}) async {
    final targetUser = user ?? currentUser;
    if (targetUser == null) {
      throw const AuthException('No authenticated user found.');
    }

    final cleanEmail = targetUser.email?.trim().toLowerCase() ?? '';
    final isOwnerEmail = cleanEmail == 'mberuela11@gmail.com' ||
        cleanEmail == 'jubileealfonnn@gmail.com' ||
        cleanEmail == 'owner@bellies.com';

    try {
      final response = await _supabase
          .from('profiles')
            .select('*, employee_details(*)')
          .eq('id', targetUser.id)
          .maybeSingle();

      if (response != null) {
        if (isOwnerEmail && (response['role'] != 'OWNER' || response['position'] != 'Owner / Manager')) {
          try {
            await _supabase.from('profiles').update({
              'role': 'OWNER',
              'position': 'Owner / Manager',
            }).eq('id', targetUser.id);
            response['role'] = 'OWNER';
            response['position'] = 'Owner / Manager';
          } catch (_) {}
        }
        return UserModel.fromJson(response);
      }
    } catch (_) {
      // Fallback if employee_details join fails
      try {
        final response = await _supabase
            .from('profiles')
            .select()
            .eq('id', targetUser.id)
            .maybeSingle();
        if (response != null) {
          if (isOwnerEmail && (response['role'] != 'OWNER' || response['position'] != 'Owner / Manager')) {
            try {
              await _supabase.from('profiles').update({
                'role': 'OWNER',
                'position': 'Owner / Manager',
              }).eq('id', targetUser.id);
              response['role'] = 'OWNER';
              response['position'] = 'Owner / Manager';
            } catch (_) {}
          }
          return UserModel.fromJson(response);
        }
      } catch (_) {}
    }

    // New profile creation from OAuth or Email metadata
    final metadata = targetUser.userMetadata ?? {};
    final email = targetUser.email ?? '';
    final metaFirstName = metadata['first_name']?.toString();
    final metaMiddleName = metadata['middle_name']?.toString();
    final metaLastName = metadata['last_name']?.toString();
    final metaContact = metadata['contact_number']?.toString();
    final metaAddress = metadata['address']?.toString();

    final rawFullName = metadata['full_name']?.toString() ?? metadata['name']?.toString();
    final derivedFullName = [metaFirstName, metaMiddleName, metaLastName].where((s) => s != null && s.trim().isNotEmpty).join(' ');
    final String finalFullName = (rawFullName != null && rawFullName.trim().isNotEmpty)
        ? rawFullName.trim()
        : (derivedFullName.isNotEmpty ? derivedFullName : (email.isNotEmpty ? email.split('@').first : 'Customer'));

    final avatarUrl = metadata['avatar_url']?.toString() ?? metadata['picture']?.toString();

    final nameParts = _splitFullName(finalFullName);
    final String emailPrefix = email.split('@').first;
    final String? firstNameToUse = (metaFirstName != null && metaFirstName.trim().isNotEmpty && metaFirstName.trim() != emailPrefix)
        ? metaFirstName.trim()
        : (nameParts['first_name'] != null && nameParts['first_name'] != emailPrefix ? nameParts['first_name'] : null);
    final String? lastNameToUse = (metaLastName != null && metaLastName.trim().isNotEmpty && metaLastName.trim() != emailPrefix)
        ? metaLastName.trim()
        : (nameParts['last_name'] != null && nameParts['last_name'] != emailPrefix ? nameParts['last_name'] : null);

    final newProfilePayload = {
      'id': targetUser.id,
      'email': email,
      'full_name': finalFullName,
      'first_name': firstNameToUse,
      'middle_name': metaMiddleName ?? nameParts['middle_name'],
      'last_name': lastNameToUse,
      if (metaContact != null && metaContact.isNotEmpty) 'contact_number': metaContact,
      if (metaAddress != null && metaAddress.isNotEmpty) 'address': metaAddress,
      'avatar_url': avatarUrl,
      'position': isOwnerEmail ? 'Owner / Manager' : 'Customer',
      'role': isOwnerEmail ? 'OWNER' : 'CUSTOMER',
      'account_status': 'ACTIVE',
    };

    final created = await _supabase
        .from('profiles')
        .upsert(newProfilePayload)
        .select()
        .single();

    return UserModel.fromJson(created);
  }

  /// Initiates OAuth Sign-In with Google or Facebook
  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    String? redirectTo;
    if (kIsWeb) {
      // Importante sa Vercel/Web: I-redirect sa mismong origin + callback route
      redirectTo = '${Uri.base.origin}/'; 
    } else {
      redirectTo = 'bellies://login-callback';
    }

    return await _supabase.auth.signInWithOAuth(
      provider,
      redirectTo: redirectTo,
      // Gamitin ang inAppWebView (popup sa loob) imbes na externalApplication para hindi maputol ang session storage ng browser sa Vercel
      authScreenLaunchMode: kIsWeb ? LaunchMode.inAppWebView : LaunchMode.platformDefault, 
    );
  }

  /// Sign In with Email & Password
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw const AuthException('Authentication failed.');
    }

    return await ensureProfileExists(user: response.user);
  }

  /// Checks if an email is already registered in the profiles table
  Future<bool> isEmailRegistered(String email) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  static final Map<String, Map<String, dynamic>> _pendingSignUpData = {};

  /// Step 1: Initiates Sign Up by generating & sending a 6-digit OTP code via Gmail SMTP.
  /// NOTE: Does NOT create an account in Supabase yet.
  /// Account creation ONLY happens in Step 2 after the user verifies the OTP.
  Future<String> initiateEmailSignUpOTP({
    required String email,
    required String password,
    required String fullName,
    String? firstName,
    String? middleName,
    String? lastName,
    String? username,
    String? contactNumber,
    String? address,
  }) async {
    final acceptedAt = DateTime.now().toIso8601String();
    final cleanEmail = email.trim().toLowerCase();

    // 1. Generate local OTP and send via Gmail SMTP / Serverless Service
    String otpCode = "123456";
    try {
      otpCode = await GmailEmailService().sendSignUpOtpEmail(
        recipientEmail: cleanEmail,
        recipientName: fullName.trim(),
      );
    } catch (e) {
      debugPrint("Gmail OTP error: $e");
      rethrow;
    }

    // Store pending registration info & generated OTP code locally
    _pendingSignUpData[cleanEmail] = {
      'password': password,
      'fullName': fullName.trim(),
      'firstName': firstName?.trim(),
      'middleName': middleName?.trim(),
      'lastName': lastName?.trim(),
      'username': username?.trim(),
      'contactNumber': contactNumber?.trim(),
      'address': address?.trim(),
      'acceptedAt': acceptedAt,
      'otpCode': otpCode.trim(),
    };

    return otpCode;
  }

  /// Step 2: Verifies the 6-digit OTP code and ONLY THEN creates the account in Supabase.
  Future<UserModel> verifyEmailSignUpOTP({
    required String email,
    required String code,
    required String fullName,
    String? firstName,
    String? middleName,
    String? lastName,
    String? username,
    String? contactNumber,
    String? address,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim();

    final pendingData = _pendingSignUpData[cleanEmail];
    final password = pendingData?['password'] ?? 'Password123!';
    final storedOtpCode = pendingData?['otpCode']?.toString().trim();
    final cleanFullName = (pendingData?['fullName'] ?? fullName).toString().trim();
    final nameParts = _splitFullName(cleanFullName);
    final cleanFirstName = (pendingData?['firstName'] ?? firstName ?? nameParts['first_name'])?.toString().trim();
    final cleanMiddleName = (pendingData?['middleName'] ?? middleName ?? nameParts['middle_name'])?.toString().trim();
    final cleanLastName = (pendingData?['lastName'] ?? lastName ?? nameParts['last_name'])?.toString().trim();
    final cleanUsername = (pendingData?['username'] ?? username)?.toString().trim();
    final cleanContactNumber = (pendingData?['contactNumber'] ?? contactNumber)?.toString().trim();
    final cleanAddress = (pendingData?['address'] ?? address)?.toString().trim();
    final acceptedAt = pendingData?['acceptedAt']?.toString() ?? DateTime.now().toIso8601String();

    // 1. Verify OTP code against stored OTP code in pendingData, Gmail OTP manager, or Supabase OTP
    bool isOtpValid = (storedOtpCode != null && storedOtpCode.isNotEmpty && storedOtpCode == cleanCode) ||
        GmailEmailService().verifyOtpCode(
          email: cleanEmail,
          code: cleanCode,
        );

    // Also attempt Supabase OTP verification if local verification didn't match
    if (!isOtpValid) {
      final otpTypes = [
        OtpType.email,
        OtpType.signup,
        OtpType.magiclink,
        OtpType.recovery,
      ];
      for (final type in otpTypes) {
        try {
          final response = await _supabase.auth.verifyOTP(
            email: cleanEmail,
            token: cleanCode,
            type: type,
          );
          if (response.user != null || response.session != null) {
            isOtpValid = true;
            break;
          }
        } catch (_) {}
      }
    }

    if (!isOtpValid) {
      throw const AuthException('Incorrect code. Please try again');
    }

    // --- OTP IS CONFIRMED! NOW REGISTER / LINK USER IN SUPABASE ---
    _pendingSignUpData.remove(cleanEmail);

    User? user = _supabase.auth.currentUser;

    if (user != null && user.email?.trim().toLowerCase() == cleanEmail) {
      // User has an active Supabase session (e.g. from verifyOTP)
      try {
        final updateRes = await _supabase.auth.updateUser(
          UserAttributes(
            password: password,
            data: {
              'first_name': cleanFirstName,
              if (cleanMiddleName != null && cleanMiddleName.isNotEmpty) 'middle_name': cleanMiddleName,
              'last_name': cleanLastName,
              'name': cleanFullName,
              'full_name': cleanFullName,
              'username': cleanUsername,
              'contact_number': cleanContactNumber,
              if (cleanAddress != null && cleanAddress.isNotEmpty) 'address': cleanAddress,
              'terms_version': '1.0',
              'privacy_policy_version': '1.0',
              'consent_accepted_at': acceptedAt,
            },
          ),
        );
        user = updateRes.user ?? user;
      } catch (e) {
        debugPrint("Update user metadata during OTP confirmation: $e");
      }
    } else {
      // User is not yet authenticated in session
      AuthResponse? authResponse;
      try {
        authResponse = await _supabase.auth.signUp(
          email: cleanEmail,
          password: password,
          data: {
            'first_name': cleanFirstName,
            if (cleanMiddleName != null && cleanMiddleName.isNotEmpty) 'middle_name': cleanMiddleName,
            'last_name': cleanLastName,
            'name': cleanFullName,
            'full_name': cleanFullName,
            'username': cleanUsername,
            'contact_number': cleanContactNumber,
            if (cleanAddress != null && cleanAddress.isNotEmpty) 'address': cleanAddress,
            'terms_version': '1.0',
            'privacy_policy_version': '1.0',
            'consent_accepted_at': acceptedAt,
          },
        );
        user = authResponse.user ?? _supabase.auth.currentUser;
      } catch (e) {
        debugPrint("Supabase signUp error during OTP confirmation: $e");
        // User may already be registered in auth.users
        try {
          final res = await _supabase.auth.signInWithPassword(
            email: cleanEmail,
            password: password,
          );
          user = res.user;
        } catch (_) {
          // If signInWithPassword failed, check if user profile exists in profiles table
          try {
            final existingProfile = await _supabase
                .from('profiles')
                .select('id')
                .eq('email', cleanEmail)
                .maybeSingle();

            if (existingProfile != null) {
              throw const AuthException("An account with this email is already registered. Please sign in instead.");
            }
          } catch (pe) {
            if (pe is AuthException) rethrow;
          }
        }
      }
    }

    // Explicitly update user metadata if session is active
    if (_supabase.auth.currentUser != null) {
      try {
        await _supabase.auth.updateUser(
          UserAttributes(
            password: password,
            data: {
              'first_name': cleanFirstName,
              if (cleanMiddleName != null && cleanMiddleName.isNotEmpty) 'middle_name': cleanMiddleName,
              'last_name': cleanLastName,
              'name': cleanFullName,
              'full_name': cleanFullName,
              'contact_number': cleanContactNumber,
              if (cleanAddress != null && cleanAddress.isNotEmpty) 'address': cleanAddress,
            },
          ),
        );
      } catch (_) {}
    }

    // Get real UUID from Supabase Auth
    final userId = user?.id ?? _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException("Registration failed: Unable to link user account in Supabase Auth.");
    }

    final isOwnerEmail = cleanEmail == 'mberuela11@gmail.com' ||
        cleanEmail == 'jubileealfonnn@gmail.com' ||
        cleanEmail == 'owner@bellies.com';

    final profilePayload = {
      'id': userId,
      'email': cleanEmail,
      'full_name': cleanFullName,
      'first_name': cleanFirstName,
      'middle_name': cleanMiddleName,
      'last_name': cleanLastName,
      'username': cleanUsername,
      if (cleanContactNumber != null && cleanContactNumber.isNotEmpty)
        'contact_number': cleanContactNumber,
      if (cleanAddress != null && cleanAddress.isNotEmpty)
        'address': cleanAddress,
      'position': isOwnerEmail ? 'Owner / Manager' : 'Customer',
      'role': isOwnerEmail ? 'OWNER' : 'CUSTOMER',
      'account_status': 'ACTIVE',
    };

    try {
      final created = await _supabase
          .from('profiles')
          .upsert(profilePayload)
          .select()
          .single();

      return UserModel.fromJson(created);
    } catch (e) {
      debugPrint("Profiles upsert warning (handled): $e");
      try {
        final existing = await _supabase
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (existing != null) {
          return UserModel.fromJson(existing);
        }
      } catch (_) {}

      return UserModel(
        id: userId,
        email: cleanEmail,
        fullName: cleanFullName,
        position: 'Customer',
        role: UserRole.customer,
        accountStatus: AccountStatus.active,
      );
    }
  }

  /// Resends the signup OTP verification code to the specified email
  Future<void> resendSignUpOTP({required String email, String fullName = "Customer"}) async {
    final cleanEmail = email.trim().toLowerCase();
    final pendingData = _pendingSignUpData[cleanEmail];
    final recipientName = (pendingData?['fullName'] ?? fullName).toString().trim();

    try {
      final newOtpCode = await GmailEmailService().sendSignUpOtpEmail(
        recipientEmail: cleanEmail,
        recipientName: recipientName,
      );
      if (pendingData != null) {
        pendingData['otpCode'] = newOtpCode.trim();
      }
    } catch (e) {
      debugPrint("Resend Gmail OTP error: $e");
      throw AuthException("Failed to resend verification code: $e");
    }
  }

  /// Formats a Philippine phone number into standard international format (+639xxxxxxxxx)
  static String formatPhPhoneNumber(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '63${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('63')) {
      cleaned = '63$cleaned';
    }
    return '+$cleaned';
  }

  /// Sends a signup OTP verification code via SMS (Phone)
  Future<void> sendSignUpSMS({required String phone}) async {
    final formattedPhone = formatPhPhoneNumber(phone);
    try {
      await _supabase.auth.signInWithOtp(
        phone: formattedPhone,
        shouldCreateUser: true,
      );
      debugPrint("✅ [SMS OTP] Sent verification code to $formattedPhone");
    } catch (e) {
      debugPrint("⚠️ [SMS OTP ERROR]: $e");
      final str = e.toString().toLowerCase();
      if (str.contains('phone_provider_disabled') || str.contains('unsupported phone provider') || str.contains('disabled')) {
        throw const AuthException("SMS OTP provider is currently disabled in database settings. Please verify using Gmail OTP.");
      }
      throw AuthException("Unable to send SMS code to $formattedPhone. Please verify using Gmail OTP.");
    }
  }

  /// Sign Up with Email & Password (Customer Account)
  Future<UserModel> signUpCustomerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    String? contactNumber,
    String? address,
    String termsVersion = '1.0',
    String privacyPolicyVersion = '1.0',
  }) async {
    final acceptedAt = DateTime.now().toIso8601String();
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': fullName,
        'full_name': fullName,
        'contact_number': contactNumber,
        if (address != null && address.isNotEmpty) 'address': address,
        'terms_version': termsVersion,
        'privacy_policy_version': privacyPolicyVersion,
        'consent_accepted_at': acceptedAt,
      },
    );

    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'name': fullName,
            'full_name': fullName,
          },
        ),
      );
    } catch (_) {}

    final user = response.user;
    if (user == null) {
      throw const AuthException('Sign up failed. Please try again.');
    }

    final profilePayload = {
      'id': user.id,
      'email': email,
      'full_name': fullName,
      'contact_number': contactNumber,
      if (address != null && address.isNotEmpty) 'address': address,
      'position': 'Customer',
      'role': 'CUSTOMER',
      'account_status': 'ACTIVE',
    };

    try {
      final created = await _supabase
          .from('profiles')
          .upsert(profilePayload)
          .select()
          .single();

      return UserModel.fromJson(created);
    } catch (_) {
      return UserModel(
        id: user.id,
        email: email,
        fullName: fullName,
        contactNumber: contactNumber,
        position: 'Customer',
        role: UserRole.guest,
        accountStatus: AccountStatus.active,
      );
    }
  }

  /// Update customer contact details and address
  Future<void> updateCustomerDetails({
    required String userId,
    String? contactNumber,
    String? address,
  }) async {
    final updates = <String, dynamic>{};
    if (contactNumber != null && contactNumber.isNotEmpty) {
      updates['contact_number'] = contactNumber;
    }
    if (address != null && address.isNotEmpty) {
      updates['address'] = address;
    }

    if (updates.isNotEmpty) {
      await _supabase.from('profiles').update(updates).eq('id', userId);
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
