class WalletModel {
  final String id;
  final String name;
  final String type;
  final double balance;
  final DateTime createdAt;

  WalletModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.createdAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json, String id) {
    return WalletModel(
      id: id,
      name: json['name'],
      type: json['type'],
      balance: (json['balance'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'balance': balance,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
