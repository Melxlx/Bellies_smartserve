import 'order_model.dart';

/// Owned by the customer's menu/cart route, so checkout can be reopened without
/// losing the address. This draft is deliberately not a shared global or a
/// persistent store of personal information.
class CustomerCheckoutDraft {
  CustomerDetails? details;
  String gcashReference;
  String paymentProofUrl;

  CustomerCheckoutDraft({this.details, this.gcashReference = '', this.paymentProofUrl = ''});

  // Simplified and unified with CustomerDetails validation
  bool get hasConfirmedAddress {
    final d = details;
    if (d == null) return false;
    
    // We only need a confirmed map point and basic recipient details to proceed.
    return d.locationConfirmed && 
           d.latitude != null && 
           d.longitude != null &&
           d.name.trim().isNotEmpty &&
           d.address.trim().isNotEmpty;
  }

  void clear() {
    details = null;
    gcashReference = '';
    paymentProofUrl = '';
  }
}

class CustomerCheckoutArguments {
  final List<OrderItem> cart;
  final CustomerCheckoutDraft draft;

  const CustomerCheckoutArguments({required this.cart, required this.draft});
}
