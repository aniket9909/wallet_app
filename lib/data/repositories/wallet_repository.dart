import '../models/wallet_data_model.dart';
import '../services/firebase_realtime_service.dart';

class WalletRepository {
  final FirebaseRealtimeService _firebaseService;

  WalletRepository(this._firebaseService);

  Stream<WalletDataModel?> watchWalletData() {
    return _firebaseService.watchWalletData();
  }

  Future<void> updateWalletData(WalletDataModel wallet) async {
    await _firebaseService.updateWalletData(wallet);
  }
}

