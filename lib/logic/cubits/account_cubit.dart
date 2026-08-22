import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/account_model.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/services/overlay_cache_service.dart';

// States
abstract class AccountState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AccountInitial extends AccountState {}

class AccountLoading extends AccountState {}

class AccountLoaded extends AccountState {
  final List<AccountModel> accounts;

  AccountLoaded(this.accounts);

  @override
  List<Object?> get props => [accounts];
}

class AccountError extends AccountState {
  final String message;

  AccountError(this.message);

  @override
  List<Object?> get props => [message];
}

class AccountOperationSuccess extends AccountState {
  final String message;

  AccountOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class AccountCubit extends Cubit<AccountState> {
  final AccountRepository _repository;
  StreamSubscription? _accountSubscription;

  AccountCubit(this._repository) : super(AccountInitial());

  void loadAccounts() {
    emit(AccountLoading());
    _accountSubscription?.cancel();
    _accountSubscription = _repository.watchAccounts().listen(
      (accounts) {
        emit(AccountLoaded(accounts));
        OverlayCacheService.syncFromLocalDatabase();
      },
      onError: (error) {
        emit(AccountError(error.toString()));
      },
    );
  }

  Future<void> addAccount(AccountModel account) async {
    try {
      await _repository.addAccount(account);
      // Don't emit success state - let the stream handle the update
      // The stream will automatically emit AccountLoaded with updated data
    } catch (e) {
      emit(AccountError(e.toString()));
      // After showing error, reload to get back to loaded state
      Future.delayed(const Duration(seconds: 2), () {
        if (state is AccountError) {
          loadAccounts();
        }
      });
    }
  }

  Future<void> updateAccount(AccountModel account) async {
    try {
      await _repository.updateAccount(account);
      // Don't emit success state - let the stream handle the update
    } catch (e) {
      emit(AccountError(e.toString()));
      Future.delayed(const Duration(seconds: 2), () {
        if (state is AccountError) {
          loadAccounts();
        }
      });
    }
  }

  Future<void> deleteAccount(String accountId) async {
    try {
      await _repository.deleteAccount(accountId);
      // Don't emit success state - let the stream handle the update
    } catch (e) {
      emit(AccountError(e.toString()));
      Future.delayed(const Duration(seconds: 2), () {
        if (state is AccountError) {
          loadAccounts();
        }
      });
    }
  }

  void reset() {
    _accountSubscription?.cancel();
    _accountSubscription = null;
    emit(AccountInitial());
  }

  @override
  Future<void> close() {
    _accountSubscription?.cancel();
    return super.close();
  }
}

