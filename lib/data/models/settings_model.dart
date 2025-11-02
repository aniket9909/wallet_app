import 'package:equatable/equatable.dart';

class SettingsModel extends Equatable {
  final bool notificationsEnabled;
  final BankDetails? bankDetails;
  final CardDetails? cardDetails;
  final List<String> expenseTypes;
  final UserProfile profile;
  final bool darkMode;
  final String currency;

  const SettingsModel({
    required this.notificationsEnabled,
    this.bankDetails,
    this.cardDetails,
    required this.expenseTypes,
    required this.profile,
    this.darkMode = false,
    this.currency = '₹',
  });

  factory SettingsModel.fromJson(Map<dynamic, dynamic> json) {
    return SettingsModel(
      notificationsEnabled: json['notifications'] ?? true,
      bankDetails: json['bank_details'] != null
          ? BankDetails.fromJson(json['bank_details'])
          : null,
      cardDetails: json['card_details'] != null
          ? CardDetails.fromJson(json['card_details'])
          : null,
      expenseTypes: json['expense_types'] != null
          ? List<String>.from(json['expense_types'])
          : ['Food', 'Bills', 'Shopping', 'Travel', 'Entertainment', 'Health', 'Other'],
      profile: json['profile'] != null
          ? UserProfile.fromJson(json['profile'])
          : const UserProfile(name: '', email: ''),
      darkMode: json['dark_mode'] ?? false,
      currency: json['currency'] ?? '₹',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notifications': notificationsEnabled,
      'bank_details': bankDetails?.toJson(),
      'card_details': cardDetails?.toJson(),
      'expense_types': expenseTypes,
      'profile': profile.toJson(),
      'dark_mode': darkMode,
      'currency': currency,
    };
  }

  SettingsModel copyWith({
    bool? notificationsEnabled,
    BankDetails? bankDetails,
    CardDetails? cardDetails,
    List<String>? expenseTypes,
    UserProfile? profile,
    bool? darkMode,
    String? currency,
  }) {
    return SettingsModel(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      bankDetails: bankDetails ?? this.bankDetails,
      cardDetails: cardDetails ?? this.cardDetails,
      expenseTypes: expenseTypes ?? this.expenseTypes,
      profile: profile ?? this.profile,
      darkMode: darkMode ?? this.darkMode,
      currency: currency ?? this.currency,
    );
  }

  @override
  List<Object?> get props => [
        notificationsEnabled,
        bankDetails,
        cardDetails,
        expenseTypes,
        profile,
        darkMode,
        currency,
      ];
}

class BankDetails extends Equatable {
  final String accountNumber;
  final String ifsc;
  final String bankName;

  const BankDetails({
    required this.accountNumber,
    required this.ifsc,
    this.bankName = '',
  });

  factory BankDetails.fromJson(Map<dynamic, dynamic> json) {
    return BankDetails(
      accountNumber: json['account_number'] ?? '',
      ifsc: json['ifsc'] ?? '',
      bankName: json['bank_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_number': accountNumber,
      'ifsc': ifsc,
      'bank_name': bankName,
    };
  }

  @override
  List<Object?> get props => [accountNumber, ifsc, bankName];
}

class CardDetails extends Equatable {
  final String cardNumber;
  final String expiry;
  final String cardType;

  const CardDetails({
    required this.cardNumber,
    required this.expiry,
    this.cardType = 'Debit',
  });

  factory CardDetails.fromJson(Map<dynamic, dynamic> json) {
    return CardDetails(
      cardNumber: json['card_number'] ?? '',
      expiry: json['expiry'] ?? '',
      cardType: json['card_type'] ?? 'Debit',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'card_number': cardNumber,
      'expiry': expiry,
      'card_type': cardType,
    };
  }

  @override
  List<Object?> get props => [cardNumber, expiry, cardType];
}

class UserProfile extends Equatable {
  final String name;
  final String email;
  final String? phone;
  final String? avatar;

  const UserProfile({
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
  });

  factory UserProfile.fromJson(Map<dynamic, dynamic> json) {
    return UserProfile(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      avatar: json['avatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'avatar': avatar,
    };
  }

  @override
  List<Object?> get props => [name, email, phone, avatar];
}

