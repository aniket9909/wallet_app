import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/investment_model.dart';
import '../../data/repositories/investment_repository.dart';

// States
abstract class InvestmentState extends Equatable {
  @override
  List<Object?> get props => [];
}

class InvestmentInitial extends InvestmentState {}

class InvestmentLoading extends InvestmentState {}

class InvestmentLoaded extends InvestmentState {
  final List<InvestmentModel> investments;

  InvestmentLoaded(this.investments);

  @override
  List<Object?> get props => [investments];
}

class InvestmentError extends InvestmentState {
  final String message;

  InvestmentError(this.message);

  @override
  List<Object?> get props => [message];
}

class InvestmentOperationSuccess extends InvestmentState {
  final String message;

  InvestmentOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class InvestmentCubit extends Cubit<InvestmentState> {
  final InvestmentRepository _repository;
  StreamSubscription? _investmentsSubscription;

  InvestmentCubit(this._repository) : super(InvestmentInitial());

  void loadInvestments() {
    emit(InvestmentLoading());
    _investmentsSubscription?.cancel();
    _investmentsSubscription = _repository.watchInvestments().listen(
      (investments) {
        emit(InvestmentLoaded(investments));
      },
      onError: (error) {
        emit(InvestmentError(error.toString()));
      },
    );
  }

  Future<void> addInvestment(InvestmentModel investment) async {
    try {
      await _repository.addInvestment(investment);
      // Don't emit success state - let the stream handle the update
      // The stream will automatically emit InvestmentLoaded with updated data
    } catch (e) {
      emit(InvestmentError(e.toString()));
      // After showing error, reload to get back to loaded state
      Future.delayed(const Duration(seconds: 2), () {
        if (state is InvestmentError) {
          loadInvestments();
        }
      });
    }
  }

  Future<void> updateInvestment(InvestmentModel investment) async {
    try {
      await _repository.updateInvestment(investment);
      // Don't emit success state - let the stream handle the update
    } catch (e) {
      emit(InvestmentError(e.toString()));
      Future.delayed(const Duration(seconds: 2), () {
        if (state is InvestmentError) {
          loadInvestments();
        }
      });
    }
  }

  Future<void> deleteInvestment(String investmentId) async {
    try {
      await _repository.deleteInvestment(investmentId);
      // Don't emit success state - let the stream handle the update
    } catch (e) {
      emit(InvestmentError(e.toString()));
      Future.delayed(const Duration(seconds: 2), () {
        if (state is InvestmentError) {
          loadInvestments();
        }
      });
    }
  }

  void reset() {
    _investmentsSubscription?.cancel();
    _investmentsSubscription = null;
    emit(InvestmentInitial());
  }

  @override
  Future<void> close() {
    _investmentsSubscription?.cancel();
    return super.close();
  }
}

