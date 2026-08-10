import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/debt_model.dart';
import '../../data/repositories/debt_repository.dart';

// States
abstract class DebtState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DebtInitial extends DebtState {}

class DebtLoading extends DebtState {}

class DebtLoaded extends DebtState {
  final List<DebtModel> debts;

  DebtLoaded(this.debts);

  @override
  List<Object?> get props => [debts];
}

class DebtError extends DebtState {
  final String message;

  DebtError(this.message);

  @override
  List<Object?> get props => [message];
}

class DebtOperationSuccess extends DebtState {
  final String message;

  DebtOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class DebtCubit extends Cubit<DebtState> {
  final DebtRepository _repository;
  StreamSubscription? _debtsSubscription;

  DebtCubit(this._repository) : super(DebtInitial());

  void loadDebts() {
    emit(DebtLoading());
    _debtsSubscription?.cancel();
    _debtsSubscription = _repository.watchDebts().listen(
      (debts) {
        emit(DebtLoaded(debts));
      },
      onError: (error) {
        emit(DebtError(error.toString()));
      },
    );
  }

  Future<void> addDebt(DebtModel debt) async {
    try {
      await _repository.addDebt(debt);
      // Don't emit success state - let the stream handle the update
      // The stream will automatically emit DebtLoaded with updated data
    } catch (e) {
      emit(DebtError(e.toString()));
      // After showing error, reload to get back to loaded state
      Future.delayed(const Duration(seconds: 2), () {
        if (state is DebtError) {
          loadDebts();
        }
      });
    }
  }

  Future<void> updateDebt(DebtModel debt) async {
    try {
      await _repository.updateDebt(debt);
      // Don't emit success state - let the stream handle the update
    } catch (e) {
      emit(DebtError(e.toString()));
      Future.delayed(const Duration(seconds: 2), () {
        if (state is DebtError) {
          loadDebts();
        }
      });
    }
  }

  Future<void> deleteDebt(String debtId) async {
    try {
      await _repository.deleteDebt(debtId);
      // Don't emit success state - let the stream handle the update
    } catch (e) {
      emit(DebtError(e.toString()));
      Future.delayed(const Duration(seconds: 2), () {
        if (state is DebtError) {
          loadDebts();
        }
      });
    }
  }

  Future<void> updatePayment(String debtId, double amount) async {
    try {
      final currentState = state;
      if (currentState is DebtLoaded) {
        await _repository.updatePayment(debtId, amount, currentState.debts);
        // Don't emit success state - let the stream handle the update
      }
    } catch (e) {
      emit(DebtError(e.toString()));
      Future.delayed(const Duration(seconds: 2), () {
        if (state is DebtError) {
          loadDebts();
        }
      });
    }
  }

  void reset() {
    _debtsSubscription?.cancel();
    _debtsSubscription = null;
    emit(DebtInitial());
  }

  @override
  Future<void> close() {
    _debtsSubscription?.cancel();
    return super.close();
  }
}

