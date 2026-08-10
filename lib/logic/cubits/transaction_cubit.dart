import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/transaction_model_new.dart';
import '../../data/repositories/transaction_repository.dart';

// States
abstract class TransactionState extends Equatable {
  @override
  List<Object?> get props => [];
}

class TransactionInitial extends TransactionState {}

class TransactionLoading extends TransactionState {}

class TransactionLoaded extends TransactionState {
  final List<TransactionModelNew> transactions;
  final Map<String, double> categoryExpenses;

  TransactionLoaded(this.transactions, this.categoryExpenses);

  @override
  List<Object?> get props => [transactions, categoryExpenses];
}

class TransactionError extends TransactionState {
  final String message;

  TransactionError(this.message);

  @override
  List<Object?> get props => [message];
}

class TransactionOperationSuccess extends TransactionState {
  final String message;

  TransactionOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class TransactionCubit extends Cubit<TransactionState> {
  final TransactionRepository _repository;
  StreamSubscription? _transactionSubscription;

  TransactionCubit(this._repository) : super(TransactionInitial());

  void loadTransactions() {
    emit(TransactionLoading());
    _transactionSubscription?.cancel();
    _transactionSubscription = _repository.watchTransactions().listen(
      (transactions) {
        final categoryExpenses = _repository.getCategoryExpenses(transactions);
        emit(TransactionLoaded(transactions, categoryExpenses));
      },
      onError: (error) {
        emit(TransactionError(error.toString()));
      },
    );
  }

  Future<void> addTransaction(TransactionModelNew transaction) async {
    try {
      await _repository.addTransaction(transaction);
      // Don't emit success state - let the stream handle the update
      // The stream will automatically emit TransactionLoaded with updated data
    } catch (e) {
      emit(TransactionError(e.toString()));
      // After showing error, reload to get back to loaded state
      Future.delayed(const Duration(seconds: 2), () {
        if (state is TransactionError) {
          loadTransactions();
        }
      });
    }
  }

  Future<void> updateTransaction(TransactionModelNew transaction) async {
    try {
      await _repository.updateTransaction(transaction);
      // Don't emit success state - let the stream handle the update
    } catch (e) {
      emit(TransactionError(e.toString()));
      Future.delayed(const Duration(seconds: 2), () {
        if (state is TransactionError) {
          loadTransactions();
        }
      });
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _repository.deleteTransaction(transactionId);
      // Don't emit success state - let the stream handle the update
    } catch (e) {
      emit(TransactionError(e.toString()));
      Future.delayed(const Duration(seconds: 2), () {
        if (state is TransactionError) {
          loadTransactions();
        }
      });
    }
  }

  List<TransactionModelNew> filterByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    final currentState = state;
    if (currentState is TransactionLoaded) {
      return _repository.filterByDateRange(
        currentState.transactions,
        startDate,
        endDate,
      );
    }
    return [];
  }

  List<TransactionModelNew> filterByCategory(String category) {
    final currentState = state;
    if (currentState is TransactionLoaded) {
      return _repository.filterByCategory(
        currentState.transactions,
        category,
      );
    }
    return [];
  }

  void reset() {
    _transactionSubscription?.cancel();
    _transactionSubscription = null;
    emit(TransactionInitial());
  }

  @override
  Future<void> close() {
    _transactionSubscription?.cancel();
    return super.close();
  }
}

