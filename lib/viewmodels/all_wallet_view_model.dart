import 'package:ewallet/models/wallet_model.dart';
import 'package:ewallet/services/wallet_type_service.dart';
import 'package:ewallet/services/wallets_service.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class AllWalletViewModel extends ChangeNotifier {
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  List<dynamic> _wallets = [];
  List<dynamic> _walletType = [];
  List<dynamic> get wallets => _wallets;
  List<dynamic> get walletType => _walletType;
  TextEditingController walletTypeController = TextEditingController();
  TextEditingController walletAmountController = TextEditingController();

  AllWalletViewModel() {
    fetchAllWallets();
    fetchWalletTypes();
  }

  fetchAllWallets() {
    _isLoading = true;
    notifyListeners();
    WalletService().getWallets().listen((value) {
      _isLoading = false;
      _wallets = value;
      print(_wallets);
      notifyListeners();
    });
  }

  fetchWalletTypes() {
    _isLoading = true;
    notifyListeners();
    TypeMasterService().getTypes().then((value) {
      _isLoading = false;
      _walletType = value;
      print(_walletType);
      notifyListeners();
    });
  }

  Future<void> addWallet() async {
    _isLoading = true;
    notifyListeners();
    try {
      await WalletService().addWallet(WalletModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: walletTypeController.text,
        name: walletTypeController.text,
        balance: double.tryParse(walletAmountController.text) ?? 0.0,
        createdAt: DateTime.now(),
      ));
      await fetchAllWallets();
    } catch (e) {
      print('Error adding wallet: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
