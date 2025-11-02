import '../models/account_model.dart';
import '../services/firebase_realtime_service.dart';

class AccountRepository {
  final FirebaseRealtimeService _firebaseService;

  AccountRepository(this._firebaseService);

  Stream<List<AccountModel>> watchAccounts() {
    return _firebaseService.watchAccounts();
  }

  Future<void> addAccount(AccountModel account) async {
    await _firebaseService.addAccount(account);
  }

  Future<void> updateAccount(AccountModel account) async {
    await _firebaseService.updateAccount(account);
  }

  Future<void> deleteAccount(String accountId) async {
    await _firebaseService.deleteAccount(accountId);
  }
}

