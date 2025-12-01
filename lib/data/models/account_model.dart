import 'package:equatable/equatable.dart';

class AccountModel extends Equatable {
  final String id;
  final String name;
  final double balance;
  final String type; // Bank, Cash, UPI, Credit Card
  final String? icon;
  final String? color;
  final String? lastDigits; // last 4 or 6 digits

  const AccountModel({
    required this.id,
    required this.name,
    required this.balance,
    required this.type,
    this.icon,
    this.color,
    this.lastDigits,
  });

  factory AccountModel.fromJson(String id, Map<dynamic, dynamic> json) {
    return AccountModel(
      id: id,
      name: json['name'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      type: json['type'] ?? 'Cash',
      icon: json['icon'],
      color: json['color'],
      lastDigits: json['last_digits'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'balance': balance,
      'type': type,
      'icon': icon,
      'color': color,
      'last_digits': lastDigits,
    };
  }

  AccountModel copyWith({
    String? id,
    String? name,
    double? balance,
    String? type,
    String? icon,
    String? color,
    String? lastDigits,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      lastDigits: lastDigits ?? this.lastDigits,
    );
  }

  @override
  List<Object?> get props => [id, name, balance, type, icon, color, lastDigits];
}

