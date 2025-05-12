class TypeMasterModel {
  final String id;
  final String name;
  final String value;
  final DateTime createdAt;

  TypeMasterModel({
    required this.id,
    required this.name,
    required this.value,
    required this.createdAt,
  });

  factory TypeMasterModel.fromJson(Map<String, dynamic> json, String id) {
    return TypeMasterModel(
      id: id,
      name: json['name'],
      value: json['value'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
