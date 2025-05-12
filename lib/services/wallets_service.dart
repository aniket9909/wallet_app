import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ewallet/models/wallet_model.dart';

class WalletService {
  final CollectionReference _walletRef =
      FirebaseFirestore.instance.collection('wallet');

  /// 🔹 Create Wallet
  Future<void> addWallet(WalletModel wallet) async {
    await _walletRef.doc('123').collection('my_wallet').add(wallet.toJson());
  }

  /// 🔹 Read All Wallets
  Stream<List<WalletModel>> getWallets() {
    return _walletRef.doc('123').collection('my_wallet').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return WalletModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// 🔹 Update Wallet
  Future<void> updateWallet(
      String walletId, Map<String, dynamic> updates) async {
    await _walletRef.doc(walletId).update(updates);
  }

  /// 🔹 Delete Wallet
  Future<void> deleteWallet(String walletId) async {
    await _walletRef.doc(walletId).delete();
  }

  /// 🔹 Get Single Wallet by ID
  Future<WalletModel?> getWalletById(String walletId) async {
    final doc = await _walletRef.doc(walletId).get();
    if (doc.exists) {
      return WalletModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }
}
