import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/wallet_data_model.dart';
import '../../data/repositories/wallet_repository.dart';

// States
abstract class WalletState extends Equatable {
  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletLoaded extends WalletState {
  final WalletDataModel wallet;

  WalletLoaded(this.wallet);

  @override
  List<Object?> get props => [wallet];
}

class WalletError extends WalletState {
  final String message;

  WalletError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class WalletCubit extends Cubit<WalletState> {
  final WalletRepository _repository;
  StreamSubscription? _walletSubscription;

  WalletCubit(this._repository) : super(WalletInitial());

  void loadWallet() {
    emit(WalletLoading());
    _walletSubscription?.cancel();
    _walletSubscription = _repository.watchWalletData().listen(
      (wallet) {
        if (wallet != null) {
          emit(WalletLoaded(wallet));
        } else {
          emit(WalletLoaded(const WalletDataModel(
            totalBalance: 0,
            totalIncome: 0,
            totalExpense: 0,
            monthlyIncome: 0,
            monthlyExpense: 0,
          )));
        }
      },
      onError: (error) {
        emit(WalletError(error.toString()));
      },
    );
  }

  Future<void> updateWallet(WalletDataModel wallet) async {
    try {
      await _repository.updateWalletData(wallet);
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  void reset() {
    _walletSubscription?.cancel();
    _walletSubscription = null;
    emit(WalletInitial());
  }

  @override
  Future<void> close() {
    _walletSubscription?.cancel();
    return super.close();
  }
}

