import 'product_model.dart';

enum ServiceType { dineIn, takeout, delivery }
enum PaymentMethod { cash, gcash }
enum DeliveryStatus { preparing, readyForDelivery, outForDelivery, delivered, cancelled }

class OrderModel {
  final String id;
  final String queueNumber;
  final String trackingNumber;
  final List<OrderItem> items;
  final DateTime timestamp;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final double? deliveryDistanceKm;
  final ServiceType serviceType;
  final CustomerDetails? customerDetails;
  String status;
  final String paymentStatus;
  DeliveryStatus? deliveryStatus;
  final PaymentMethod? paymentMethod;
  final double? amountTendered;
  final double? change;
  final String? referenceNumber;
  final DateTime? completedAt;
  String? estimatedDeliveryTime;
  final String? riderId;
  final String? riderName;
  final String? createdBy;
  final String? cashierName;
  final String? deliveryProofUrl;
  final String? paymentProofUrl;

  OrderModel({
    required this.id,
    required this.queueNumber,
    required this.trackingNumber,
    required this.items,
    required this.timestamp,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalAmount,
    this.deliveryDistanceKm,
    required this.serviceType,
    this.customerDetails,
    this.status = 'New',
    this.paymentStatus = 'PENDING',
    this.deliveryStatus,
    this.paymentMethod,
    this.amountTendered,
    this.change,
    this.referenceNumber,
    this.completedAt,
    this.estimatedDeliveryTime,
    this.riderId,
    this.riderName,
    this.createdBy,
    this.cashierName,
    this.deliveryProofUrl,
    this.paymentProofUrl,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    String? resolvedCashierName = json['cashier_name']?.toString();
    if (resolvedCashierName == null || resolvedCashierName.isEmpty) {
      if (json['cashier'] != null && json['cashier']['full_name'] != null) {
        resolvedCashierName = json['cashier']['full_name'].toString();
      } else if (json['created_by_profile'] != null && json['created_by_profile']['full_name'] != null) {
        final name = json['created_by_profile']['full_name'].toString();
        final role = json['created_by_profile']['role']?.toString().toUpperCase() ?? '';
        final pos = json['created_by_profile']['position']?.toString() ?? '';
        if (role == 'OWNER' || pos.toLowerCase().contains('owner')) {
          resolvedCashierName = "$name (Owner)";
        } else if (role != 'CUSTOMER') {
          resolvedCashierName = name;
        }
      } else if (json['processed_by_profile'] != null && json['processed_by_profile']['full_name'] != null) {
        resolvedCashierName = json['processed_by_profile']['full_name'].toString();
      }
    }

    return OrderModel(
      id: json['id']?.toString() ?? '',
      queueNumber: (json['queue_no'] ?? json['queue_number'])?.toString() ?? '000',
      trackingNumber: json['tracking_number'] ?? '',
      items: (json['order_items'] as List? ?? [])
          .map((i) => OrderItem.fromJson(i))
          .toList(),
      timestamp: json['created_at'] != null ? DateTime.parse(json['created_at']).toLocal() : DateTime.now(),
      subtotal: (json['subtotal'] as num? ?? 0).toDouble(),
      deliveryFee: (json['delivery_fee'] as num? ?? 0).toDouble(),
      totalAmount: (json['total_amount'] as num? ?? 0).toDouble(),
      deliveryDistanceKm: (json['delivery_distance_km'] as num? ?? json['customer_details']?['delivery_distance_km'] as num?)?.toDouble(),
      serviceType: _serviceTypeFromDatabase(json['service_type'] ?? json['order_type']),
      customerDetails: json['customer_details'] != null
          ? CustomerDetails.fromJson(json['customer_details'])
          : null,
      status: json['status']?.toString() ?? 'received',
      paymentStatus: ((json['payment_status'] ?? 'PENDING') as String).trim().toUpperCase(),
      deliveryStatus: json['delivery_status'] != null
          ? _deliveryStatusFromDatabase(json['delivery_status'])
          : null,
      paymentMethod: json['payment_method'] != null
          ? PaymentMethod.values.firstWhere((e) => e.name.toLowerCase() == json['payment_method'].toString().toLowerCase(), orElse: () => PaymentMethod.cash)
          : null,
      amountTendered: (json['amount_tendered'] as num?)?.toDouble(),
      change: (json['change_amount'] as num? ?? json['change'] as num? ?? 0).toDouble(),
      referenceNumber: json['reference_number'],
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']).toLocal() : null,
      estimatedDeliveryTime: json['estimated_delivery_time'],
      riderId: json['rider_id']?.toString(),
      riderName: json['profiles']?['full_name']?.toString(),
      createdBy: json['created_by']?.toString(),
      cashierName: resolvedCashierName,
      deliveryProofUrl: json['delivery_proof_url']?.toString() ?? json['proof_url']?.toString() ?? json['customer_details']?['proof_url']?.toString(),
      paymentProofUrl: json['payment_proof_url']?.toString() ?? json['proof_url']?.toString() ?? json['customer_details']?['proof_url']?.toString(),
    );
  }

  static ServiceType _serviceTypeFromDatabase(dynamic value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'dinein':
      case 'dine_in':
      case 'dine-in':
        return ServiceType.dineIn;
      case 'takeout':
      case 'take_out':
      case 'take-out':
        return ServiceType.takeout;
      case 'delivery':
        return ServiceType.delivery;
      default:
        return ServiceType.dineIn;
    }
  }

  static DeliveryStatus _deliveryStatusFromDatabase(dynamic value) {
    final normalized = value
        .toString()
        .trim()
        .replaceAll('-', '')
        .replaceAll('_', '')
        .toLowerCase();
    return DeliveryStatus.values.firstWhere(
      (status) => status.name.toLowerCase() == normalized,
      orElse: () => DeliveryStatus.preparing,
    );
  }

  OrderModel copyWith({
    String? id,
    String? queueNumber,
    String? status,
    String? paymentStatus,
    DeliveryStatus? deliveryStatus,
    DateTime? completedAt,
    String? estimatedDeliveryTime,
    String? riderId,
    String? riderName,
    String? createdBy,
    String? cashierName,
    CustomerDetails? customerDetails,
    String? deliveryProofUrl,
    double? deliveryDistanceKm,
    double? deliveryFee,
    double? totalAmount,
  }) {
    return OrderModel(
      id: id ?? this.id,
      queueNumber: queueNumber ?? this.queueNumber,
      trackingNumber: trackingNumber,
      items: items,
      timestamp: timestamp,
      subtotal: subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      totalAmount: totalAmount ?? this.totalAmount,
      deliveryDistanceKm: deliveryDistanceKm ?? this.deliveryDistanceKm,
      serviceType: serviceType,
      customerDetails: customerDetails ?? this.customerDetails,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      paymentMethod: paymentMethod,
      amountTendered: amountTendered,
      change: change,
      referenceNumber: referenceNumber,
      completedAt: completedAt ?? this.completedAt,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      createdBy: createdBy ?? this.createdBy,
      cashierName: cashierName ?? this.cashierName,
      deliveryProofUrl: deliveryProofUrl ?? this.deliveryProofUrl,
    );
  }

  String get itemsSummary {
    if (items.isEmpty) return 'No items listed';
    return items.map((i) {
      final qty = i.quantity > 1 ? " x${i.quantity}" : " x1";
      final instr = (i.instructions != null && i.instructions!.isNotEmpty) ? " (${i.instructions})" : "";
      return "${i.product.name}$qty$instr";
    }).join(", ");
  }

  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inSeconds < 45) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "";
  }
}

class OrderItem {
  final ProductModel product;
  int quantity;
  String? instructions;

  OrderItem({
    required this.product,
    required this.quantity,
    this.instructions,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final instr = json['item_instructions'] ?? json['instructions'];

    ProductModel resolvedProduct;
    if (json['product'] != null || json['products'] != null) {
      resolvedProduct = ProductModel.fromJson(json['product'] ?? json['products']);
    } else {
      resolvedProduct = ProductModel(
        id: json['product_id']?.toString() ?? '',
        sku: '',
        name: json['product_name_snapshot']?.toString() ?? json['product_name']?.toString() ?? 'Item',
        sellingPrice: (json['unit_price'] as num? ?? json['selling_price'] as num? ?? 0).toDouble(),
        estimatedCost: (json['unit_cost'] as num? ?? 0).toDouble(),
        categoryId: '',
        status: ProductStatus.available,
        createdAt: DateTime.now(),
      );
    }

    return OrderItem(
      product: resolvedProduct,
      quantity: (json['quantity'] as num? ?? 1).toInt(),
      instructions: instr?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'quantity': quantity,
    'instructions': instructions,
  };

  double get total => product.sellingPrice * quantity;
}

class CustomerDetails {
  final String name;
  final String contact;
  final String address;
  final String landmark;
  final String notes;
  final String houseUnit;
  final String deliveryInstructions;
  final double? latitude;
  final double? longitude;
  final bool locationConfirmed;
  final double? deliveryDistanceKm;
  final double? calculatedDeliveryFee;

  CustomerDetails({
    required this.name,
    required this.contact,
    required this.address,
    required this.landmark,
    required this.notes,
    this.houseUnit = '',
    this.deliveryInstructions = '',
    this.latitude,
    this.longitude,
    this.locationConfirmed = false,
    this.deliveryDistanceKm,
    this.calculatedDeliveryFee,
  });

  bool get hasConfirmedDeliveryLocation =>
      locationConfirmed ||
      (latitude != null &&
          longitude != null &&
          latitude!.isFinite &&
          longitude!.isFinite &&
          latitude! >= -90 &&
          latitude! <= 90 &&
          longitude! >= -180 &&
          longitude! <= 180);

  static bool isValidContact(String value) => RegExp(r'^\+?[0-9]{7,15}$')
      .hasMatch(value.replaceAll(RegExp(r'[\s()\-]'), ''));

  bool get hasRequiredDeliveryDetails =>
      hasConfirmedDeliveryLocation &&
      name.trim().isNotEmpty &&
      isValidContact(contact) &&
      address.trim().isNotEmpty;

  String get fullAddress => [houseUnit.trim(), address.trim()]
      .where((part) => part.isNotEmpty)
      .join(', ');

  Map<String, dynamic> toJson() => {
    'name': name,
    'contact': contact,
    'address': address,
    'landmark': landmark,
    'notes': notes,
    'house_unit': houseUnit,
    'delivery_instructions': deliveryInstructions,
    'latitude': latitude,
    'longitude': longitude,
    'location_confirmed': locationConfirmed,
    if (deliveryDistanceKm != null) 'delivery_distance_km': deliveryDistanceKm,
    if (calculatedDeliveryFee != null) 'calculated_delivery_fee': calculatedDeliveryFee,
  };

  factory CustomerDetails.fromJson(Map<String, dynamic> json) {
    return CustomerDetails(
      name: json['name'] ?? '',
      contact: json['contact'] ?? '',
      address: json['address'] ?? '',
      landmark: json['landmark'] ?? '',
      notes: json['notes'] ?? '',
      houseUnit: json['house_unit'] ?? '',
      deliveryInstructions: json['delivery_instructions'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationConfirmed: json['location_confirmed'] == true,
      deliveryDistanceKm: (json['delivery_distance_km'] as num?)?.toDouble(),
      calculatedDeliveryFee: (json['calculated_delivery_fee'] as num?)?.toDouble(),
    );
  }
}
