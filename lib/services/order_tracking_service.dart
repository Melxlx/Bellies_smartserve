import 'package:flutter/foundation.dart';

class OrderTrackingService extends ChangeNotifier {
  // Singleton pattern
  static final OrderTrackingService _instance = OrderTrackingService._internal();
  factory OrderTrackingService() => _instance;
  OrderTrackingService._internal();

  String? _lastTrackingNumber;
  String? get lastTrackingNumber => _lastTrackingNumber;

  void setTrackingNumber(String number) {
    _lastTrackingNumber = number;
    notifyListeners();
  }

  void clear() {
    _lastTrackingNumber = null;
    notifyListeners();
  }
}
