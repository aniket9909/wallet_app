import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/savings_goal_model.dart';
import '../../data/repositories/savings_goal_repository.dart';

// States
abstract class SavingsGoalState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SavingsGoalInitial extends SavingsGoalState {}

class SavingsGoalLoading extends SavingsGoalState {}

class SavingsGoalLoaded extends SavingsGoalState {
  final List<SavingsGoalModel> goals;

  SavingsGoalLoaded(this.goals);

  @override
  List<Object?> get props => [goals];
}

class SavingsGoalError extends SavingsGoalState {
  final String message;

  SavingsGoalError(this.message);

  @override
  List<Object?> get props => [message];
}

class SavingsGoalOperationSuccess extends SavingsGoalState {
  final String message;

  SavingsGoalOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class SavingsGoalCubit extends Cubit<SavingsGoalState> {
  final SavingsGoalRepository _repository;
  StreamSubscription? _goalsSubscription;

  SavingsGoalCubit(this._repository) : super(SavingsGoalInitial());

  void loadGoals() {
    emit(SavingsGoalLoading());
    _goalsSubscription?.cancel();
    _goalsSubscription = _repository.watchSavingsGoals().listen(
      (goals) {
        emit(SavingsGoalLoaded(goals));
      },
      onError: (error) {
        emit(SavingsGoalError(error.toString()));
      },
    );
  }

  Future<void> addGoal(SavingsGoalModel goal) async {
    try {
      await _repository.addSavingsGoal(goal);
      emit(SavingsGoalOperationSuccess('Goal added successfully'));
    } catch (e) {
      emit(SavingsGoalError(e.toString()));
    }
  }

  Future<void> updateGoal(SavingsGoalModel goal) async {
    try {
      await _repository.updateSavingsGoal(goal);
      emit(SavingsGoalOperationSuccess('Goal updated successfully'));
    } catch (e) {
      emit(SavingsGoalError(e.toString()));
    }
  }

  Future<void> deleteGoal(String goalId) async {
    try {
      await _repository.deleteSavingsGoal(goalId);
      emit(SavingsGoalOperationSuccess('Goal deleted successfully'));
    } catch (e) {
      emit(SavingsGoalError(e.toString()));
    }
  }

  Future<void> updateProgress(String goalId, double amount) async {
    try {
      final currentState = state;
      if (currentState is SavingsGoalLoaded) {
        await _repository.updateProgress(goalId, amount, currentState.goals);
        emit(SavingsGoalOperationSuccess('Progress updated successfully'));
      }
    } catch (e) {
      emit(SavingsGoalError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _goalsSubscription?.cancel();
    return super.close();
  }
}

