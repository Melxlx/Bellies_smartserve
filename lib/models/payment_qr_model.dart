class PaymentQrModel {
  final String id;
  final String providerName; // e.g. GCash, Maya, BPI
  final String accountName;
  final String accountNumber;
  final String qrImageUrl;
  final bool isActive;

  PaymentQrModel({
    required this.id,
    required this.providerName,
    required this.accountName,
    required this.accountNumber,
    required this.qrImageUrl,
    required this.isActive,
  });

  factory PaymentQrModel.fromJson(Map<String, dynamic> json) {
    return PaymentQrModel(
      id: json['id']?.toString() ?? '',
      providerName: json['provider_name']?.toString() ?? 'GCash',
      accountName: json['account_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      qrImageUrl: json['qr_image_url']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider_name': providerName,
      'account_name': accountName,
      'account_number': accountNumber,
      'qr_image_url': qrImageUrl,
      'is_active': isActive,
    };
  }
}
