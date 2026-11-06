import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_qr_model.dart';

class PaymentQrRepository {
  final _supabase = Supabase.instance.client;

  Future<List<PaymentQrModel>> getPaymentQrs() async {
    try {
      final response = await _supabase
          .from('payment_qrs')
          .select()
          .order('created_at', ascending: false);
      return (response as List).map((json) => PaymentQrModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<PaymentQrModel?> getActiveQr() async {
    try {
      final response = await _supabase
          .from('payment_qrs')
          .select()
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();
      if (response != null) {
        return PaymentQrModel.fromJson(response);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveQr(PaymentQrModel qr) async {
    if (qr.id.isEmpty) {
      await _supabase.from('payment_qrs').insert(qr.toJson());
    } else {
      await _supabase.from('payment_qrs').update(qr.toJson()).eq('id', qr.id);
    }
  }

  Future<void> toggleActive(String id, bool isActive) async {
    await _supabase.from('payment_qrs').update({'is_active': isActive}).eq('id', id);
  }

  Future<void> deleteQr(String id) async {
    await _supabase.from('payment_qrs').delete().eq('id', id);
  }
}
