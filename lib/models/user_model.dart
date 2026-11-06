enum UserRole { owner, cashier, kitchen, rider, guest, customer }

enum AccountStatus { active, archived, locked, deleted }

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? contactNumber;
  final String? avatarUrl;
  final String position;
  final UserRole role;
  final AccountStatus accountStatus;
  final String? rfidUid;
  final bool isCardActive;
  final double dailyRate;

  final bool isTrustedCustomer;
  final String? ownerNotes;
  final bool isOnline;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.firstName,
    this.middleName,
    this.lastName,
    this.contactNumber,
    this.avatarUrl,
    required this.position,
    required this.role,
    required this.accountStatus,
    this.rfidUid,
    this.isCardActive = true,
    this.dailyRate = 0,
    this.isTrustedCustomer = false,
    this.ownerNotes,
    this.isOnline = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['role'] as String? ?? 'CUSTOMER').toUpperCase();

    Map<String, dynamic>? empDetails;
    if (json['employee_details'] is List && (json['employee_details'] as List).isNotEmpty) {
      empDetails = (json['employee_details'] as List).first as Map<String, dynamic>?;
    } else if (json['employee_details'] is Map) {
      empDetails = json['employee_details'] as Map<String, dynamic>?;
    }

    String normalizedRole = rawRole;
    if (rawRole == 'DRIVER') {
      normalizedRole = 'RIDER';
    } else if (rawRole == 'GUEST') {
      normalizedRole = 'CUSTOMER';
    }

    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'No Name',
      firstName: json['first_name']?.toString(),
      middleName: json['middle_name']?.toString(),
      lastName: json['last_name']?.toString(),
      contactNumber: json['contact_number']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      position: empDetails?['position']?.toString() ?? json['position']?.toString() ?? 'Customer',
      role: UserRole.values.firstWhere(
        (e) => e.name.toUpperCase() == normalizedRole,
        orElse: () => UserRole.customer,
      ),
      accountStatus: AccountStatus.values.firstWhere(
        (e) =>
            e.name.toUpperCase() ==
            (json['account_status'] as String? ?? 'ACTIVE').toUpperCase(),
        orElse: () => AccountStatus.active,
      ),
      rfidUid: empDetails?['rfid_uid']?.toString() ?? json['rfid_uid']?.toString(),
      isCardActive: empDetails?['is_card_active'] ?? json['is_card_active'] ?? true,
      dailyRate: (empDetails?['daily_rate'] as num? ?? json['daily_rate'] as num? ?? 0).toDouble(),
      isTrustedCustomer: json['is_trusted_customer'] as bool? ?? false,
      ownerNotes: json['owner_notes']?.toString(),
      isOnline: json['is_online'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    final isCustomer = role == UserRole.guest || role == UserRole.customer;
    return {
      'full_name': fullName,
      'position': position,
      'role': isCustomer ? 'CUSTOMER' : role.name.toUpperCase(),
      'account_status': accountStatus.name.toUpperCase(),
      'rfid_uid': rfidUid,
      'is_card_active': isCardActive,
      if (!isCustomer) 'daily_rate': dailyRate,
      'is_trusted_customer': isTrustedCustomer,
      'owner_notes': ownerNotes,
      'is_online': isOnline,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? firstName,
    String? middleName,
    String? lastName,
    String? contactNumber,
    String? avatarUrl,
    String? position,
    UserRole? role,
    AccountStatus? accountStatus,
    String? rfidUid,
    bool? isCardActive,
    double? dailyRate,
    bool? isTrustedCustomer,
    String? ownerNotes,
    bool? isOnline,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      contactNumber: contactNumber ?? this.contactNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      position: position ?? this.position,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      rfidUid: rfidUid ?? this.rfidUid,
      isCardActive: isCardActive ?? this.isCardActive,
      dailyRate: dailyRate ?? this.dailyRate,
      isTrustedCustomer: isTrustedCustomer ?? this.isTrustedCustomer,
      ownerNotes: ownerNotes ?? this.ownerNotes,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
