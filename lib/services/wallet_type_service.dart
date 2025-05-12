import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ewallet/models/wallet_type_master_model.dart';

class TypeMasterService {
  final CollectionReference _typeMasterRef =
      FirebaseFirestore.instance.collection('wallet_type_master');

  /// 🔹 Add a new wallet type
  Future<void> addType(TypeMasterModel type) async {
    try {
      await _typeMasterRef.doc(type.id).set(type.toJson());
    } catch (e) {
      // Handle Firestore errors (e.g., permissions, connectivity)
      print('Failed to add wallet type: $e');
      rethrow;
    }
  }

  /// 🔹 Get all types
  Future<List<TypeMasterModel>> getTypes() async {
    final snapshot = await _typeMasterRef.get();
    return snapshot.docs.map((doc) {
      return TypeMasterModel.fromJson(
          doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  Future<void> addDefaultWalletTypes() async {
    final typeService = TypeMasterService();

    final types = [
      TypeMasterModel(
        id: 'wallet_cash',
        name: 'Cash',
        value: 'cash',
        createdAt: DateTime.now(),
      ),
      TypeMasterModel(
        id: 'wallet_bank',
        name: 'Bank',
        value: 'bank',
        createdAt: DateTime.now(),
      ),
      TypeMasterModel(
        id: 'wallet_sbi',
        name: 'SBI Bank',
        value: 'sbi_bank',
        createdAt: DateTime.now(),
      ),
      TypeMasterModel(
        id: 'wallet_axis',
        name: 'Axis Bank',
        value: 'axis_bank',
        createdAt: DateTime.now(),
      ),
      TypeMasterModel(
        id: 'wallet_upi',
        name: 'UPI',
        value: 'upi',
        createdAt: DateTime.now(),
      ),
      TypeMasterModel(
        id: 'wallet_credit_card',
        name: 'Credit Card',
        value: 'credit_card',
        createdAt: DateTime.now(),
      ),
      TypeMasterModel(
        id: 'wallet_app',
        name: 'Wallet App',
        value: 'wallet_app',
        createdAt: DateTime.now(),
      ),
    ];

    for (final type in types) {
      await typeService.addType(type);
    }
  }
}
