import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/wallet_data_model.dart';
import '../models/account_model.dart';
import '../models/transaction_model_new.dart';
import '../models/savings_goal_model.dart';
import '../models/settings_model.dart';
import '../models/debt_model.dart';
import '../models/investment_model.dart';
import '../models/partial_transaction_model.dart';
import '../models/sms_message_model.dart';
import '../models/money_plan_model.dart';

class FirebaseRealtimeService {
  final FirebaseDatabase _database;
  final FirebaseAuth _auth;

  FirebaseRealtimeService({
    FirebaseDatabase? database,
    FirebaseAuth? auth,
  })  : _database = database ?? FirebaseDatabase.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  bool get isAuthenticated => userId != null;

  DatabaseReference get _userRef {
    final uid = userId;
    if (uid == null) {
      throw StateError('FirebaseRealtimeService: user not authenticated');
    }
    return _database.ref('users/$uid');
  }

  // ============ WALLET DATA ============
  Stream<WalletDataModel?> watchWalletData() {
    if (!isAuthenticated) return Stream.value(null);
    return _userRef.child('wallet').onValue.map((event) {
      if (event.snapshot.value == null) return null;
      return WalletDataModel.fromJson(
          event.snapshot.value as Map<dynamic, dynamic>);
    });
  }

  Future<void> updateWalletData(WalletDataModel wallet) async {
    await _userRef.child('wallet').set(wallet.toJson());
  }

  // ============ ACCOUNTS ============
  Stream<List<AccountModel>> watchAccounts() {
    if (!isAuthenticated) return Stream.value([]);
    return _userRef.child('accounts').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries
          .map((e) => AccountModel.fromJson(e.key, e.value))
          .toList();
    });
  }

  Future<void> addAccount(AccountModel account) async {
    final ref = _userRef.child('accounts').push();
    await ref.set(account.toJson());
  }

  Future<void> updateAccount(AccountModel account) async {
    await _userRef.child('accounts/${account.id}').update(account.toJson());
  }

  Future<void> deleteAccount(String accountId) async {
    await _userRef.child('accounts/$accountId').remove();
  }

  // ============ TRANSACTIONS ============
  Stream<List<TransactionModelNew>> watchTransactions() {
    if (!isAuthenticated) return Stream.value([]);
    return _userRef.child('transactions').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final transactions = data.entries
          .map((e) => TransactionModelNew.fromJson(e.key, e.value))
          .toList();
      // Sort by date descending
      transactions.sort((a, b) => b.date.compareTo(a.date));
      return transactions;
    });
  }

  Future<String> addTransaction(TransactionModelNew transaction) async {
    final ref = _userRef.child('transactions').push();
    await ref.set(transaction.toJson());
    
    // Update wallet balance
    await _updateWalletBalance(transaction);
    
    // Update account balance
    await _updateAccountBalance(transaction);
    
    return ref.key!;
  }

  Future<void> updateTransaction(TransactionModelNew transaction) async {
    await _userRef
        .child('transactions/${transaction.id}')
        .update(transaction.toJson());
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _userRef.child('transactions/$transactionId').remove();
  }

  Future<void> _updateWalletBalance(TransactionModelNew transaction) async {
    // Do not change wallet totals for transfers
    if (transaction.category == 'Transfer') {
      return;
    }
    final snapshot = await _userRef.child('wallet').get();
    WalletDataModel wallet;
    
    if (snapshot.exists) {
      wallet = WalletDataModel.fromJson(snapshot.value as Map<dynamic, dynamic>);
    } else {
      wallet = const WalletDataModel(
        totalBalance: 0,
        totalIncome: 0,
        totalExpense: 0,
        monthlyIncome: 0,
        monthlyExpense: 0,
      );
    }

    final isCurrentMonth = transaction.date.month == DateTime.now().month &&
        transaction.date.year == DateTime.now().year;

    if (transaction.type == TransactionType.credit) {
      wallet = wallet.copyWith(
        totalBalance: wallet.totalBalance + transaction.amount,
        totalIncome: wallet.totalIncome + transaction.amount,
        monthlyIncome: isCurrentMonth
            ? wallet.monthlyIncome + transaction.amount
            : wallet.monthlyIncome,
      );
    } else {
      wallet = wallet.copyWith(
        totalBalance: wallet.totalBalance - transaction.amount,
        totalExpense: wallet.totalExpense + transaction.amount,
        monthlyExpense: isCurrentMonth
            ? wallet.monthlyExpense + transaction.amount
            : wallet.monthlyExpense,
      );
    }

    await updateWalletData(wallet);
  }

  Future<void> _updateAccountBalance(TransactionModelNew transaction) async {
    final accountsSnapshot = await _userRef.child('accounts').get();
    if (!accountsSnapshot.exists) return;

    final accounts = accountsSnapshot.value as Map<dynamic, dynamic>;
    final accountEntry = accounts.entries.firstWhere(
      (e) => (e.value as Map)['name'] == transaction.account,
      orElse: () => MapEntry('', {}),
    );

    if (accountEntry.key == '') return;

    final account = AccountModel.fromJson(
        accountEntry.key, accountEntry.value as Map<dynamic, dynamic>);

    final newBalance = transaction.type == TransactionType.credit
        ? account.balance + transaction.amount
        : account.balance - transaction.amount;

    await updateAccount(account.copyWith(balance: newBalance));
  }

  // ============ SAVINGS GOALS ============
  Stream<List<SavingsGoalModel>> watchSavingsGoals() {
    if (!isAuthenticated) return Stream.value([]);
    return _userRef.child('goals').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries
          .map((e) => SavingsGoalModel.fromJson(e.key, e.value))
          .toList();
    });
  }

  Future<void> addSavingsGoal(SavingsGoalModel goal) async {
    final ref = _userRef.child('goals').push();
    await ref.set(goal.toJson());
  }

  Future<void> updateSavingsGoal(SavingsGoalModel goal) async {
    await _userRef.child('goals/${goal.id}').update(goal.toJson());
  }

  Future<void> deleteSavingsGoal(String goalId) async {
    await _userRef.child('goals/$goalId').remove();
  }

  // ============ SETTINGS ============
  Stream<SettingsModel> watchSettings() {
    if (!isAuthenticated) {
      return Stream.value(
        SettingsModel(
          notificationsEnabled: true,
          expenseTypes: const [
            'Food', 'Bills', 'Shopping', 'Travel',
            'Entertainment', 'Health', 'Other',
          ],
          profile: const UserProfile(name: '', email: ''),
        ),
      );
    }
    return _userRef.child('settings').onValue.map((event) {
      if (event.snapshot.value == null) {
        return SettingsModel(
          notificationsEnabled: true,
          expenseTypes: ['Food', 'Bills', 'Shopping', 'Travel', 'Entertainment', 'Health', 'Other'],
          profile: UserProfile(
            name: _auth.currentUser?.displayName ?? '',
            email: _auth.currentUser?.email ?? '',
          ),
        );
      }
      return SettingsModel.fromJson(
          event.snapshot.value as Map<dynamic, dynamic>);
    });
  }

  Future<void> updateSettings(SettingsModel settings) async {
    await _userRef.child('settings').set(settings.toJson());
  }

  // ============ DEBTS ============
  Stream<List<DebtModel>> watchDebts() {
    if (!isAuthenticated) return Stream.value([]);
    return _userRef.child('debts').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries
          .map((e) => DebtModel.fromJson(e.key, e.value))
          .toList();
    });
  }

  Future<String> addDebt(DebtModel debt) async {
    final ref = _userRef.child('debts').push();
    await ref.set(debt.toJson());
    return ref.key!;
  }

  Future<void> updateDebt(DebtModel debt) async {
    await _userRef.child('debts/${debt.id}').update(debt.toJson());
  }

  Future<void> deleteDebt(String debtId) async {
    await _userRef.child('debts/$debtId').remove();
  }

  // ============ INVESTMENTS ============
  Stream<List<InvestmentModel>> watchInvestments() {
    if (!isAuthenticated) return Stream.value([]);
    return _userRef.child('investments').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries
          .map((e) => InvestmentModel.fromJson(e.key, e.value))
          .toList();
    });
  }

  Future<String> addInvestment(InvestmentModel investment) async {
    final ref = _userRef.child('investments').push();
    await ref.set(investment.toJson());
    return ref.key!;
  }

  Future<void> updateInvestment(InvestmentModel investment) async {
    await _userRef.child('investments/${investment.id}').update(investment.toJson());
  }

  Future<void> deleteInvestment(String investmentId) async {
    await _userRef.child('investments/$investmentId').remove();
  }

  // ============ MONEY PLAN ============
  Stream<MoneyPlanModel?> watchMoneyPlan() {
    if (!isAuthenticated) return Stream.value(null);
    return _userRef.child('money_plan').onValue.map((event) {
      if (event.snapshot.value == null) return null;
      return MoneyPlanModel.fromJson(
        event.snapshot.value as Map<dynamic, dynamic>,
      );
    });
  }

  Future<void> saveMoneyPlan(MoneyPlanModel plan) async {
    await _userRef.child('money_plan').set(plan.toJson());
  }

  // ============ UTILITY METHODS ============
  Future<void> initializeUserData() async {
    if (!isAuthenticated) return;

    final snapshot = await _userRef.get();
    final user = _auth.currentUser;
    if (!snapshot.exists) {
      await _userRef.set({
        'wallet': const WalletDataModel(
          totalBalance: 0,
          totalIncome: 0,
          totalExpense: 0,
          monthlyIncome: 0,
          monthlyExpense: 0,
        ).toJson(),
        'settings': SettingsModel(
          notificationsEnabled: true,
          expenseTypes: const [
            'Food', 'Bills', 'Shopping', 'Travel',
            'Entertainment', 'Health', 'Other',
          ],
          profile: UserProfile(
            name: user?.displayName ?? '',
            email: user?.email ?? '',
          ),
        ).toJson(),
      });
      return;
    }

    // Ensure settings node exists for older accounts.
    final settingsSnap = await _userRef.child('settings').get();
    if (!settingsSnap.exists) {
      await _userRef.child('settings').set(
        SettingsModel(
          notificationsEnabled: true,
          expenseTypes: const [
            'Food', 'Bills', 'Shopping', 'Travel',
            'Entertainment', 'Health', 'Other',
          ],
          profile: UserProfile(
            name: user?.displayName ?? '',
            email: user?.email ?? '',
          ),
        ).toJson(),
      );
    }

    // Ensure wallet node exists (partial user records).
    final walletSnap = await _userRef.child('wallet').get();
    if (!walletSnap.exists) {
      await _userRef.child('wallet').set(
        const WalletDataModel(
          totalBalance: 0,
          totalIncome: 0,
          totalExpense: 0,
          monthlyIncome: 0,
          monthlyExpense: 0,
        ).toJson(),
      );
    }
  }

  // ============ PARTIAL TRANSACTIONS ============
  Stream<List<PartialTransaction>> watchPartialTransactions() {
    if (!isAuthenticated) return Stream.value([]);
    return _userRef.child('partialTransactions').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final partials = data.entries
          .map((e) => PartialTransaction.fromJson(e.key, e.value))
          .toList();
      // Sort by date descending
      partials.sort((a, b) => b.date.compareTo(a.date));
      return partials;
    });
  }

  Future<String> addPartialTransaction(PartialTransaction partial) async {
    final ref = _userRef.child('partialTransactions').push();
    await ref.set(partial.toJson());
    return ref.key!;
  }

  Future<void> updatePartialTransaction(PartialTransaction partial) async {
    await _userRef
        .child('partialTransactions/${partial.id}')
        .update(partial.toJson());
  }

  Future<void> deletePartialTransaction(String partialId) async {
    await _userRef.child('partialTransactions/$partialId').remove();
  }

  Future<void> markPartialTransactionAsSeen(String partialId) async {
    await _userRef
        .child('partialTransactions/$partialId/seen')
        .set(true);
  }

  // ============ SMS MESSAGES ============
  Stream<List<SmsMessageModel>> watchSmsMessages() {
    if (!isAuthenticated) return Stream.value([]);
    return _userRef.child('smsMessages').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final smsList = data.entries
          .map((e) => SmsMessageModel.fromJson(e.key, e.value))
          .toList();
      // Sort by date descending
      smsList.sort((a, b) => b.date.compareTo(a.date));
      return smsList;
    });
  }

  Future<String> addSmsMessage(SmsMessageModel sms) async {
    final ref = _userRef.child('smsMessages').push();
    await ref.set(sms.toJson());
    return ref.key!;
  }

  Future<void> updateSmsMessage(SmsMessageModel sms) async {
    if (sms.id == null) return;
    await _userRef
        .child('smsMessages/${sms.id}')
        .update(sms.toJson());
  }

  Future<void> deleteSmsMessage(String smsId) async {
    await _userRef.child('smsMessages/$smsId').remove();
  }

  Future<void> syncSmsMessages(List<SmsMessageModel> smsList) async {
    // Sync all local SMS to Firebase
    for (final sms in smsList) {
      if (sms.id != null) {
        // Use local ID as Firebase key for consistency
        await _userRef
            .child('smsMessages/${sms.id}')
            .set(sms.toJson());
      } else {
        // If no ID, push new entry
        await _userRef.child('smsMessages').push().set(sms.toJson());
      }
    }
  }
}

