import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsRepository {
  SettingsRepository({this.client});

  final SupabaseClient? client;
  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  Future<Map<String, dynamic>> getBusinessSettings() async {
    final response = await _supabase.from('business_settings').select().single();
    return response;
  }

  Future<void> updateBusinessSettings(Map<String, dynamic> updates) async {
    final settings = await _supabase.from('business_settings').select('id').single();
    await _supabase.from('business_settings').update(updates).eq('id', settings['id']);
  }

  Future<void> updateProfile(String fullName) async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _supabase.from('profiles').update({'full_name': fullName}).eq('id', user.id);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }
}
