import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_qr_model.dart';

class PaymentQrRepository {
  final _supabase = Supabase.instance.client;

  Future<List<PaymentQrModel>> getPaymentQrs() async {
    List<PaymentQrModel> dbList = [];
    try {
      final response = await _supabase
          .from('payment_qrs')
          .select()
          .order('created_at', ascending: false);
      dbList = (response as List).map((json) => PaymentQrModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Database getPaymentQrs failed: $e");
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_payment_qrs');
      if (cachedStr != null) {
        final List<dynamic> decoded = jsonDecode(cachedStr);
        final cachedList = decoded.map((j) => PaymentQrModel.fromJson(j)).toList();
        for (var c in cachedList) {
          if (!dbList.any((d) => d.id == c.id || d.accountNumber == c.accountNumber)) {
            dbList.add(c);
          }
        }
      }
    } catch (_) {}

    return dbList;
  }

  Future<PaymentQrModel?> getActiveQr() async {
    try {
      final qrs = await getPaymentQrs();
      return qrs.firstWhere(
        (q) => q.isActive,
        orElse: () => qrs.isNotEmpty ? qrs.first : PaymentQrModel(id: '', providerName: 'GCash', accountName: 'Default', accountNumber: '09171234567', qrImageUrl: '', isActive: true),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveQr(PaymentQrModel qr) async {
    try {
      if (qr.isActive) {
        await _supabase.from('payment_qrs').update({'is_active': false});
      }
      if (qr.id.isEmpty) {
        await _supabase.from('payment_qrs').insert(qr.toJson());
      } else {
        await _supabase.from('payment_qrs').update(qr.toJson()).eq('id', qr.id);
      }
    } catch (e) {
      debugPrint("Database saveQr failed ($e). Saving to local cache...");
      final prefs = await SharedPreferences.getInstance();
      final qrs = await getPaymentQrs();

      if (qr.isActive) {
        for (var i = 0; i < qrs.length; i++) {
          final q = qrs[i];
          qrs[i] = PaymentQrModel(
            id: q.id,
            providerName: q.providerName,
            accountName: q.accountName,
            accountNumber: q.accountNumber,
            qrImageUrl: q.qrImageUrl,
            isActive: false,
          );
        }
      }

      if (qr.id.isEmpty) {
        final newQr = PaymentQrModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          providerName: qr.providerName,
          accountName: qr.accountName,
          accountNumber: qr.accountNumber,
          qrImageUrl: qr.qrImageUrl,
          isActive: qr.isActive,
        );
        qrs.insert(0, newQr);
      } else {
        final index = qrs.indexWhere((q) => q.id == qr.id);
        if (index >= 0) {
          qrs[index] = qr;
        } else {
          qrs.add(qr);
        }
      }
      final encoded = jsonEncode(qrs.map((q) => q.toJson()).toList());
      await prefs.setString('cached_payment_qrs', encoded);
    }
  }

  Future<void> toggleActive(String id, bool isActive) async {
    try {
      if (isActive) {
        await _supabase.from('payment_qrs').update({'is_active': false}).neq('id', id);
      }
      await _supabase.from('payment_qrs').update({'is_active': isActive}).eq('id', id);
    } catch (e) {
      debugPrint("Database toggleActive failed ($e). Updating local cache...");
      final prefs = await SharedPreferences.getInstance();
      final qrs = await getPaymentQrs();
      
      for (var i = 0; i < qrs.length; i++) {
        final q = qrs[i];
        if (isActive && q.id == id) {
          qrs[i] = PaymentQrModel(id: q.id, providerName: q.providerName, accountName: q.accountName, accountNumber: q.accountNumber, qrImageUrl: q.qrImageUrl, isActive: true);
        } else if (isActive) {
          qrs[i] = PaymentQrModel(id: q.id, providerName: q.providerName, accountName: q.accountName, accountNumber: q.accountNumber, qrImageUrl: q.qrImageUrl, isActive: false);
        } else if (q.id == id) {
          qrs[i] = PaymentQrModel(id: q.id, providerName: q.providerName, accountName: q.accountName, accountNumber: q.accountNumber, qrImageUrl: q.qrImageUrl, isActive: false);
        }
      }
      await prefs.setString('cached_payment_qrs', jsonEncode(qrs.map((q) => q.toJson()).toList()));
    }
  }

  Future<void> deleteQr(String id) async {
    try {
      await _supabase.from('payment_qrs').delete().eq('id', id);
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final qrs = await getPaymentQrs();
      qrs.removeWhere((q) => q.id == id);
      await prefs.setString('cached_payment_qrs', jsonEncode(qrs.map((q) => q.toJson()).toList()));
    }
  }
}
