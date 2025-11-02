import 'package:equatable/equatable.dart';

class AccountModel extends Equatable {
  final String id;
  final String name;
  final double balance;
  final String type; // Bank, Cash, UPI, Credit Card
  final String? icon;
  final String? color;

  const AccountModel({
    required this.id,
    required this.name,
    required this.balance,
    required this.type,
    this.icon,
    this.color,
  });

  factory AccountModel.fromJson(String id, Map<dynamic, dynamic> json) {
    return AccountModel(
      id: id,
      name: json['name'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      type: json['type'] ?? 'Cash',
      icon: json['icon'],
      color: json['color'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'balance': balance,
      'type': type,
      'icon': icon,
      'color': color,
    };
  }

  AccountModel copyWith({
    String? id,
    String? name,
    double? balance,
    String? type,
    String? icon,
    String? color,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }

  @override
  List<Object?> get props => [id, name, balance, type, icon, color];
}

