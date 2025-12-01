import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/partial_transaction_model.dart';
import '../../data/repositories/partial_transaction_repository.dart';

// States
abstract class PartialTransactionState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PartialTransactionInitial extends PartialTransactionState {}

class PartialTransactionLoading extends PartialTransactionState {}

class PartialTransactionLoaded extends PartialTransactionState {
  final List<PartialTransaction> partials;

  PartialTransactionLoaded(this.partials);

  @override
  List<Object?> get props => [partials];
}

class PartialTransactionError extends PartialTransactionState {
  final String message;

  PartialTransactionError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class PartialTransactionCubit extends Cubit<PartialTransactionState> {
  final PartialTransactionRepository _repository;
  StreamSubscription? _partialSubscription;

  PartialTransactionCubit(this._repository) : super(PartialTransactionInitial());

  void loadPartialTransactions() {
    emit(PartialTransactionLoading());
    _partialSubscription?.cancel();
    _partialSubscription = _repository.watchPartialTransactions().listen(
      (partials) {
        emit(PartialTransactionLoaded(partials));
      },
      onError: (error) {
        emit(PartialTransactionError(error.toString()));
        Future.delayed(const Duration(seconds: 2), () {
          loadPartialTransactions();
        });
      },
    );
  }

  Future<String> addPartialTransaction(PartialTransaction partial) async {
    try {
      return await _repository.addPartialTransaction(partial);
    } catch (e) {
      emit(PartialTransactionError(e.toString()));
      return '';
    }
  }

  Future<void> updatePartialTransaction(PartialTransaction partial) async {
    try {
      await _repository.updatePartialTransaction(partial);
    } catch (e) {
      emit(PartialTransactionError(e.toString()));
    }
  }

  Future<void> deletePartialTransaction(String partialId) async {
    try {
      await _repository.deletePartialTransaction(partialId);
    } catch (e) {
      emit(PartialTransactionError(e.toString()));
    }
  }

  Future<void> markAsSeen(String partialId) async {
    try {
      await _repository.markAsSeen(partialId);
    } catch (e) {
      emit(PartialTransactionError(e.toString()));
    }
  }

  List<PartialTransaction> getTodayUnseenPartials() {
    if (state is! PartialTransactionLoaded) return [];
    final loadedState = state as PartialTransactionLoaded;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return loadedState.partials.where((p) {
      final pDate = DateTime(p.date.year, p.date.month, p.date.day);
      return pDate.isAtSameMomentAs(today) && !p.seen;
    }).toList();
  }

  @override
  Future<void> close() {
    _partialSubscription?.cancel();
    return super.close();
  }
}

